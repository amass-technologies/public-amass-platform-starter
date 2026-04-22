// Learn more about clients at https://docs.boundaryml.com/docs/snippets/clients/overview
//
// All active clients route through the a LiteLLM proxy (openai-generic provider),
// so only LITELLM_PROXY_URL and LITELLM_PROXY_KEY are required.
//
// ⚠️  LOCAL ADJUSTMENT REQUIRED
// The active client definitions below target the a LiteLLM proxy and the model
// IDs deployed there. If you are running this demo outside that environment
// you MUST edit this file before `baml-cli generate`:
//   • swap `provider` / `base_url` / `api_key` to your own gateway or a
//     direct provider (e.g. `openai`, `anthropic`), and
//   • replace the `model` strings with IDs your endpoint actually serves.
// Any function referencing a client defined here will fail at runtime
// until these values match your local setup.
//
// ── Direct provider examples (commented out) ──────────────────────────────
// Uncomment and set the matching env vars to bypass the LiteLLM proxy and
// call OpenAI or Anthropic directly. Then reference the client by name from
// a function's `client` field (and re-run `baml-cli generate`).

// client<llm> MyOpenAI {
//   provider "openai"
//   options {
//     api_key env.OPENAI_API_KEY
//     model "gpt-5.4"
//   }
// }

// client<llm> MyAnthropic {
//   provider "anthropic"
//   options {
//     api_key env.ANTHROPIC_API_KEY
//     model "claude-sonnet-4-6-20250514"
//   }
// }

// ── GPT-5.4 family ─────────────────────────────────────────────────────────

client<llm> AmassLiteLLMClientGPT54 {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "gpt-5.4-2026-03-05-global"
  }
}

client<llm> AmassLiteLLMClientGPT54mini {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "gpt-5.4-mini-2026-03-17-global"
  }
}


// ── Anthropic family ─────────────────────────


client<llm> AmassLiteLLMClientSonnet46 {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "eu.anthropic.claude-sonnet-4-6"
    default_role "user"
  }
}


client<llm> AmassLiteLLMClientHaiku45 {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "eu.anthropic.claude-haiku-4-5-20251001-v1:0"
    default_role "user"
  }
}

// ── Fallback compositions ──────────────────────────────────────────────────

client<llm> AmassLiteLLMClientSonnet46FallbackToGPT54 {
  provider fallback
  options {
    strategy [
      AmassLiteLLMClientSonnet46
      AmassLiteLLMClientGPT54
    ]
  }
}

client<llm> AmassLiteLLMClientHaiku45FallbackToGPT54mini {
  provider fallback
  options {
    strategy [
      AmassLiteLLMClientHaiku45
      AmassLiteLLMClientGPT54mini
    ]
  }
}


// ── Retry policies ─────────────────────────────────────────────────────────

retry_policy Constant {
  max_retries 3
  strategy {
    type constant_delay
    delay_ms 200
  }
}

retry_policy Exponential {
  max_retries 2
  strategy {
    type exponential_backoff
    delay_ms 300
    multiplier 1.5
    max_delay_ms 10000
  }
}
