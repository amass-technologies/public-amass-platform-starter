# Amass Platform Starter Agent

An interactive agent for querying scientific literature and clinical trials via the [amass platform](https://platform.amass.tech/).
Get your `AMASS_API_KEY` at https://platform.amass.tech/ and starter credits will be added to your account.

https://github.com/user-attachments/assets/e92ab012-10a0-4c76-95be-c3b8e348f033

## Quickstart

Built with [BAML](https://docs.boundaryml.com) for type-safe LLM function calls and managed with `uv`.

```bash
# 0. install uv if you don't have it: https://docs.astral.sh/uv/getting-started/installation/

# 1. Install dependencies
uv sync

# 2. Set up environment variables (see below)
cp .env.example .env
# fill in your keys

# 3. Generate the BAML client (required before first run)
uv run baml-cli generate

# 4. Run the agent
uv run python -m src.main

# Or seed the first turn directly:
uv run python -m src.main "Find recruiting Phase 3 lung cancer drug trials"
```

## How the agent works

The agent runs a **router loop** per user turn. On each step the `RouteQuery` function (a fast, cheap LLM call) picks one tool to execute or emits a `FinalAnswer` to stop. Three pieces of state flow through the loop:

- **`history`** — the last 10 conversation turns (user + assistant), giving the router and summarizer conversational context.
- **`last_results`** — the raw records from the most recent search call. Rendered as a numbered list so the user can say "tell me about #2" and the router resolves it to the right amass ID.
- **`observations`** (intra-turn only) — a scratchpad of `{tool, call, result}` dicts from every tool call within the current turn. Fed back to the router so it can chain calls (e.g. search then drill in), and passed to `SummarizeResult` at the end for synthesis.

The router has a budget of 5 tool calls per turn. If exhausted, a nudge is injected into the scratchpad to force a `FinalAnswer`.

### Available tools for the agent

| Tool | Core | Purpose |
|---|---|---|
| `search_papers` | BioMedCore | Topic search over scientific literature |
| `get_paper` | BioMedCore | Fetch a paper by amass ID (`AMBC_...`) |
| `lookup_paper` | BioMedCore | Resolve a PMID or DOI, then fetch |
| `search_trials` | TrialCore | Topic search over clinical trials |
| `get_trial` | TrialCore | Fetch a trial by amass ID (`AMTC_...`) |
| `lookup_trial` | TrialCore | Resolve an NCT ID, then fetch |

## Project structure

```
baml_src/
  agent.baml       # Tool schemas, RouteQuery + SummarizeResult prompts, tests
  clients.baml     # LLM client declarations (native Anthropic/OpenAI/Google + optional LiteLLM) and retry policies
  generators.baml  # Code-gen config (Python/Pydantic, async by default)
baml_client/       # Generated — do not edit (gitignored)
src/
  __init__.py      # marks src/ as a package so `python -m src.main` works
  amass.py         # Async HTTP client for the amass platform API
  main.py          # REPL entry point and agent loop
BAML.md            # Full BAML language reference
AMASS.md           # amass platform API reference
```

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `AMASS_API_KEY` | Yes | Authenticates against the amass platform API |
| `BAML_LOG` | No | Set to `warn` to silence per-call prompt/reply dumps |

### LLM API keys

By default, the agent calls native providers through a fallback chain: **Anthropic → OpenAI → Google AI**. Set **any one** of the three API keys below to run the agent — the fallback tries each leg in order and uses the first one whose call succeeds. Setting more keys is optional and adds resilience.

| Variable | Required | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | One of the three | First leg of the default fallback chain |
| `OPENAI_API_KEY` | One of the three | Second leg of the default fallback chain |
| `GOOGLE_API_KEY` | One of the three | Third leg of the default fallback chain |
| `LITELLM_PROXY_URL` | Only if using LiteLLM | Base URL for a LiteLLM proxy — see ['Using a LiteLLM proxy instead'](#using-a-litellm-proxy-instead) |
| `LITELLM_PROXY_KEY` | Only if using LiteLLM | API key for the LiteLLM proxy |

## LLM overview

[BAML](https://docs.boundaryml.com) is a domain-specific language for defining type-safe LLM functions. You write `.baml` source files that declare data models (`class`), LLM-backed functions (`function` with a `prompt` block), clients (`client<llm>`), and inline tests (`test`). A code generator then produces a typed client library you import from your application code.

The workflow:

1. **Edit** `.baml` files in `baml_src/`.
2. **Generate** the client: `uv run baml-cli generate` — this writes `baml_client/` with typed async Python functions and Pydantic models.
3. **Call** from Python: `from baml_client import b` then `await b.YourFunction(...)`.
4. **Test** with inline test blocks: `uv run baml-cli test` (or `uv run baml-cli test -i "Fn:TestName"` for a single test).

### Using your own LLM clients

BAML clients are declared in `baml_src/clients.baml`. Out of the box, `clients.baml` defines native-provider clients for Anthropic (Sonnet 4.6, Haiku 4.5), OpenAI (GPT-5.4, GPT-5.4-mini), and Google AI (Gemini 2.5 Pro, Gemini 2.5 Flash), and composes them into two fallback chains that the functions in `agent.baml` reference:

- `MyAnthropicHaikuFallbackToOpenAIMiniToGoogle` — Haiku 4.5 → GPT-5.4-mini → Gemini 2.5 Flash (used by `RouteQuery`, the fast per-step router)
- `MyAnthropicSonnetFallbackToOpenAIToGoogle` — Sonnet 4.6 → GPT-5.4 → Gemini 2.5 Pro (used by `SummarizeResult`, the end-of-turn synthesizer)

Each chain tries Anthropic first, then OpenAI, then Google AI. Set any one of `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GOOGLE_API_KEY` and the agent works; set more for redundancy and resilience.

#### Using a LiteLLM proxy instead

If you prefer to route calls through a [LiteLLM](https://docs.litellm.ai/) proxy, `clients.baml` also defines proxy-backed equivalents (`LiteLLMClient...`) and two fallback compositions that chain the proxy's Anthropic model to its OpenAI model. To switch:

1. Set `LITELLM_PROXY_URL` and `LITELLM_PROXY_KEY` in your `.env`.
2. Edit `baml_src/agent.baml` and change the `client` field on each function:
   - `RouteQuery` → `LiteLLMClientHaiku45FallbackToGPT54mini`
   - `SummarizeResult` → `LiteLLMClientSonnet46FallbackToGPT54`
3. Re-run `uv run baml-cli generate`.

The proxy-backed `model` strings (e.g. `eu.anthropic.claude-sonnet-4-6`) must match IDs your proxy actually serves — adjust them in `clients.baml` if your deployment uses different names.

After any change to `.baml` files, re-run `uv run baml-cli generate`.
