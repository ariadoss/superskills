"""Config subcommand."""

from rich.panel import Panel


def add_parser(subparsers):
    parser = subparsers.add_parser(
        "config",
        help="Show or edit configuration (including LLM provider setup)",
    )
    parser.add_argument(
        "--set", nargs=2, metavar=("KEY", "VALUE"), help="Set a configuration value"
    )
    parser.add_argument("--save", help="Save configuration to file")
    parser.add_argument(
        "--set-provider",
        nargs="*",
        metavar="KEY=VALUE",
        help=(
            "Configure the default LLM endpoint and persist to "
            "~/.clearwing/config.yaml. Accepts: base_url=..., "
            "api_key=..., model=..., auth=... "
            "Example: clearwing config --set-provider "
            "base_url=https://openrouter.ai/api/v1 "
            "api_key='${OPENROUTER_API_KEY}' "
            "model=anthropic/claude-opus-4"
        ),
    )
    parser.add_argument(
        "--show-provider",
        action="store_true",
        help="Print the current LLM provider configuration (CLI + env + config.yaml merged)",
    )
    return parser


def handle(cli, args):
    """Show or edit configuration."""
    if args.set:
        key, value = args.set
        keys = key.split(".")
        cli.config.set(*keys, value=value)
        cli.console.print(f"[green]Set {key} = {value}[/green]")

    if args.set_provider is not None:
        _apply_set_provider(cli, args.set_provider)
        return

    if args.show_provider:
        _show_provider(cli)
        return

    if args.save:
        cli.config.save(args.save)
        cli.console.print(f"[green]Configuration saved to {args.save}[/green]")

    cli.console.print(Panel(str(cli.config.config), title="Current Configuration"))


def _apply_set_provider(cli, pairs: list[str]) -> None:
    """Persist a `provider:` section to ~/.clearwing/config.yaml.

    Merges with any existing config file — leaves unrelated sections
    (scanning, exploitation, reporting, database) untouched.
    """
    if not pairs:
        cli.console.print(
            "[red]Error: --set-provider requires KEY=VALUE pairs. "
            "Example: --set-provider base_url=https://openrouter.ai/api/v1 "
            "api_key='${OPENROUTER_API_KEY}' model=anthropic/claude-opus-4[/red]"
        )
        return

    updates: dict[str, str] = {}
    for pair in pairs:
        if "=" not in pair:
            cli.console.print(
                f"[red]Error: '{pair}' is not a KEY=VALUE pair. "
                "Expected base_url=... / api_key=... / model=... / auth=...[/red]"
            )
            return
        key, value = pair.split("=", 1)
        key = key.strip().lower()
        if key not in ("base_url", "api_key", "model", "auth"):
            cli.console.print(
                f"[red]Error: unknown provider key '{key}'. "
                "Expected one of: base_url, api_key, model, auth.[/red]"
            )
            return
        updates[key] = value.strip()

    # Merge into the existing provider: section (preserves fields the
    # user didn't override this time).
    current = cli.config.get_provider_section()
    current.update(updates)
    cli.config.set("provider", value=current)

    # Persist to ~/.clearwing/config.yaml, preserving any other sections
    # in the file. We avoid `cli.config.save()` because that would dump
    # the full merged default config (including the 1024-port scanning
    # defaults) — ballooning the file for a 3-key write.
    import yaml

    path = cli.config.DEFAULT_CONFIG_PATH
    path.parent.mkdir(parents=True, exist_ok=True)

    existing: dict = {}
    if path.exists():
        try:
            loaded = yaml.safe_load(path.read_text()) or {}
            if isinstance(loaded, dict):
                existing = loaded
        except Exception:
            existing = {}

    existing["provider"] = current
    path.write_text(yaml.safe_dump(existing, default_flow_style=False, sort_keys=True))

    cli.console.print(f"[green]Saved provider config to {path}[/green]")
    _show_provider(cli)


def _show_provider(cli) -> None:
    """Print the effective provider triple after CLI/env/config merging."""
    from ...providers import resolve_llm_endpoint

    # No CLI flags on `config` — show env + config.yaml state.
    endpoint = resolve_llm_endpoint(
        config_provider=cli.config.get_provider_section(),
    )

    lines = [
        f"  provider: {endpoint.provider}",
        f"  model:    {endpoint.model}",
        f"  base_url: {endpoint.base_url or '(Anthropic direct)'}",
        f"  api_key:  {'(set)' if endpoint.api_key else '(NOT SET)'}",
        f"  source:   {endpoint.source}",
    ]
    cli.console.print(Panel("\n".join(lines), title="LLM Provider", border_style="cyan"))

    # Helpful next-step hints
    file_path = cli.config.DEFAULT_CONFIG_PATH
    if endpoint.source == "default" and not file_path.exists():
        cli.console.print(
            "[yellow]No provider configured. Options:[/yellow]\n"
            "  1. Set ANTHROPIC_API_KEY for Anthropic direct\n"
            "  2. Set CLEARWING_BASE_URL + CLEARWING_API_KEY for an OpenAI-compatible endpoint\n"
            "  3. Run `clearwing config --set-provider base_url=... api_key=... model=...`\n"
            "  4. See `docs/providers.md` for OpenRouter / Ollama / LM Studio / vLLM snippets"
        )
