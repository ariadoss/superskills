"""Benchmark CLI — clearwing bench (spec 017).

Subcommands:
    ossfuzz     Run the OSS-Fuzz crash severity ladder benchmark
    compare     Compare two benchmark result files
"""

from __future__ import annotations

import asyncio
import logging
import sys


def add_parser(subparsers):
    parser = subparsers.add_parser(
        "bench",
        help="Benchmarking tools for model evaluation",
    )
    sub = parser.add_subparsers(dest="bench_action")

    ossfuzz = sub.add_parser(
        "ossfuzz", help="OSS-Fuzz crash severity ladder benchmark",
    )
    ossfuzz.add_argument(
        "--mode", choices=["quick", "standard", "full", "deep"],
        default="standard", help="Benchmark mode (default: standard)",
    )
    ossfuzz.add_argument(
        "--corpus-dir", metavar="DIR",
        help="Directory of OSS-Fuzz project clones",
    )
    ossfuzz.add_argument(
        "--targets-file", metavar="FILE",
        help="JSON file listing benchmark targets",
    )
    ossfuzz.add_argument(
        "--output-dir", default=None,
        help="Output directory for results (default: ./results/bench or ~/.clearwing/results/bench)",
    )
    ossfuzz.add_argument(
        "--max-parallel", type=int, default=4,
        help="Max parallel target runs (default: 4)",
    )
    ossfuzz.add_argument(
        "--resume", action="store_true", default=True,
        help="Resume from existing per-target results (default: true)",
    )
    ossfuzz.add_argument(
        "--no-llm-classify", action="store_true",
        help="Skip LLM-assisted tier 3-5 classification",
    )
    ossfuzz.add_argument("--model", default=None, help="LLM model name")
    ossfuzz.add_argument("--base-url", default=None, help="LLM API base URL")
    ossfuzz.add_argument("--api-key", default=None, help="LLM API key")

    compare = sub.add_parser(
        "compare", help="Compare two benchmark result files",
    )
    compare.add_argument(
        "results", nargs=2, metavar="FILE",
        help="Two JSON result files to compare",
    )
    compare.add_argument(
        "--format", choices=["table", "json", "markdown"],
        default="table", dest="output_format",
        help="Output format (default: table)",
    )

    return parser


def handle(cli, args):
    """Dispatch to the appropriate bench subcommand."""
    action = getattr(args, "bench_action", None)
    if not action:
        cli.console.print(
            "[yellow]Usage: clearwing bench <ossfuzz|compare>[/yellow]",
        )
        return

    handlers = {
        "ossfuzz": _handle_ossfuzz,
        "compare": _handle_compare,
    }
    handler = handlers.get(action)
    if handler:
        handler(cli, args)
    else:
        cli.console.print(f"[red]Unknown action: {action}[/red]")


def _handle_ossfuzz(cli, args):
    from ...bench.ossfuzz import (
        OssFuzzBenchmark,
        load_corpus_dir,
        load_targets_file,
    )
    from ...core.config import default_results_dir
    from ...providers import ProviderManager, resolve_llm_endpoint

    if args.output_dir is None:
        args.output_dir = default_results_dir("bench")

    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s: %(message)s", force=True,
    )

    if not args.corpus_dir and not args.targets_file:
        cli.console.print(
            "[red]Error: provide --corpus-dir or --targets-file[/red]",
        )
        sys.exit(1)

    # Load targets
    targets = []
    if args.corpus_dir:
        targets = load_corpus_dir(args.corpus_dir)
    elif args.targets_file:
        targets = load_targets_file(args.targets_file)

    if not targets:
        cli.console.print("[yellow]No benchmark targets found.[/yellow]")
        return

    # Resolve LLM
    endpoint = resolve_llm_endpoint(
        cli_model=args.model,
        cli_base_url=args.base_url,
        cli_api_key=args.api_key,
        config_provider=cli.config.get_provider_section() or None,
    )
    cli.console.print(f"[dim]LLM endpoint: {endpoint.describe()}[/dim]")
    provider_manager = ProviderManager.for_endpoint(endpoint)
    llm = provider_manager.llm()

    model_name = args.model or endpoint.model or "unknown"

    cli.console.print(
        f"[bold]OSS-Fuzz Benchmark:[/bold] mode={args.mode}, "
        f"targets={len(targets)}, model={model_name}",
    )

    benchmark = OssFuzzBenchmark(
        llm=llm,
        mode=args.mode,
        output_dir=args.output_dir,
        model_name=model_name,
        max_parallel=args.max_parallel,
        llm_classify=not args.no_llm_classify,
    )

    result = asyncio.run(benchmark.arun(targets))

    # Print summary
    cli.console.print("")
    cli.console.print("[bold]Results:[/bold]")
    cli.console.print(
        f"  Targets: {result.targets_succeeded}/{result.targets_attempted} "
        f"succeeded, {result.targets_failed} failed",
    )
    cli.console.print(f"  Cost: ${result.total_cost_usd:.2f}")
    cli.console.print(
        f"  Duration: {result.total_duration_seconds:.0f}s",
    )

    if result.tier_distribution:
        cli.console.print("  Tier distribution:")
        for tier in sorted(result.tier_distribution.keys()):
            count = result.tier_distribution[tier]
            cli.console.print(f"    Tier {tier}: {count}")


def _handle_compare(cli, args):
    from ...bench.results import (
        compare_results,
        format_comparison,
        load_result,
    )

    try:
        a = load_result(args.results[0])
        b = load_result(args.results[1])
    except Exception as e:
        cli.console.print(f"[red]Error loading results: {e}[/red]")
        sys.exit(1)

    comparison = compare_results(a, b)
    output = format_comparison(comparison, fmt=args.output_format)
    cli.console.print(output)
