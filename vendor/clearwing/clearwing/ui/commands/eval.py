"""Evaluation CLI — clearwing eval (spec 018).

Subcommands:
    preprocessing   A/B test the preprocessing pipeline
    compare         Compare two eval result files
"""

from __future__ import annotations

import asyncio
import logging
import sys


def add_parser(subparsers):
    parser = subparsers.add_parser(
        "eval",
        help="Evaluation and A/B testing",
    )
    sub = parser.add_subparsers(dest="eval_action")

    pp = sub.add_parser(
        "preprocessing",
        help="A/B test the preprocessing pipeline",
    )
    pp.add_argument(
        "--project", required=True,
        help="Git URL or local path to a repository",
    )
    pp.add_argument(
        "--commit", default="",
        help="Git commit to check out before evaluation",
    )
    pp.add_argument(
        "--configs",
        default="glasswing_minimal,sourcehunt_full",
        help="Comma-separated config names (default: glasswing_minimal,sourcehunt_full)",
    )
    pp.add_argument("--model", default=None, help="LLM model name")
    pp.add_argument("--base-url", default=None, help="LLM API base URL")
    pp.add_argument("--api-key", default=None, help="LLM API key")
    pp.add_argument(
        "--budget-per-config", type=float, default=500.0,
        help="USD budget per config per run (default: $500)",
    )
    pp.add_argument(
        "--runs", type=int, default=1,
        help="Runs per config for statistical significance (default: 1)",
    )
    pp.add_argument(
        "--depth", choices=["quick", "standard", "deep"],
        default="standard", help="Hunt depth (default: standard)",
    )
    pp.add_argument(
        "--output-dir", default=None,
        help="Output directory (default: ./results/eval or ~/.clearwing/results/eval)",
    )
    pp.add_argument(
        "--ground-truth", nargs="*", default=None,
        help="Known CVE IDs for recall measurement",
    )
    pp.add_argument(
        "--format", choices=["table", "json", "markdown"],
        default="table", dest="output_format",
        help="Output format (default: table)",
    )

    compare = sub.add_parser(
        "compare",
        help="Compare two eval result files",
    )
    compare.add_argument(
        "results", nargs=2, metavar="FILE",
        help="Two eval result JSON files to compare",
    )
    compare.add_argument(
        "--format", choices=["table", "json", "markdown"],
        default="table", dest="output_format",
        help="Output format (default: table)",
    )

    return parser


def handle(cli, args):
    """Dispatch to the appropriate eval subcommand."""
    action = getattr(args, "eval_action", None)
    if not action:
        cli.console.print(
            "[yellow]Usage: clearwing eval <preprocessing|compare>[/yellow]",
        )
        return

    handlers = {
        "preprocessing": _handle_preprocessing,
        "compare": _handle_compare,
    }
    handler = handlers.get(action)
    if handler:
        handler(cli, args)
    else:
        cli.console.print(f"[red]Unknown action: {action}[/red]")


def _handle_preprocessing(cli, args):
    from ...core.config import default_results_dir
    from ...eval.metrics import format_eval_comparison
    from ...eval.preprocessing import PreprocessingEval
    from ...providers import ProviderManager, resolve_llm_endpoint

    if args.output_dir is None:
        args.output_dir = default_results_dir("eval")

    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s: %(message)s", force=True,
    )

    endpoint = resolve_llm_endpoint(
        cli_model=args.model,
        cli_base_url=args.base_url,
        cli_api_key=args.api_key,
        config_provider=cli.config.get_provider_section() or None,
    )
    cli.console.print(f"[dim]LLM endpoint: {endpoint.describe()}[/dim]")
    provider_manager = ProviderManager.for_endpoint(endpoint)

    config_names = [c.strip() for c in args.configs.split(",") if c.strip()]
    model_name = args.model or endpoint.model or "unknown"

    cli.console.print(
        f"[bold]Preprocessing Evaluation:[/bold] "
        f"configs={','.join(config_names)}, "
        f"budget=${args.budget_per_config:.0f}/config, "
        f"runs={args.runs}",
    )

    evaluator = PreprocessingEval(
        provider_manager=provider_manager,
        project=args.project,
        commit=args.commit,
        configs=config_names,
        model_name=model_name,
        budget_per_config=args.budget_per_config,
        runs=args.runs,
        depth=args.depth,
        output_dir=args.output_dir,
        ground_truth_cves=args.ground_truth,
    )

    result = asyncio.run(evaluator.arun())

    cli.console.print("")
    output = format_eval_comparison(result, fmt=args.output_format)
    cli.console.print(output)


def _handle_compare(cli, args):
    from ...eval.metrics import (
        format_eval_comparison,
        load_eval_result,
    )

    try:
        a = load_eval_result(args.results[0])
        b = load_eval_result(args.results[1])
    except Exception as e:
        cli.console.print(f"[red]Error loading results: {e}[/red]")
        sys.exit(1)

    cli.console.print(
        format_eval_comparison(a, fmt=args.output_format),
    )
    cli.console.print("")
    cli.console.print(
        format_eval_comparison(b, fmt=args.output_format),
    )
