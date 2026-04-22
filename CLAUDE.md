# CLAUDE.md aka AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Project

Python 3.13+ demo agent built around [BAML](https://docs.boundaryml.com) for type-safe LLM function calls. Managed with `uv`. `BAML.md` is a full BAML language reference kept in-repo — consult it before writing `.baml` code.

The amass platform API reference is found in `AMASS.md`. The `biomedcore` and `trialcore` cores are the focus of this demo, but the agent can be easily extended to call other cores or API endpoints by adding new BAML functions.

## Commands

```bash
uv sync                    # install/refresh deps from pyproject.toml + uv.lock
uv run baml-cli generate   # regenerate baml_client/ from baml_src/ — REQUIRED after any .baml edit
uv run baml-cli test       # run tests defined in .baml files (use -i "Fn:Test" for one)
uv run python main.py      # run the entry point
```

`baml_client/` is gitignored. If it's missing (e.g. fresh clone), run `baml-cli generate` before executing Python code that imports from it.

## Architecture

The runtime split is BAML-source → generated-client → Python caller:

- **`baml_src/*.baml`** — hand-written source of truth. `clients.baml` declares LLM clients. `generators.baml` targets `python/pydantic` with `default_client_mode async`, so generated functions are `async` by default. Feature files like `agent.baml` define `class` data models, `function` LLM calls, and inline `test` blocks.
- **`baml_client/`** — generated, do not edit. Import as `from baml_client import b` for functions and `from baml_client.types import ...` for Pydantic models. Because the default mode is async, call sites need `await b.FunctionName(...)`.
- **`main.py`** — REPL entry point. Runs a router loop per user turn: `RouteQuery` picks one tool (search/get/lookup for papers or trials) or emits `FinalAnswer`; `SummarizeResult` synthesizes at end-of-turn. Maintains `history`, `last_results`, and per-turn `observations`.
- **`amass.py`** — async HTTP client for the amass platform API, wrapping `biomedcore` and `trialcore`.

When adding an LLM capability: define the class + function in a new or existing `baml_src/*.baml` file, add a `test` block, run `baml-cli generate`, then `await b.NewFunction(...)` from Python.

Required env vars depend on the client referenced by the function.
