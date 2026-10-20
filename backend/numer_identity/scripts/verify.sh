#!/usr/bin/env bash
# proves the identity library is acceptable, run before reporting and in ci
set -euo pipefail
cd "$(dirname "$0")/.."

uv sync --group dev
uv run ruff format --check .
uv run ruff check .
uv run mypy src
uv run pytest --cov=numer_identity --cov-fail-under=95
