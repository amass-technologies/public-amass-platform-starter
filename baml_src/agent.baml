class SearchPapers {
  tool "search_papers" @description("Must be the literal string 'search_papers'.")
  thought string @description("One sentence on why this tool was chosen.")
  query string @description("Free-text query across titles, abstracts, fulltext, and metadata. Author names are indexed, so use this for author follow-ups too.")
  limit int? @description("1 to 50, default 10.")
  min_publication_date string? @description("ISO date lower bound, e.g. 2023-01-01.")
  min_journal_quality int? @description("0 to 3. Use 2 when the user asks for high quality or top-tier.")
}

class GetPaper {
  tool "get_paper" @description("Must be the literal string 'get_paper'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMBC_ id from a prior search result.")
  include_fulltext bool? @description("Default true. Set false only if the user explicitly asks for metadata or authors without the body text.")
}

class LookupPaper {
  tool "lookup_paper" @description("Must be the literal string 'lookup_paper'.")
  thought string @description("One sentence on why this tool was chosen.")
  pmid string? @description("PubMed ID, digits only (e.g. '38123456'). Set this OR doi, never both.")
  doi string? @description("Digital Object Identifier (e.g. '10.1038/s41586-024-00001-x'). Set this OR pmid, never both.")
  include_fulltext bool? @description("Default true. Set false only if the user explicitly asks for metadata without the body text.")
}

class SearchTrials {
  tool "search_trials" @description("Must be the literal string 'search_trials'.")
  thought string @description("One sentence on why this tool was chosen.")
  query string @description("Free-text search across trial titles, summaries, conditions, interventions, sponsors. NCT ids can also be passed here.")
  limit int? @description("1 to 50, default 10.")
  phase string? @description("One of EARLY_PHASE1, PHASE1, PHASE1/PHASE2, PHASE2, PHASE2/PHASE3, PHASE3, PHASE4, NA. Set only when the user names a phase.")
  overall_status string? @description("One of RECRUITING, NOT_YET_RECRUITING, ENROLLING_BY_INVITATION, ACTIVE_NOT_RECRUITING, SUSPENDED, TERMINATED, COMPLETED, WITHDRAWN, UNKNOWN, WITHHELD, AVAILABLE, NO_LONGER_AVAILABLE, TEMPORARILY_NOT_AVAILABLE, APPROVED_FOR_MARKETING. Set only when the user filters by status (e.g. 'recruiting', 'completed').")
  study_type string? @description("One of INTERVENTIONAL, OBSERVATIONAL, EXPANDED_ACCESS.")
  intervention_type string? @description("One of DRUG, DEVICE, BIOLOGICAL, PROCEDURE, RADIATION, BEHAVIORAL, GENETIC, DIETARY_SUPPLEMENT, DIAGNOSTIC_TEST, COMBINATION_PRODUCT, OTHER.")
  min_start_date string? @description("ISO date lower bound for trial start, e.g. 2020-01-01. Set only when the user gives a year or says 'recent'.")
  has_results bool? @description("True only when the user explicitly asks for trials with posted results.")
}

class GetTrial {
  tool "get_trial" @description("Must be the literal string 'get_trial'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMTC_ id from a prior trial search result.")
  include_outcomes bool? @description("Default true. Set false only if the user explicitly wants just the protocol summary without outcome measures.")
}

class LookupTrial {
  tool "lookup_trial" @description("Must be the literal string 'lookup_trial'.")
  thought string @description("One sentence on why this tool was chosen.")
  nct_id string @description("ClinicalTrials.gov ID, e.g. 'NCT06012345'. Must start with 'NCT'.")
  include_outcomes bool? @description("Default true. Set false only if the user explicitly wants just the protocol summary.")
  include_references bool? @description("Default false. Set true when the user asks about referenced publications, related papers, or evidence behind a trial. Fetches amass IDs of BioMedCore papers cited by the trial.")
}

class FinalAnswer {
  tool "final_answer" @description("Must be the literal string 'final_answer'. Use when no tool is needed or when prior tool results already answer the user.")
  thought string @description("One sentence on why no further tool call is needed.")
  answer string @description("The user-facing reply.")
}

function RouteQuery(user_query: string, history: string, last_results: string, scratch: string) -> SearchPapers | GetPaper | SearchTrials | GetTrial | LookupPaper | LookupTrial | FinalAnswer {
  client MyAnthropicHaikuFallbackToOpenAIMiniToGoogle
  prompt #"
    {{ _.role("system") }}
    You are the router for an agent that may call multiple tools per user turn against the amass
    platform before emitting a final answer. On each step you pick one tool to run OR pick
    final_answer to stop. The platform exposes two cores:
      - BioMedCore (search_papers / get_paper / lookup_paper) — published scientific literature.
      - TrialCore  (search_trials / get_trial / lookup_trial) — clinical trials on ClinicalTrials.gov.

    CRITICAL — read the scratchpad FIRST on every step:
      - The scratchpad lists every tool call already made this turn together with its result.
      - If any prior step in the scratchpad already answers the user, pick final_answer now.
      - NEVER repeat a call that is already in the scratchpad.
      - If the scratchpad ends with a fake "user:" message telling you the tool budget is
        exhausted, obey it and pick final_answer.

    Tools:
      - search_papers: topic search over BioMedCore. Also use this for "what else has author X
        written" — put the author name (and any topic hint) into the query string.
      - get_paper: fetch a specific BioMedCore record by amassId (AMBC_...). Use whenever the
        user wants full text, author affiliations, or details about a paper already in the recent
        results or scratchpad.
      - lookup_paper: resolve a public identifier (PMID or DOI) to a BioMedCore record AND fetch
        it in one call. Use whenever the user gives a PMID (digits, often introduced as "PMID
        12345678" or "PubMed 12345678") or a DOI (looks like "10.xxxx/..."). Set exactly one of
        pmid or doi, never both.
      - search_trials: topic search over TrialCore. Use when the user asks about ongoing studies,
        recruitment, trial phases, sponsors, interventions, or anything trial-shaped without a
        specific NCT id.
      - get_trial: fetch a specific TrialCore record by amassId (AMTC_...). Use whenever the user
        wants details, outcomes, or referenced publications of a trial already in the recent
        results or scratchpad.
      - lookup_trial: resolve an NCT id to a TrialCore record AND fetch it in one call. Use
        whenever the user gives an NCT id (starts with "NCT" followed by digits, e.g.
        NCT06012345). Prefer this over search_trials for direct NCT lookups — it's faster and
        guaranteed to hit the right trial. Set include_references=true when the user asks about
        referenced publications, related papers, or evidence behind the trial — this fetches
        amass IDs of BioMedCore papers cited by the trial for cross-core enrichment.
      - final_answer: use when (a) no tool is needed (greetings, meta questions, ambiguous
        requests that need a clarifying question), or (b) the scratchpad already contains enough
        information to answer. Also pick final_answer if the scratchpad contains a fake user
        message instructing you to stop calling tools — obey it.

    Rules:
      - If the user asks about papers/literature, pick search_papers / get_paper / lookup_paper.
      - If the user asks about trials/studies/recruitment/phases, pick search_trials / get_trial /
        lookup_trial.
      - Identifier routing (these take priority over text search):
          * Bare PMID (e.g. "38123456", "PMID 38123456", "PubMed 38123456") → lookup_paper(pmid=...)
          * DOI (e.g. "10.1038/s41586-024-00001-x", "doi:10.xxxx/...") → lookup_paper(doi=...)
          * NCT id (e.g. "NCT06012345") → lookup_trial(nct_id=...)
      - amassId prefix tells you which get tool: AMBC_ → get_paper, AMTC_ → get_trial.
      - When the user references a result by number (#1), title, or trial acronym (e.g. "the
        ALPHA3 trial", "KEYNOTE-189"), resolve it against the Recent results list below — pick
        get_paper or get_trial based on the amassId prefix. If no match is in Recent results,
        fall back to search_trials with the acronym as the query.
      - Query construction (both search tools): keep it short and nominal. Use the 2-6 content
        words that most directly name the topic. Drop conversational words like "how", "what",
        "changed over time", "evolution", "history", "review". The amass index does best with
        concise noun phrases.
          * user: "What are the hallmarks of cancer and how have they changed over time?"
            → search_papers query: "hallmarks of cancer"
          * user: "What else has D Hanahan published on cancer biology since 2015?"
            → search_papers query: "Hanahan cancer biology"
          * user: "Find recruiting Phase 3 lung cancer drug trials in the US"
            → search_trials query: "lung cancer", phase: "PHASE3", overall_status: "RECRUITING", intervention_type: "DRUG"
          * user: "Look up PMID 38123456"
            → lookup_paper pmid: "38123456"
          * user: "Show me trial NCT06012345"
            → lookup_trial nct_id: "NCT06012345"
          * user: "Fetch DOI 10.1038/s41586-024-00001-x"
            → lookup_paper doi: "10.1038/s41586-024-00001-x"
      - Leave min_journal_quality and min_publication_date (search_papers) and phase /
        overall_status / study_type / intervention_type / min_start_date / has_results
        (search_trials) null unless the user's phrasing explicitly calls for them.
        Do NOT apply filters just because the topic sounds foundational or important.
      - Never invent an amassId; only use IDs that appear in the Recent results block or the
        scratchpad.

    {{ _.role("user") }}
    Conversation so far:
    {{ history }}

    Recent results (numbered; use these to resolve references like #2):
    {{ last_results }}

    Scratchpad (tool calls + results already made this turn — do NOT repeat any call that appears
    here; if it already answers the user, pick final_answer):
    {{ scratch }}

    New user message:
    {{ user_query }}

    {{ ctx.output_format }}
  "#
}

function SummarizeResult(user_query: string, history: string, observations_json: string) -> string {
  client MyAnthropicSonnetFallbackToOpenAIToGoogle
  prompt #"
    {{ _.role("system") }}
    You turn raw amass platform API results into a concise, user-facing reply. The observations
    are a JSON array — each element represents one tool call made during this user turn and has
    three fields: tool (the tool name), call (a human-readable call signature), and result (the
    trimmed tool output). Tools come from BioMedCore (papers) or TrialCore (clinical trials).
    Multiple observations may appear when the agent chained calls (e.g. search_trials then
    get_trial on the top hit).

    Synthesize a single reply that draws on all observations. Apply the per-tool formatting rules
    below to each observation's result, then weave the pieces together so the reply directly
    answers the user's question.

    Formatting rules by tool:
      - search_papers: produce a numbered list (1., 2., ...) with, per paper:
          <title> — <first 2 authors et al.> (<year>, <journal>)
          amassId: AMBC_...   citations: N   quality: 0 to 3 or dash
          One-sentence takeaway if the abstract supports it.
        If any result is retracted, prefix that line with [RETRACTED]. After the list, give a
        1-2 sentence synthesis answering the user's question.
      - get_paper / lookup_paper: produce a structured summary:
          Title, authors (list first + last with affiliation + country if available, then count
          of remaining co-authors), journal/year, amassId.
          Key findings: 2 to 4 bullets grounded in the abstract/fulltext.
          Methods: 1 bullet if discernible.
          Note if the fulltext was truncated.
          Prefix with [RETRACTED] if applicable.
      - search_trials: produce a numbered list (1., 2., ...) with, per trial:
          [<acronym>] <briefTitle> — <sponsorName> (<phase>, <overallStatus>)
          amassId: AMTC_...   nctId: NCT...   enrollment: N   country(s): XX, YY
          One-sentence summary from briefSummary if it adds info beyond the title.
          Omit the [<acronym>] prefix when acronym is null/empty.
        After the list, give a 1-2 sentence synthesis answering the user's question.
      - get_trial / lookup_trial: produce a structured summary:
          Title (brief + official if they differ), acronym if present, sponsor + collaborators,
          phase, status, studyType, amassId, nctId, start/completion dates, enrollment.
          Conditions: comma-separated list (cap at 6).
          Interventions: <type>: <name> bullets (cap at 6).
          Design: allocation / model / primaryPurpose / masking when present.
          Primary outcomes: 2 to 4 bullets from primaryOutcomeMeasures.
          If whyStopped is present, surface it.
          References: if the result contains a "_references" array of BioMedCore papers, render
          a small sub-list at the end as "References (from BioMedCore):" with one line per
          paper: <title> — <first author> et al. (<year>) — AMBC_...

    When multiple observations are present, render them in the order they were made. If a later
    observation drills into a result from an earlier one (e.g. get_trial on #1 of a prior
    search_trials), you may render only the drilled-in detail and reference the list position
    rather than repeating the full list — use judgment based on what best answers the user.

    Focus on what the data contains, not on what is missing. Present the available information
    confidently — do not caveat with "no X was found" or "the data does not include Y". If a
    field is absent, simply leave it out of the reply. Never invent facts. Keep it tight — no
    preamble.

    {{ _.role("user") }}
    User's question: {{ user_query }}

    Conversation so far:
    {{ history }}

    Observations (JSON array, may be truncated):
    {{ observations_json }}

    {{ ctx.output_format }}
  "#
}

// ===== Tests =====

test TestRouteTopicSearch {
  functions [RouteQuery]
  args {
    user_query "Find recent high-quality papers on CRISPR gene editing from 2024"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteGetPaper {
  functions [RouteQuery]
  args {
    user_query "Show me the full text and author affiliations for #1"
    history "user: What are the hallmarks of cancer and how have they changed over time?\nassistant: (lists 3 review papers on the hallmarks framework)"
    last_results "1. Hallmarks of Cancer: The Next Generation — Hanahan D et al. (2011, Cell) — AMBC_example001\n2. Hallmarks of Cancer: New Dimensions — Hanahan D et al. (2022, Cancer Discovery) — AMBC_example002\n3. The Hallmarks of Cancer — Hanahan D, Weinberg RA (2000, Cell) — AMBC_example003"
    scratch ""
  }
}

test TestRouteSearchTrials {
  functions [RouteQuery]
  args {
    user_query "Find recruiting Phase 3 lung cancer drug trials in the US"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteGetTrial {
  functions [RouteQuery]
  args {
    user_query "Tell me more about #2"
    history "user: Find recruiting Phase 3 lung cancer drug trials\nassistant: (lists 3 trials)"
    last_results "1. A Study of Pembrolizumab in NSCLC — Merck (PHASE3, RECRUITING) — AMTC_example001\n2. Osimertinib in EGFR-mutant NSCLC — AstraZeneca (PHASE3, RECRUITING) — AMTC_example002\n3. Adagrasib for KRAS G12C NSCLC — Mirati (PHASE3, RECRUITING) — AMTC_example003"
    scratch ""
  }
}

test TestRouteLookupPaperPmid {
  functions [RouteQuery]
  args {
    user_query "Look up PMID 38123456"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteLookupPaperDoi {
  functions [RouteQuery]
  args {
    user_query "Fetch DOI 10.1038/s41586-024-00001-x"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteLookupTrial {
  functions [RouteQuery]
  args {
    user_query "Show me trial NCT06012345"
    history ""
    last_results ""
    scratch ""
  }
}

// Multi-tool: scratch shows a completed search_trials; router should drill into #1 with get_trial.
test TestRouteMultiToolDrillIn {
  functions [RouteQuery]
  args {
    user_query "Find recruiting Phase 3 lung cancer drug trials and tell me about the top one."
    history ""
    last_results "1. Pembrolizumab vs Chemo in NSCLC — Merck (PHASE3, RECRUITING) — AMTC_example001\n2. Osimertinib in EGFRm NSCLC — AstraZeneca (PHASE3, RECRUITING) — AMTC_example002"
    scratch "[1] search_trials(query='lung cancer', limit=10, phase=PHASE3, overall_status=RECRUITING, intervention_type=DRUG)\n  -> 2 trial(s):\n    1. Pembrolizumab vs Chemo in NSCLC - Merck (PHASE3, RECRUITING) - AMTC_example001\n    2. Osimertinib in EGFRm NSCLC - AstraZeneca (PHASE3, RECRUITING) - AMTC_example002"
  }
}

// Budget exhaustion: scratch contains a fake user nudge; router must pick final_answer.
test TestRouteBudgetExhausted {
  functions [RouteQuery]
  args {
    user_query "Find recruiting Phase 3 lung cancer drug trials and tell me about the top one."
    history ""
    last_results "1. Pembrolizumab vs Chemo in NSCLC - Merck (PHASE3, RECRUITING) - AMTC_example001"
    scratch "[1] search_trials(query='lung cancer', limit=10, phase=PHASE3, overall_status=RECRUITING, intervention_type=DRUG)\n  -> 1 trial(s):\n    1. Pembrolizumab vs Chemo in NSCLC - Merck (PHASE3, RECRUITING) - AMTC_example001\n\nuser: You have used your tool budget. Answer now using only the information above. Do not request another tool."
  }
}

test TestSummarizeSearch {
  functions [SummarizeResult]
  args {
    user_query "What are the hallmarks of cancer and how have they changed over time?"
    history ""
    observations_json "[{\"tool\":\"search_papers\",\"call\":\"search_papers(query='hallmarks of cancer', limit=10)\",\"result\":[{\"amassId\":\"AMBC_ex001\",\"title\":\"The Hallmarks of Cancer\",\"authors\":[\"Hanahan D\",\"Weinberg RA\"],\"journal\":\"Cell\",\"publicationDate\":\"2000-01-07\",\"citationCount\":52000,\"journalQualityJufo\":3,\"isRetracted\":false,\"abstract\":\"We suggest six hallmarks of cancer: sustained proliferative signaling, evading growth suppressors, resisting cell death, enabling replicative immortality, inducing angiogenesis, and activating invasion and metastasis.\"},{\"amassId\":\"AMBC_ex002\",\"title\":\"Hallmarks of Cancer: The Next Generation\",\"authors\":[\"Hanahan D\",\"Weinberg RA\"],\"journal\":\"Cell\",\"publicationDate\":\"2011-03-04\",\"citationCount\":48000,\"journalQualityJufo\":3,\"isRetracted\":false,\"abstract\":\"An updated framework adds reprogramming energy metabolism and evading immune destruction as emerging hallmarks.\"},{\"amassId\":\"AMBC_ex003\",\"title\":\"Hallmarks of Cancer: New Dimensions\",\"authors\":[\"Hanahan D\"],\"journal\":\"Cancer Discovery\",\"publicationDate\":\"2022-01-01\",\"citationCount\":6500,\"journalQualityJufo\":3,\"isRetracted\":false,\"abstract\":\"Four new dimensions: unlocking phenotypic plasticity, nonmutational epigenetic reprogramming, polymorphic microbiomes, and senescent cells.\"}]}]"
  }
}

test TestSummarizeGetPaper {
  functions [SummarizeResult]
  args {
    user_query "Show me the full text and author affiliations for #1"
    history "user: What are the hallmarks of cancer?\nassistant: (lists 3 review papers)"
    observations_json "[{\"tool\":\"get_paper\",\"call\":\"get_paper(amass_id='AMBC_ex002', include_fulltext=True)\",\"result\":{\"amassId\":\"AMBC_ex002\",\"title\":\"Hallmarks of Cancer: The Next Generation\",\"authors\":[\"Hanahan D\",\"Weinberg RA\"],\"journal\":\"Cell\",\"publicationDate\":\"2011-03-04\",\"citationCount\":48000,\"journalQualityJufo\":3,\"isRetracted\":false,\"abstract\":\"An updated framework ...\",\"fulltext\":\"[truncated] The hallmarks of cancer comprise six biological capabilities acquired during the multistep development of human tumors ...\",\"authorsMetadata\":[{\"name\":\"Hanahan D\",\"nameRaw\":\"Douglas Hanahan\",\"position\":0,\"affiliations\":[{\"name\":\"Swiss Institute for Experimental Cancer Research\",\"countryCode\":\"CH\"}]},{\"name\":\"Weinberg RA\",\"nameRaw\":\"Robert A. Weinberg\",\"position\":1,\"affiliations\":[{\"name\":\"Whitehead Institute for Biomedical Research\",\"countryCode\":\"US\"}]}]}}]"
  }
}

test TestSummarizeSearchTrials {
  functions [SummarizeResult]
  args {
    user_query "Find recruiting Phase 3 lung cancer drug trials"
    history ""
    observations_json "[{\"tool\":\"search_trials\",\"call\":\"search_trials(query='lung cancer', phase=PHASE3, overall_status=RECRUITING, intervention_type=DRUG)\",\"result\":[{\"amassId\":\"AMTC_ex001\",\"nctId\":\"NCT05000001\",\"briefTitle\":\"Pembrolizumab vs Chemo in NSCLC\",\"sponsorName\":\"Merck Sharp & Dohme\",\"phase\":\"PHASE3\",\"overallStatus\":\"RECRUITING\",\"enrollment\":1200,\"facilityCountries\":[\"US\",\"DE\"],\"briefSummary\":\"Comparing pembrolizumab monotherapy to platinum-doublet chemotherapy in PD-L1 positive NSCLC.\"},{\"amassId\":\"AMTC_ex002\",\"nctId\":\"NCT05000002\",\"briefTitle\":\"Osimertinib in EGFRm NSCLC\",\"sponsorName\":\"AstraZeneca\",\"phase\":\"PHASE3\",\"overallStatus\":\"RECRUITING\",\"enrollment\":850,\"facilityCountries\":[\"US\",\"JP\",\"GB\"],\"briefSummary\":\"Adjuvant osimertinib after surgical resection in EGFR-mutant stage IB-IIIA NSCLC.\"}]}]"
  }
}

test TestSummarizeGetTrial {
  functions [SummarizeResult]
  args {
    user_query "Tell me more about #2"
    history "user: Find Phase 3 lung cancer trials\nassistant: (lists trials)"
    observations_json "[{\"tool\":\"get_trial\",\"call\":\"get_trial(amass_id='AMTC_ex002', include_outcomes=True)\",\"result\":{\"amassId\":\"AMTC_ex002\",\"nctId\":\"NCT05000002\",\"briefTitle\":\"Osimertinib in EGFRm NSCLC\",\"officialTitle\":\"A Phase III Study of Adjuvant Osimertinib in EGFR-Mutant NSCLC\",\"sponsorName\":\"AstraZeneca\",\"collaborators\":[\"Memorial Sloan Kettering\"],\"phase\":\"PHASE3\",\"overallStatus\":\"RECRUITING\",\"studyType\":\"INTERVENTIONAL\",\"startDate\":\"2023-04-01\",\"completionDate\":\"2028-12-31\",\"enrollment\":850,\"conditions\":[\"Non-Small Cell Lung Cancer\",\"EGFR Mutation\"],\"interventionTypes\":[\"DRUG\",\"DRUG\"],\"interventionNames\":[\"Osimertinib\",\"Placebo\"],\"facilityCountries\":[\"US\",\"JP\",\"GB\"],\"primaryOutcomeMeasures\":[\"Disease-Free Survival\",\"Overall Survival\"],\"designAllocation\":\"RANDOMIZED\",\"designInterventionModel\":\"PARALLEL\",\"designPrimaryPurpose\":\"TREATMENT\",\"designMasking\":\"DOUBLE\",\"referencesBiomedCore\":[\"AMBC_ref001\"],\"_references\":[{\"amassId\":\"AMBC_ref001\",\"title\":\"Osimertinib in untreated EGFR-mutated advanced NSCLC\",\"authors\":[\"Soria JC\",\"Ohe Y\"],\"journal\":\"NEJM\",\"publicationDate\":\"2018-01-11\",\"citationCount\":3200,\"journalQualityJufo\":3}]}}]"
  }
}

// Multi-observation synthesis: search_trials then get_trial on the top hit.
test TestSummarizeMultiTool {
  functions [SummarizeResult]
  args {
    user_query "Find recruiting Phase 3 lung cancer drug trials and give me details on the top one."
    history ""
    observations_json "[{\"tool\":\"search_trials\",\"call\":\"search_trials(query='lung cancer', phase=PHASE3, overall_status=RECRUITING, intervention_type=DRUG, limit=10)\",\"result\":[{\"amassId\":\"AMTC_ex001\",\"nctId\":\"NCT05000001\",\"briefTitle\":\"Pembrolizumab vs Chemo in NSCLC\",\"sponsorName\":\"Merck\",\"phase\":\"PHASE3\",\"overallStatus\":\"RECRUITING\",\"enrollment\":1200,\"facilityCountries\":[\"US\",\"DE\"]},{\"amassId\":\"AMTC_ex002\",\"nctId\":\"NCT05000002\",\"briefTitle\":\"Osimertinib in EGFRm NSCLC\",\"sponsorName\":\"AstraZeneca\",\"phase\":\"PHASE3\",\"overallStatus\":\"RECRUITING\",\"enrollment\":850,\"facilityCountries\":[\"US\",\"JP\"]}]},{\"tool\":\"get_trial\",\"call\":\"get_trial(amass_id='AMTC_ex001')\",\"result\":{\"amassId\":\"AMTC_ex001\",\"nctId\":\"NCT05000001\",\"briefTitle\":\"Pembrolizumab vs Chemo in NSCLC\",\"sponsorName\":\"Merck\",\"phase\":\"PHASE3\",\"overallStatus\":\"RECRUITING\",\"studyType\":\"INTERVENTIONAL\",\"enrollment\":1200,\"conditions\":[\"Non-Small Cell Lung Cancer\"],\"interventionTypes\":[\"DRUG\",\"DRUG\"],\"interventionNames\":[\"Pembrolizumab\",\"Platinum-doublet chemotherapy\"],\"primaryOutcomeMeasures\":[\"Progression-Free Survival\",\"Overall Survival\"],\"designAllocation\":\"RANDOMIZED\",\"designInterventionModel\":\"PARALLEL\",\"designPrimaryPurpose\":\"TREATMENT\"}}]"
  }
}
