"""Campaign orchestration CLI — clearwing campaign (spec 012).

Subcommands:
    run         Start a campaign from a YAML config
    status      Show campaign progress dashboard
    pause       Pause a running campaign
    resume      Resume a paused campaign from checkpoint
    report      Generate aggregate campaign report
"""

from __future__ import annotations

import time
from datetime import datetime, timezone
from pathlib import Path

from rich.table import Table


def add_parser(subparsers):
    parser = subparsers.add_parser(
        "campaign",
        help="Campaign-scale orchestration across multiple projects",
    )
    sub = parser.add_subparsers(dest="campaign_action")

    r = sub.add_parser("run", help="Start a campaign from a YAML config")
    r.add_argument("config_file", help="Path to campaign.yaml")
    r.add_argument(
        "--dry-run", action="store_true",
        help="Validate config and show plan without running",
    )

    s = sub.add_parser("status", help="Show campaign progress dashboard")
    s.add_argument("config_file", help="Path to campaign.yaml")

    p = sub.add_parser("pause", help="Pause a running campaign")
    p.add_argument("config_file", help="Path to campaign.yaml")

    rs = sub.add_parser("resume", help="Resume a paused campaign from checkpoint")
    rs.add_argument("config_file", help="Path to campaign.yaml")

    rp = sub.add_parser("report", help="Generate aggregate campaign report")
    rp.add_argument("config_file", help="Path to campaign.yaml")
    rp.add_argument(
        "--format", nargs="+",
        choices=["sarif", "markdown", "json", "all"],
        default=["all"],
    )

    return parser


def handle(cli, args):
    """Dispatch to the appropriate campaign subcommand."""
    action = getattr(args, "campaign_action", None)
    if not action:
        cli.console.print(
            "[yellow]Usage: clearwing campaign "
            "<run|status|pause|resume|report>[/yellow]",
        )
        return

    handlers = {
        "run": _handle_run,
        "status": _handle_status,
        "pause": _handle_pause,
        "resume": _handle_resume,
        "report": _handle_report,
    }
    handler = handlers.get(action)
    if handler:
        handler(cli, args)
    else:
        cli.console.print(f"[red]Unknown action: {action}[/red]")


def _handle_run(cli, args):
    from clearwing.sourcehunt.campaign import CampaignRunner
    from clearwing.sourcehunt.campaign_config import load_campaign_config

    try:
        config = load_campaign_config(args.config_file)
    except Exception as e:
        cli.console.print(f"[red]Config error: {e}[/red]")
        return

    if args.dry_run:
        _print_plan(cli, config)
        return

    cli.console.print(
        f"[bold]Starting campaign:[/bold] {config.name} "
        f"({len(config.targets)} targets, ${config.budget:.0f} budget)",
    )

    runner = CampaignRunner(config)
    result = runner.run()

    cli.console.print("")
    _print_result(cli, result)


def _handle_status(cli, args):
    from clearwing.sourcehunt.campaign import load_checkpoint
    from clearwing.sourcehunt.campaign_config import load_campaign_config

    try:
        config = load_campaign_config(args.config_file)
    except Exception as e:
        cli.console.print(f"[red]Config error: {e}[/red]")
        return

    checkpoint_dir = Path(config.output_dir)
    session_dirs = sorted(checkpoint_dir.glob("campaign-*"))
    if not session_dirs:
        cli.console.print("[yellow]No campaign checkpoints found.[/yellow]")
        return

    cp = load_checkpoint(session_dirs[-1])
    if cp is None:
        cli.console.print("[yellow]Could not load checkpoint.[/yellow]")
        return

    elapsed = time.time() - cp.timestamp
    cli.console.print(f"[bold]Campaign:[/bold] {cp.campaign_name}")
    cli.console.print(
        f"[bold]Status:[/bold] {'PAUSED' if cp.paused else 'RUNNING'} "
        f"(last checkpoint {elapsed:.0f}s ago)",
    )
    cli.console.print(
        f"[bold]Budget:[/bold] ${cp.budget_spent:.0f} / ${config.budget:.0f} "
        f"({cp.budget_spent / config.budget * 100:.1f}%)" if config.budget > 0 else "",
    )

    table = Table(title="Projects")
    table.add_column("Project", style="cyan")
    table.add_column("Findings", style="magenta")
    table.add_column("Verified", style="green")
    table.add_column("Cost", style="yellow")
    table.add_column("Status", style="bold")

    for repo, ps in cp.per_project_state.items():
        name = repo.rstrip("/").split("/")[-1]
        table.add_row(
            name,
            str(ps.findings_count),
            str(ps.verified_count),
            f"${ps.cost_usd:.0f}",
            ps.status,
        )

    cli.console.print(table)

    if cp.recent_runs_count > 0:
        rate = cp.recent_new_findings / cp.recent_runs_count
        cli.console.print(
            f"\n[bold]Finding rate:[/bold] "
            f"1 per {1 / rate:.0f} runs" if rate > 0 else "no findings yet",
        )


def _handle_pause(cli, args):
    from clearwing.sourcehunt.campaign_config import load_campaign_config

    try:
        config = load_campaign_config(args.config_file)
    except Exception as e:
        cli.console.print(f"[red]Config error: {e}[/red]")
        return

    checkpoint_dir = Path(config.output_dir)
    session_dirs = sorted(checkpoint_dir.glob("campaign-*"))
    if not session_dirs:
        cli.console.print("[yellow]No running campaign found.[/yellow]")
        return

    pause_file = session_dirs[-1] / "PAUSE"
    pause_file.touch()
    cli.console.print(
        f"[green]Pause signal written to {pause_file}. "
        f"Campaign will pause after current files complete.[/green]",
    )


def _handle_resume(cli, args):
    import asyncio

    from clearwing.sourcehunt.campaign import CampaignRunner
    from clearwing.sourcehunt.campaign_config import load_campaign_config

    try:
        config = load_campaign_config(args.config_file)
    except Exception as e:
        cli.console.print(f"[red]Config error: {e}[/red]")
        return

    checkpoint_dir = Path(config.output_dir)
    session_dirs = sorted(checkpoint_dir.glob("campaign-*"))
    if not session_dirs:
        cli.console.print("[yellow]No campaign checkpoint found.[/yellow]")
        return

    pause_file = session_dirs[-1] / "PAUSE"
    if pause_file.exists():
        pause_file.unlink()

    try:
        runner = asyncio.run(CampaignRunner.from_checkpoint(config))
    except ValueError as e:
        cli.console.print(f"[red]{e}[/red]")
        return

    cli.console.print(f"[bold]Resuming campaign:[/bold] {config.name}")
    result = runner.run()
    _print_result(cli, result)


def _handle_report(cli, args):
    from clearwing.sourcehunt.campaign import load_checkpoint
    from clearwing.sourcehunt.campaign_config import load_campaign_config

    try:
        config = load_campaign_config(args.config_file)
    except Exception as e:
        cli.console.print(f"[red]Config error: {e}[/red]")
        return

    checkpoint_dir = Path(config.output_dir)
    session_dirs = sorted(checkpoint_dir.glob("campaign-*"))
    if not session_dirs:
        cli.console.print("[yellow]No campaign data found.[/yellow]")
        return

    cp = load_checkpoint(session_dirs[-1])
    if cp is None:
        cli.console.print("[yellow]Could not load checkpoint.[/yellow]")
        return

    total_findings = sum(
        ps.findings_count for ps in cp.per_project_state.values()
    )
    total_verified = sum(
        ps.verified_count for ps in cp.per_project_state.values()
    )
    completed = sum(
        1 for ps in cp.per_project_state.values()
        if ps.status == "completed"
    )

    cli.console.print(f"[bold]Campaign Report: {cp.campaign_name}[/bold]")
    cli.console.print(f"Session: {cp.campaign_session_id}")
    cli.console.print(f"Projects: {completed}/{len(cp.per_project_state)} completed")
    cli.console.print(f"Findings: {total_findings} ({total_verified} verified)")
    cli.console.print(f"Total cost: ${cp.budget_spent:.2f}")


def _print_plan(cli, config):
    """Show what the campaign would do without running."""
    cli.console.print(f"[bold]Campaign Plan: {config.name}[/bold]")
    cli.console.print(f"Budget: ${config.budget:.0f}")
    cli.console.print(f"Depth: {config.depth}")
    cli.console.print(f"Max containers: {config.max_concurrent_containers}")
    cli.console.print("")

    table = Table(title="Targets")
    table.add_column("Repo", style="cyan")
    table.add_column("Budget", style="yellow")
    table.add_column("Depth", style="blue")
    table.add_column("Focus", style="magenta")

    for t in config.targets:
        table.add_row(
            t.repo,
            f"${t.budget:.0f}" if t.budget else "shared",
            t.depth or config.depth,
            ", ".join(t.focus) if t.focus else "-",
        )

    cli.console.print(table)


def _print_result(cli, result):
    """Print campaign result summary."""
    cli.console.print(f"[bold]Campaign Complete: {result.campaign_name}[/bold]")
    cli.console.print(f"Status: {result.status}")
    cli.console.print(f"Duration: {result.duration_seconds / 3600:.1f}h")
    cli.console.print(f"Cost: ${result.total_cost_usd:.2f}")
    cli.console.print(
        f"Projects: {result.projects_completed}/{result.projects_total}",
    )
    cli.console.print(
        f"Findings: {result.total_findings} ({result.total_verified} verified)",
    )
    if result.stopping_reason:
        cli.console.print(f"Stopped: {result.stopping_reason}")
