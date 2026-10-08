#!/usr/bin/env bash
# cli_fixture <dir>: builds the book-inventory repo for the cli-for-agent eval.
# Base: inventory.py (Book dataclass, in-memory store, JSON load/save) +
# README specifying the shelfy CLI. The agent's task is to BUILD the CLI, so
# the fixture ships the library and spec, not the CLI. Domain deliberately
# disjoint from the skill's mycli/deploy examples (anti-leakage).
cli_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: cli_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > inventory.py <<'EOF'
import json
from dataclasses import dataclass, asdict


@dataclass
class Book:
    isbn: str
    title: str
    genre: str
    rating: int  # 1-5


class Inventory:
    def __init__(self):
        self._books = []

    def add(self, book):
        if any(b.isbn == book.isbn for b in self._books):
            raise ValueError(f"duplicate isbn: {book.isbn}")
        self._books.append(book)

    def by_genre(self, genre):
        return [b for b in self._books if b.genre == genre]

    def save(self, path):
        with open(path, "w") as f:
            json.dump([asdict(b) for b in self._books], f, indent=2)

    @classmethod
    def load(cls, path):
        inv = cls()
        with open(path) as f:
            for row in json.load(f):
                inv.add(Book(**row))
        return inv
EOF
  cat > README.md <<'EOF'
# shelfy

Personal book inventory. The `inventory.py` module holds the logic; we need a
command-line interface named `shelfy` (runnable as `python -m shelfy`) exposing:
add a book by ISBN/title/genre/rating, list books filtered by genre, export the
inventory to a JSON file, and initialize a new inventory file.
EOF
  git add -A && git commit -qm "base: inventory library + shelfy spec"
  )
}
