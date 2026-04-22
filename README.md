# Amass Platform Starter Agent

An interactive agent for querying scientific literature and clinical trials via the [amass platform](https://platform.amass.tech/).
Get your `AMASS_API_KEY` at https://platform.amass.tech/ and starter credits will be added to your account.

![agent movie](/assets/intro.mp4)

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
uv run python main.py

# Or seed the first turn directly:
uv run python main.py "Find recruiting Phase 3 lung cancer drug trials"
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
  clients.baml     # LLM client declarations (proxy-routed) and retry policies
  generators.baml  # Code-gen config (Python/Pydantic, async by default)
baml_client/       # Generated — do not edit (gitignored)
amass.py           # Async HTTP client for the amass platform API
main.py            # REPL entry point and agent loop
BAML.md            # Full BAML language reference
AMASS.md           # amass platform API reference
```

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `AMASS_API_KEY` | Yes | Authenticates against the amass platform API |
| `BAML_LOG` | No | Set to `warn` to silence per-call prompt/reply dumps |

### LLM connection (proxy or direct) variables

> ⚠️ **Local adjustment required.** See 'Using your own LLM clients' below.

| Variable | Required | Purpose |
|---|---|---|
| `LITELLM_PROXY_URL` | For LiteLLM proxy | Base URL for the LiteLLM proxy that routes LLM calls |
| `LITELLM_PROXY_KEY` | For LiteLLM proxy | API key for the LiteLLM proxy |
| `OPENAI_API_KEY` | For calling OpenAI directly | Used when bypassing the proxy |
| `ANTHROPIC_API_KEY` | For calling Anthropic directly | Used when bypassing the proxy |

## LLM overview

[BAML](https://docs.boundaryml.com) is a domain-specific language for defining type-safe LLM functions. You write `.baml` source files that declare data models (`class`), LLM-backed functions (`function` with a `prompt` block), clients (`client<llm>`), and inline tests (`test`). A code generator then produces a typed client library you import from your application code.

The workflow:

1. **Edit** `.baml` files in `baml_src/`.
2. **Generate** the client: `uv run baml-cli generate` — this writes `baml_client/` with typed async Python functions and Pydantic models.
3. **Call** from Python: `from baml_client import b` then `await b.YourFunction(...)`.
4. **Test** with inline test blocks: `uv run baml-cli test` (or `uv run baml-cli test -i "Fn:TestName"` for a single test).

### Using your own LLM clients

> ⚠️ **Local adjustment required.** The client blocks in `baml_src/clients.baml` target a specific LiteLLM proxy and the model IDs deployed there. If you are running this demo outside that environment, edit `clients.baml` before `baml-cli generate`: swap `provider` / `base_url` / `api_key` to your own gateway or a direct provider, and replace the `model` strings with IDs your endpoint actually serves. Any function referencing an unmatched client will fail at runtime.

BAML clients are declared in `baml_src/clients.baml`. Each `client<llm>` block specifies a provider and connection options. For convenience, `clients.baml` already includes commented-out templates for calling OpenAI and Anthropic directly — uncomment and adapt them, or add your own client blocks following the patterns below:

**OpenAI directly:**

```baml
client<llm> MyOpenAI {
  provider "openai"
  options {
    api_key env.OPENAI_API_KEY
    model "gpt-5.4"
  }
}
```

**Anthropic directly:**

```baml
client<llm> MyAnthropic {
  provider "anthropic"
  options {
    api_key env.ANTHROPIC_API_KEY
    model "claude-sonnet-4-6-20250514"
  }
}
```

**Any OpenAI-compatible endpoint** (Azure, Together, local vLLM, etc.):

```baml
client<llm> MyCustom {
  provider "openai-generic"
  options {
    base_url env.MY_ENDPOINT_URL
    api_key env.MY_ENDPOINT_KEY
    model "my-model-name"
  }
}
```

Then wire a client to a function by setting the `client` field:

```baml
function MyFunction(input: string) -> string {
  client MyOpenAI
  prompt #"..."#
}
```

You can also compose clients with **fallback** (try the first, fall back to the second) and **round-robin** strategies:

```baml
client<llm> MyFallback {
  provider fallback
  options {
    strategy [MyAnthropic, MyOpenAI]
  }
}
```

After any change to `.baml` files, re-run `uv run baml-cli generate`.
