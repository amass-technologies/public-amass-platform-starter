// Learn more about clients at https://docs.boundaryml.com/docs/snippets/clients/overview
//
// The functions in agent.baml call native providers directly through two
// fallback chains: Anthropic → OpenAI → Google AI. Set ANY ONE of
// ANTHROPIC_API_KEY, OPENAI_API_KEY, or GOOGLE_API_KEY to run the agent —
// the fallback tries each leg in order and uses the first one whose call
// succeeds. Setting more keys just adds resilience.
//
// LiteLLM proxy clients are defined further below and are NOT referenced by
// any function by default. To route through a LiteLLM proxy instead, set
// LITELLM_PROXY_URL + LITELLM_PROXY_KEY and swap the `client` field in
// agent.baml:
//   RouteQuery       → LiteLLMClientHaiku45FallbackToGPT54mini
//   SummarizeResult  → LiteLLMClientSonnet46FallbackToGPT54
// Then re-run `baml-cli generate`.
//
// ── Direct provider clients ───────────────────────────────────────────────

client<llm> MyAnthropicSonnet46 {
  provider "anthropic"
  options {
    api_key env.ANTHROPIC_API_KEY
    model "claude-sonnet-4-6"
  }
}

client<llm> MyAnthropicHaiku45 {
  provider "anthropic"
  options {
    api_key env.ANTHROPIC_API_KEY
    model "claude-haiku-4-5"
  }
}

client<llm> MyOpenAIGPT54 {
  provider "openai"
  options {
    api_key env.OPENAI_API_KEY
    model "gpt-5.4"
  }
}

client<llm> MyOpenAIGPT54Mini {
  provider "openai"
  options {
    api_key env.OPENAI_API_KEY
    model "gpt-5.4-mini"
  }
}

client<llm> MyGoogleAIGemini25Pro {
  provider google-ai
  options {
    api_key env.GOOGLE_API_KEY
    model "gemini-2.5-pro"
  }
}

client<llm> MyGoogleAIGemini25Flash {
  provider google-ai
  options {
    api_key env.GOOGLE_API_KEY
    model "gemini-2.5-flash"
  }
}

// ── Native provider fallback compositions ─────────────────────────────────
// Anthropic first, OpenAI second, Google third — all calling native APIs
// directly. Used by the BAML functions in agent.baml.

client<llm> MyAnthropicSonnetFallbackToOpenAIToGoogle {
  provider fallback
  options {
    strategy [
      MyAnthropicSonnet46
      MyOpenAIGPT54
      MyGoogleAIGemini25Pro
    ]
  }
}

client<llm> MyAnthropicHaikuFallbackToOpenAIMiniToGoogle {
  provider fallback
  options {
    strategy [
      MyAnthropicHaiku45
      MyOpenAIGPT54Mini
      MyGoogleAIGemini25Flash
    ]
  }
}

// ── GPT-5.4 family via LiteLLM proxy ─────────────────────────────────────────────────────────

client<llm> LiteLLMClientGPT54 {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "gpt-5.4-2026-03-05-global"
  }
}

client<llm> LiteLLMClientGPT54mini {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "gpt-5.4-mini-2026-03-17-global"
  }
}


// ── Anthropic family via LiteLLM proxy ─────────────────────────


client<llm> LiteLLMClientSonnet46 {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "eu.anthropic.claude-sonnet-4-6"
    default_role "user"
  }
}


client<llm> LiteLLMClientHaiku45 {
  provider "openai-generic"
  options {
    base_url env.LITELLM_PROXY_URL
    api_key env.LITELLM_PROXY_KEY
    model "eu.anthropic.claude-haiku-4-5-20251001-v1:0"
    default_role "user"
  }
}

// ── Fallback compositions via LiteLLM proxy ──────────────────────────────────────────────────

client<llm> LiteLLMClientSonnet46FallbackToGPT54 {
  provider fallback
  options {
    strategy [
      LiteLLMClientSonnet46
      LiteLLMClientGPT54
    ]
  }
}

client<llm> LiteLLMClientHaiku45FallbackToGPT54mini {
  provider fallback
  options {
    strategy [
      LiteLLMClientHaiku45
      LiteLLMClientGPT54mini
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
