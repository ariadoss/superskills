"""Command-line interface for Clearwing.

This module provides the thin dispatcher; each subcommand lives in its own
module under ``clearwing.ui.commands``.
"""

import argparse
import logging

from rich.console import Console

from clearwing import __version__

from ..core import Config, CoreEngine
from .commands import ALL_COMMANDS

logger = logging.getLogger(__name__)


class CLI:
    """Command-line interface for Clearwing."""

    def __init__(self):
        self.console = Console()
        self.config = Config()
        self.engine = CoreEngine(self.config)

    def run(self, args: list | None = None) -> None:
        """Run the CLI."""
        parser = self._create_parser()
        parsed_args = parser.parse_args(args)

        # Dispatch to the matching command module. A module's base name
        # matches the subcommand it registers; command modules may also
        # declare an `ALIASES` tuple so `clearwing init` can route to
        # `setup`, etc.
        for cmd_module in ALL_COMMANDS:
            cmd_name = cmd_module.__name__.rsplit(".", 1)[-1]
            aliases = getattr(cmd_module, "ALIASES", ())
            if parsed_args.command == cmd_name or parsed_args.command in aliases:
                cmd_module.handle(self, parsed_args)
                return

        parser.print_help()

    def _create_parser(self) -> argparse.ArgumentParser:
        """Create argument parser with subcommands from command modules."""
        parser = argparse.ArgumentParser(
            prog="clearwing",
            description="Clearwing - Comprehensive Vulnerability Scanner and Exploiter",
        )
        parser.add_argument(
            "-V",
            "--version",
            action="version",
            version=f"clearwing {__version__}",
        )

        subparsers = parser.add_subparsers(dest="command", help="Available commands")

        for cmd_module in ALL_COMMANDS:
            cmd_module.add_parser(subparsers)

        return parser
