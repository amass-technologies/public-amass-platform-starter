class SearchPapers {
  tool "search_papers" @description("Must be the literal string 'search_papers'.")
  thought string @description("One sentence on why this tool was chosen.")
  query string @description("Free-text query across titles, abstracts, fulltext, and metadata. Author names are indexed, so use this for author follow-ups too.")
  limit int? @description("1 to 300, default 20.")
  min_publication_date string? @description("ISO date lower bound, e.g. 2023-01-01.")
  max_publication_date string? @description("ISO date upper bound, e.g. 2024-12-31.")
  min_journal_quality int? @description("0 to 3. Use 2 when the user asks for high quality or top-tier.")
  min_citation_count int? @description("0 to 100000. Set when the user asks for highly cited or impactful papers.")
}

class GetPaper {
  tool "get_paper" @description("Must be the literal string 'get_paper'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMBC_ id from a prior search result.")
  include_fulltext bool? @description("Default true. Set false only if the user explicitly asks for metadata or authors without the body text.")
  include_references_trialcore bool? @description("Default false. Set true when the user asks about clinical trials related to or evidence-based on this paper. Fetches AMTC_ ids of TrialCore records cross-referenced from this paper.")
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
  limit int? @description("1 to 300, default 20.")
  phase string? @description("One of EARLY_PHASE1, PHASE1, PHASE1/PHASE2, PHASE2, PHASE2/PHASE3, PHASE3, PHASE4, NA. Set only when the user names a phase.")
  overall_status string? @description("One of RECRUITING, NOT_YET_RECRUITING, ENROLLING_BY_INVITATION, ACTIVE_NOT_RECRUITING, SUSPENDED, TERMINATED, COMPLETED, WITHDRAWN, UNKNOWN, WITHHELD, AVAILABLE, NO_LONGER_AVAILABLE, TEMPORARILY_NOT_AVAILABLE, APPROVED_FOR_MARKETING. Set only when the user filters by status (e.g. 'recruiting', 'completed').")
  study_type string? @description("One of INTERVENTIONAL, OBSERVATIONAL, EXPANDED_ACCESS.")
  sponsor_type string? @description("One of NIH, FED, INDUSTRY, OTHER, OTHER_GOV, INDIV, NETWORK. Set only when the user names a sponsor class (e.g. 'industry-sponsored', 'NIH-funded', 'federal').")
  intervention_type string? @description("One of DRUG, DEVICE, BIOLOGICAL, PROCEDURE, RADIATION, BEHAVIORAL, GENETIC, DIETARY_SUPPLEMENT, DIAGNOSTIC_TEST, COMBINATION_PRODUCT, OTHER.")
  facility_countries string? @description("Comma-separated ISO country codes, e.g. 'DE,US'. Set only when the user names one or more countries.")
  min_start_date string? @description("ISO date lower bound for trial start, e.g. 2020-01-01. Set only when the user gives a year or says 'recent'.")
  max_start_date string? @description("ISO date upper bound for trial start, e.g. 2024-12-31. Set when the user constrains how recently a trial began.")
  min_completion_date string? @description("ISO date lower bound for trial completion, e.g. 2026-01-01. Set for 'completing after' queries.")
  max_completion_date string? @description("ISO date upper bound for trial completion, e.g. 2026-01-01. Set for 'completing before' queries.")
  min_enrollment int? @description("Minimum participant count. Set when the user asks for 'large trials' or 'trials with at least N participants'.")
  has_results bool? @description("True only when the user explicitly asks for trials with posted results.")
}

class GetTrial {
  tool "get_trial" @description("Must be the literal string 'get_trial'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMTC_ id from a prior trial search result.")
  include_outcomes bool? @description("Default true. Set false only if the user explicitly wants just the protocol summary without outcome measures.")
  include_references bool? @description("Default false. Set true when the user asks about referenced publications, related papers, or evidence behind a trial. Fetches amass IDs of BioMedCore papers cited by the trial.")
}

class LookupTrial {
  tool "lookup_trial" @description("Must be the literal string 'lookup_trial'.")
  thought string @description("One sentence on why this tool was chosen.")
  nct_id string @description("ClinicalTrials.gov ID, e.g. 'NCT06012345'. Must start with 'NCT'.")
  include_outcomes bool? @description("Default true. Set false only if the user explicitly wants just the protocol summary.")
  include_references bool? @description("Default false. Set true when the user asks about referenced publications, related papers, or evidence behind a trial. Fetches amass IDs of BioMedCore papers cited by the trial.")
}

class SearchDrugs {
  tool "search_drugs" @description("Must be the literal string 'search_drugs'.")
  thought string @description("One sentence on why this tool was chosen.")
  query string @description("Free-text search across drug names, trade names, synonyms, and descriptions. Query by drug-class or compound terms (e.g. 'GLP-1', 'pembrolizumab'), NOT gene/target symbols.")
  limit int? @description("1 to 300, default 20.")
  drug_type string? @description("One of SMALL_MOLECULE, ANTIBODY, PROTEIN, OLIGONUCLEOTIDE, GENE, ENZYME, ANTIBODY_DRUG_CONJUGATE, VACCINE_COMPONENT, CELL, OLIGOSACCHARIDE, VACCINE, UNKNOWN. Set only when the user names a modality.")
  max_clinical_stage string? @description("One of PRECLINICAL, IND, EARLY_PHASE1, PHASE1, PHASE1/PHASE2, PHASE2, PHASE2/PHASE3, PHASE3, PREAPPROVAL, APPROVAL, UNKNOWN. Set only when the user filters by clinical stage (e.g. 'approved drugs' → APPROVAL).")
}

class GetDrug {
  tool "get_drug" @description("Must be the literal string 'get_drug'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMDC_ id from a prior drug search result.")
  include_references_trialcore bool? @description("Default false. Set true when the user asks which clinical trials are associated with this drug. Fetches AMTC_ ids of related TrialCore trials.")
  include_references_biomedcore bool? @description("Default false. Set true when the user asks which publications are associated with this drug. Fetches AMBC_ ids of related BioMedCore papers.")
  include_references_regulatorycore bool? @description("Default false. Set true when the user asks about FDA/EMA approvals or regulatory authorizations for this drug. Fetches AMRC_ ids of related RegulatoryCore authorizations.")
}

class LookupDrug {
  tool "lookup_drug" @description("Must be the literal string 'lookup_drug'.")
  thought string @description("One sentence on why this tool was chosen.")
  chembl_id string @description("ChEMBL molecule ID, e.g. 'CHEMBL1201583'. Must start with 'CHEMBL'.")
}

class SearchRegulatory {
  tool "search_regulatory" @description("Must be the literal string 'search_regulatory'.")
  thought string @description("One sentence on why this tool was chosen.")
  query string @description("Free-text search across product/brand name, active substance, indication, and holder — and the parsed full text of FDA labels/reviews and EMA SmPCs/EPARs. Use a drug name for approval-status questions, or a clinical phrase (e.g. 'immune-mediated hepatitis') to mine the source documents.")
  limit int? @description("1 to 300, default 20.")
  agency string? @description("One of FDA, EMA. Set only when the user restricts to one regulator.")
  molecule_type string? @description("One of SMALL_MOLECULE, ANTIBODY, PROTEIN, ENZYME, OLIGONUCLEOTIDE, GENE, CELL, ANTIBODY_DRUG_CONJUGATE, VACCINE_COMPONENT, VACCINE, OLIGOSACCHARIDE, UNKNOWN.")
  authorization_status string? @description("One of ACTIVE, APPROVED_NOT_MARKETED, CONDITIONAL, SUSPENDED, WITHDRAWN_VOLUNTARY, WITHDRAWN_FORCED, REVOKED, LAPSED_SUNSET, REFUSED, WITHDRAWN_DURING_REVIEW, EXPIRED, UNKNOWN. Set only when the user filters by status (e.g. 'still active', 'withdrawn').")
  has_designation string? @description("One of PRIORITY_REVIEW, BREAKTHROUGH_THERAPY, FAST_TRACK, RMAT, ACCELERATED_APPROVAL, ACCELERATED_ASSESSMENT, PRIME, CONDITIONAL_MA, EXCEPTIONAL_CIRCUMSTANCES. Set only when the user asks about expedited/special pathways.")
  is_orphan bool? @description("True when the user asks for orphan / rare-disease designated products. Cross-walks FDA Orphan Drug and EMA Orphan Medicine.")
  min_authorization_date string? @description("ISO date lower bound, e.g. 2020-01-01. Set only when the user constrains how recently a product was authorized.")
  max_authorization_date string? @description("ISO date upper bound, e.g. 2026-01-01.")
}

class GetRegulatory {
  tool "get_regulatory" @description("Must be the literal string 'get_regulatory'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMRC_ id from a prior regulatory search result.")
  include_fda_details bool? @description("Default false. Set true for FDA-specific fields (application number, label URL, NDC, withdrawal info). Null on EMA records.")
  include_ema_details bool? @description("Default false. Set true for EMA-specific fields (product number, CHMP opinion, biosimilar/ATMP flags, SmPC URL). Null on FDA records.")
  include_references_drugcore bool? @description("Default false. Set true when the user asks about the active ingredient(s). Fetches AMDC_ ids of the DrugCore records for this product.")
}

class LookupRegulatory {
  tool "lookup_regulatory" @description("Must be the literal string 'lookup_regulatory'.")
  thought string @description("One sentence on why this tool was chosen.")
  fda_application_number string? @description("FDA NDA/BLA application number, e.g. 'BLA125514'. Set exactly one identifier on this tool.")
  ema_product_number string? @description("EMA product number, e.g. 'EMEA/H/C/003820'. Set exactly one identifier on this tool.")
  ndc string? @description("FDA National Drug Code, e.g. '0169-4404'. Set exactly one identifier on this tool.")
  spl_set_id string? @description("FDA SPL Set ID (a UUID). Set exactly one identifier on this tool.")
}

class SearchGenes {
  tool "search_genes" @description("Must be the literal string 'search_genes'.")
  thought string @description("One sentence on why this tool was chosen.")
  query string @description("Free-text search across gene symbols, names, synonyms, gene families, RefSeq functional summaries, UniProt keywords, and ChEMBL target class. Use a gene symbol (e.g. 'EGFR'), gene family, or concept (e.g. 'tyrosine kinase', 'GPCR').")
  limit int? @description("1 to 300, default 20.")
  gene_type string? @description("One of PROTEIN_CODING, NCRNA, PSEUDO, TRNA, RRNA, SNRNA, SCRNA, SNORNA, MISCRNA, BIOLOGICAL_REGION, TRANSPOSON, OTHER. Set only when the user names a biotype.")
  target_class string? @description("Top-level ChEMBL target class: one of ENZYME, MEMBRANE_RECEPTOR, ION_CHANNEL, TRANSPORTER, TRANSCRIPTION_FACTOR, EPIGENETIC_REGULATOR, SECRETED_PROTEIN, SURFACE_ANTIGEN, STRUCTURAL_PROTEIN, ADHESION, OTHER_CYTOSOLIC_PROTEIN, OTHER_NUCLEAR_PROTEIN, AUXILIARY_TRANSPORT_PROTEIN, UNCLASSIFIED_PROTEIN. Set only when the user names a target class (e.g. 'kinases' → ENZYME).")
  tractability_modality string? @description("One of SMALL_MOLECULE, ANTIBODY, PROTAC, OTHER_CLINICAL. Set when the user asks about druggability by a specific modality.")
  tractability_stage string? @description("One of APPROVED_DRUG, ADVANCED_CLINICAL, PHASE_1_CLINICAL. Set when the user asks for a clinical-precedent stage (e.g. 'with an approved drug' → APPROVED_DRUG).")
  is_druggable bool? @description("True when the user asks for druggable targets (any small-molecule/antibody tractability bucket).")
  is_essential bool? @description("True when the user asks for essential genes / cancer dependencies (DepMap-essential in at least one screen).")
  has_safety_liabilities bool? @description("True when the user asks for genes with known target-safety liabilities.")
  max_constraint_loeuf float? @description("Keep genes with gnomAD v4.0 LOEUF <= this value (lower = more loss-of-function constrained; gnomAD recommends < 0.6). Set only when the user asks for constrained / mutation-intolerant genes.")
}

class GetGene {
  tool "get_gene" @description("Must be the literal string 'get_gene'.")
  thought string @description("One sentence on why this tool was chosen.")
  amass_id string @description("Canonical AMGC_ id from a prior gene search result.")
  include_protein bool? @description("Default false. Set true when the user asks about the protein: structure/PDB, subcellular localization, function summary, or biophysics (Swiss-Prot).")
  include_references_drugcore bool? @description("Default false. Set true when the user asks which drugs target this gene. Fetches AMDC_ ids of DrugCore records that target the gene.")
}

class LookupGene {
  tool "lookup_gene" @description("Must be the literal string 'lookup_gene'.")
  thought string @description("One sentence on why this tool was chosen.")
  ensembl_gene_id string? @description("Ensembl stable gene id, e.g. 'ENSG00000146648'. Set exactly one identifier on this tool.")
  hgnc_id string? @description("HGNC id with the 'HGNC:' prefix, e.g. 'HGNC:3236'. Set exactly one identifier on this tool.")
  entrez_gene_id string? @description("NCBI Entrez gene id, e.g. '1956'. Set exactly one identifier on this tool.")
  uniprot_id string? @description("UniProt accession, e.g. 'P00533'. Set exactly one identifier on this tool.")
  symbol string? @description("Approved gene symbol, e.g. 'EGFR'. Use for an exact-symbol lookup. Set exactly one identifier on this tool.")
  omim_id string? @description("OMIM id, e.g. '131550'. Set exactly one identifier on this tool.")
  orphanet string? @description("Orphanet id, e.g. '30815'. Set exactly one identifier on this tool.")
  iuphar string? @description("IUPHAR/Guide to Pharmacology target id, e.g. '1797'. Set exactly one identifier on this tool.")
}

class FinalAnswer {
  tool "final_answer" @description("Must be the literal string 'final_answer'. Use when no tool is needed or when prior tool results already answer the user.")
  thought string @description("One sentence on why no further tool call is needed.")
  answer string @description("The user-facing reply.")
}

function RouteQuery(user_query: string, history: string, last_results: string, scratch: string) -> SearchPapers | GetPaper | SearchTrials | GetTrial | LookupPaper | LookupTrial | SearchDrugs | GetDrug | LookupDrug | SearchRegulatory | GetRegulatory | LookupRegulatory | SearchGenes | GetGene | LookupGene | FinalAnswer {
  client MyAnthropicHaikuFallbackToOpenAIMiniToGoogle
  prompt #"
    {{ _.role("system") }}
    You are the router for an agent that may call multiple tools per user turn against the amass
    platform before emitting a final answer. On each step you pick one tool to run OR pick
    final_answer to stop. The platform exposes five cores:
      - BioMedCore     (search_papers / get_paper / lookup_paper)         — published scientific literature.
      - TrialCore      (search_trials / get_trial / lookup_trial)          — clinical trials on ClinicalTrials.gov.
      - DrugCore       (search_drugs / get_drug / lookup_drug)             — drugs & molecules (modality, clinical stage, structure), from ChEMBL.
      - RegulatoryCore (search_regulatory / get_regulatory / lookup_regulatory) — FDA + EMA drug authorizations on a shared schema.
      - GeneCore       (search_genes / get_gene / lookup_gene)             — harmonized genes (HGNC + NCBI) enriched with Open Targets target intelligence.

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
        results or scratchpad. Set include_references_trialcore=true when the user asks which
        clinical trials are tied to or based on this paper — this fetches AMTC ids of TrialCore
        records cross-referenced from the paper (the reverse direction of lookup_trial's
        include_references).
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
        guaranteed to hit the right trial.
      - For both get_trial and lookup_trial: set include_references=true when the user asks about
        referenced publications, related papers, or evidence behind the trial — this fetches
        amass IDs of BioMedCore papers cited by the trial for cross-core enrichment.
      - search_drugs: topic search over DrugCore. Use when the user asks about a drug, molecule,
        drug class, modality, trade name, or "what's approved / in development" for a compound.
        Query by drug-class or compound names (e.g. "GLP-1", "checkpoint inhibitor"), not gene
        symbols. Use drug_type to filter modality and max_clinical_stage to filter by stage.
      - get_drug: fetch a specific DrugCore record by amassId (AMDC_...). Use whenever the user
        wants details about a drug already in the recent results or scratchpad. Set
        include_references_trialcore / include_references_biomedcore / include_references_regulatorycore
        to fan out to the trials, papers, or FDA/EMA approvals tied to the drug.
      - lookup_drug: resolve a ChEMBL id (starts with "CHEMBL") to a DrugCore record. Prefer this
        over search_drugs when the user gives a ChEMBL id.
      - search_regulatory: cross-agency search over RegulatoryCore (FDA + EMA authorizations). Use
        when the user asks whether/where a drug is approved, its authorization status, regulatory
        designations (breakthrough, accelerated, PRIME, orphan), or wants to compare US vs EU. The
        query also full-text-searches the source labels/SmPCs/reviews/EPARs, so a clinical phrase
        (e.g. "immune-mediated hepatitis") surfaces every product whose documents mention it. Use
        agency, molecule_type, authorization_status, has_designation, and is_orphan to filter.
      - get_regulatory: fetch a specific RegulatoryCore record by amassId (AMRC_...). Use for
        details on an authorization already in the recent results or scratchpad. authorizationsByAgency
        (the cross-market US/EU link) is always present; set include_fda_details / include_ema_details
        for agency-specific fields, and include_references_drugcore for the active ingredient(s).
      - lookup_regulatory: resolve an FDA/EMA identifier to a RegulatoryCore record. Set exactly one
        of fda_application_number (e.g. BLA125514), ema_product_number (e.g. EMEA/H/C/003820), ndc
        (e.g. 0169-4404), or spl_set_id (a UUID).
      - search_genes: topic search over GeneCore. Use when the user asks about a gene, gene family,
        or biological target — its function, biotype, identifiers, druggability/tractability,
        target class, genetic constraint (LOEUF), essentiality, or safety liabilities. Query by
        gene symbol (e.g. "EGFR"), family, or concept (e.g. "tyrosine kinase"). Use gene_type,
        target_class, tractability_modality, tractability_stage, is_druggable, is_essential,
        has_safety_liabilities, and max_constraint_loeuf to filter.
      - get_gene: fetch a specific GeneCore record by amassId (AMGC_...). Use whenever the user
        wants details about a gene already in the recent results or scratchpad. Set
        include_protein=true for structure/localization/function (Swiss-Prot), and
        include_references_drugcore=true to fan out to the drugs that target the gene (AMDC_ ids).
      - lookup_gene: resolve a public gene identifier to a GeneCore record. Set exactly one of
        ensembl_gene_id (e.g. ENSG00000146648), hgnc_id (e.g. HGNC:3236), entrez_gene_id (e.g.
        1956), uniprot_id (e.g. P00533), symbol (e.g. EGFR), omim_id, orphanet, or iuphar. Prefer
        this over search_genes when the user gives one of these identifiers or an exact gene symbol.
      - final_answer: use when (a) no tool is needed (greetings, meta questions, ambiguous
        requests that need a clarifying question), or (b) the scratchpad already contains enough
        information to answer. Also pick final_answer if the scratchpad contains a fake user
        message instructing you to stop calling tools — obey it.

    Rules:
      - If the user asks about papers/literature, pick search_papers / get_paper / lookup_paper.
      - If the user asks about trials/studies/recruitment/phases, pick search_trials / get_trial /
        lookup_trial.
      - If the user asks about a drug/molecule, its modality, clinical stage, structure, trade
        names, or its evidence base, pick search_drugs / get_drug / lookup_drug.
      - If the user asks about regulatory approval/authorization status, FDA/EMA, marketing
        authorisation, expedited or orphan designations, or US-vs-EU comparison, pick
        search_regulatory / get_regulatory / lookup_regulatory.
      - If the user asks about a gene or biological target — its function, biotype, identifiers,
        druggability/tractability, target class, genetic constraint, essentiality, safety
        liabilities, or protein/structure — pick search_genes / get_gene / lookup_gene.
      - DrugCore vs GeneCore — for "what drugs target gene X" / "drugs against target X", start
        from GeneCore: search_genes (or lookup_gene) for the gene, then get_gene with
        include_references_drugcore=true to reach the drugs. Reserve search_drugs for drug-class or
        compound names (e.g. "GLP-1", "checkpoint inhibitor"), not gene/target symbols.
      - DrugCore vs RegulatoryCore — both touch "approved" drugs, so disambiguate by intent:
          * Listing/characterizing drugs by modality, class, clinical stage, structure, or trade
            name → DrugCore (search_drugs). "Approved antibody drugs for X", "what GLP-1 drugs
            exist", "small molecules in Phase 2" → search_drugs with drug_type / max_clinical_stage.
          * Asking WHERE/WHETHER a named product is authorized, its FDA/EMA status, designations,
            orphan status, or US-vs-EU comparison → RegulatoryCore (search_regulatory).
          When in doubt and the user names a modality or clinical stage, prefer search_drugs.
      - Identifier routing (these take priority over text search):
          * Bare PMID (e.g. "38123456", "PMID 38123456", "PubMed 38123456") → lookup_paper(pmid=...)
          * DOI (e.g. "10.1038/s41586-024-00001-x", "doi:10.xxxx/...") → lookup_paper(doi=...)
          * NCT id (e.g. "NCT06012345") → lookup_trial(nct_id=...)
          * ChEMBL id (e.g. "CHEMBL1201583") → lookup_drug(chembl_id=...)
          * FDA application number (e.g. "BLA125514", "NDA021986") → lookup_regulatory(fda_application_number=...)
          * EMA product number (e.g. "EMEA/H/C/003820") → lookup_regulatory(ema_product_number=...)
          * Ensembl gene id (e.g. "ENSG00000146648") → lookup_gene(ensembl_gene_id=...)
          * HGNC id (e.g. "HGNC:3236") → lookup_gene(hgnc_id=...)
          * UniProt accession (e.g. "P00533") → lookup_gene(uniprot_id=...)
      - amassId prefix tells you which get tool: AMBC_ → get_paper, AMTC_ → get_trial,
        AMDC_ → get_drug, AMRC_ → get_regulatory, AMGC_ → get_gene.
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
          * user: "Find highly-cited CRISPR papers from 2024"
            → search_papers query: "CRISPR", min_publication_date: "2024-01-01", min_citation_count: 100
          * user: "Find recruiting Phase 3 lung cancer drug trials in the US"
            → search_trials query: "lung cancer", phase: "PHASE3", overall_status: "RECRUITING", intervention_type: "DRUG"
          * user: "Industry-sponsored Phase 3 trials in Germany completing before 2026"
            → search_trials query: "", phase: "PHASE3", sponsor_type: "INDUSTRY", facility_countries: "DE", max_completion_date: "2026-01-01"
          * user: "Large diabetes trials with at least 1000 participants"
            → search_trials query: "diabetes", min_enrollment: 1000
          * user: "What trials reference this paper?" (after a search_papers result, drilling into #1)
            → get_paper amass_id: "AMBC_...", include_references_trialcore: true
          * user: "Look up PMID 38123456"
            → lookup_paper pmid: "38123456"
          * user: "Show me trial NCT06012345"
            → lookup_trial nct_id: "NCT06012345"
          * user: "Fetch DOI 10.1038/s41586-024-00001-x"
            → lookup_paper doi: "10.1038/s41586-024-00001-x"
          * user: "What approved antibody drugs target checkpoint inhibition?"
            → search_drugs query: "checkpoint inhibitor", drug_type: "ANTIBODY", max_clinical_stage: "APPROVAL"
          * user: "Is pembrolizumab approved in both the US and EU?"
            → search_regulatory query: "pembrolizumab", agency: null (omit to get both agencies; read authorizationsByAgency)
          * user: "Which oncology drugs got breakthrough therapy designation?"
            → search_regulatory query: "oncology", has_designation: "BREAKTHROUGH_THERAPY"
          * user: "Show me the active EU orphan drugs authorized since 2020"
            → search_regulatory query: "rare disease", agency: "EMA", is_orphan: true, authorization_status: "ACTIVE", min_authorization_date: "2020-01-01"
          * user: "What trials and approvals are tied to drug #1?" (after a search_drugs result)
            → get_drug amass_id: "AMDC_...", include_references_trialcore: true, include_references_regulatorycore: true
          * user: "Look up CHEMBL1201583"
            → lookup_drug chembl_id: "CHEMBL1201583"
          * user: "Resolve FDA application BLA125514"
            → lookup_regulatory fda_application_number: "BLA125514"
          * user: "Which essential kinases are heavily constrained against loss-of-function?"
            → search_genes query: "kinase", target_class: "ENZYME", is_essential: true, max_constraint_loeuf: 0.6
          * user: "Tell me about the EGFR gene"
            → lookup_gene symbol: "EGFR"
          * user: "What drugs target EGFR?" (start from the gene, then fan out)
            → search_genes query: "EGFR"  (then get_gene amass_id: "AMGC_...", include_references_drugcore: true)
          * user: "Show me the structure and localization of #1" (after a gene search)
            → get_gene amass_id: "AMGC_...", include_protein: true
          * user: "Look up ENSG00000146648"
            → lookup_gene ensembl_gene_id: "ENSG00000146648"
      - Leave min_journal_quality, min_publication_date, max_publication_date, and
        min_citation_count (search_papers); phase / overall_status / study_type /
        sponsor_type / intervention_type / facility_countries / min_start_date /
        max_start_date / min_completion_date / max_completion_date / min_enrollment /
        has_results (search_trials); drug_type / max_clinical_stage (search_drugs); and
        agency / molecule_type / authorization_status / has_designation / is_orphan /
        min_authorization_date / max_authorization_date (search_regulatory); and
        gene_type / target_class / tractability_modality / tractability_stage / is_druggable /
        is_essential / has_safety_liabilities / max_constraint_loeuf (search_genes) null unless
        the user's phrasing explicitly calls for them.
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
    trimmed tool output). Tools come from BioMedCore (papers), TrialCore (clinical trials),
    DrugCore (drugs/molecules), RegulatoryCore (FDA/EMA authorizations), or GeneCore (genes).
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
          Trials referenced: if the result contains a "_references" array of TrialCore trials,
          render a small sub-list at the end as "Trials referenced (from TrialCore):" with one
          line per trial: <briefTitle> — <sponsorName> (<phase>, <overallStatus>) — AMTC_...
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
      - search_drugs: produce a numbered list (1., 2., ...) with, per drug:
          <name> — <drugType>, <maxClinicalStage>
          amassId: AMDC_...   trade names: <up to 3>   ChEMBL: <chemblId or dash>
          One-sentence note from description if it adds info.
        After the list, give a 1-2 sentence synthesis answering the user's question.
      - get_drug / lookup_drug: produce a structured summary:
          Name, synonyms (cap at 4), trade names (cap at 4), drugType, maxClinicalStage,
          chemblId, structure (inchiKey / canonicalSmiles when present), amassId.
          Description if present.
          Cross-core links: if the result has "_referencesTrialCore", "_referencesBiomedCore",
          or "_referencesRegulatoryCore" arrays, render a sub-list per non-empty one —
          "Trials (from TrialCore):", "Publications (from BioMedCore):", "Authorizations
          (from RegulatoryCore):" — one line per linked record with its title/name and amassId.
      - search_regulatory: produce a numbered list (1., 2., ...) with, per authorization:
          <name> — <agency> · <authorizationStatus>
          amassId: AMRC_...   active substance: <activeSubstance>   holder: <marketingAuthorisationHolder>   authorized: <authorizationDate>
          If the record has a non-empty documentSections array, note the matching source
          section(s) (docType + title) and the matchedText excerpt — this is full-text
          evidence from the label/SmPC/review/EPAR.
          If the record has authorizationsByAgency entries, note the cross-market counterpart(s)
          as <agency>: <authorizationStatus>.
        After the list, give a 1-2 sentence synthesis. For US-vs-EU comparison questions, lead
        with the status divergence read straight off authorizationsByAgency.
      - get_regulatory / lookup_regulatory: produce a structured summary:
          Name, agency, activeSubstance, moleculeType, authorizationStatus, procedureType,
          therapeuticIndication, marketingAuthorisationHolder, authorization/firstAuthorization
          dates, isOrphan, amassId, sourceUrl.
          Designations: one bullet per entry — <type> (<axis>)<, post-marketing obligation if true>.
          Cross-market: render authorizationsByAgency as "Other markets:" with one line per
          entry: <agency> — <name> (<authorizationStatus>) — AMRC_...
          fdaDetails / emaDetails: surface the agency-specific fields when present.
          If "_referencesDrugCore" is present, list the active-ingredient DrugCore records.
      - search_genes: produce a numbered list (1., 2., ...) with, per gene:
          <symbol> — <name> (<geneType>)
          amassId: AMGC_...   Ensembl: ENSG...   location: <location or dash>
          One-sentence note from the summary if it adds info. If target intelligence is present,
          add a short tag: druggable / essential / LOEUF <lossOfFunction.loeuf> / target class.
        After the list, give a 1-2 sentence synthesis answering the user's question.
      - get_gene / lookup_gene: produce a structured summary:
          Symbol, name, synonyms (cap at 4), geneType, location / chromosome / strand,
          identifiers (Ensembl, HGNC, Entrez, UniProt), amassId.
          Summary: the RefSeq functional description if present.
          Target intelligence (when present): tractability modalities with clinical buckets;
          targetClass path; gnomAD constraint (LOEUF = lossOfFunction.loeuf, pLI); DepMap
          essentiality (isEssential + dependent/tested cell lines).
          Protein (when the result has a "protein" object): subcellular locations, whether a 3D
          structure exists (a few PDB ids), function summary.
          Cross-core: if "_referencesDrugCore" is present, render "Drugs targeting this gene
          (from DrugCore):" with one line per drug — <name> (<drugType>, <maxClinicalStage>) — AMDC_...

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

test TestRouteHighlyCitedDateRange {
  functions [RouteQuery]
  args {
    user_query "Find highly-cited CRISPR papers from 2024"
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

test TestRouteGetPaperWithTrialRefs {
  functions [RouteQuery]
  args {
    user_query "What clinical trials reference #1?"
    history "user: Find papers on osimertinib in EGFR-mutant NSCLC\nassistant: (lists 3 papers)"
    last_results "1. Osimertinib in untreated EGFR-mutated advanced NSCLC — Soria JC et al. (2018) — AMBC_example001\n2. Adjuvant osimertinib in resected EGFR-mutated NSCLC — Wu YL et al. (2020) — AMBC_example002\n3. Osimertinib for unresectable stage III NSCLC — Reck M et al. (2023) — AMBC_example003"
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

test TestRouteSearchTrialsSponsorCountryCompletion {
  functions [RouteQuery]
  args {
    user_query "Industry-sponsored Phase 3 trials in Germany completing before 2026"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchTrialsLargeEnrollment {
  functions [RouteQuery]
  args {
    user_query "Large diabetes trials with at least 1000 participants"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchTrialsMaxStartDate {
  functions [RouteQuery]
  args {
    user_query "Alzheimer's trials that started no later than 2022"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchTrialsCompletingAfter {
  functions [RouteQuery]
  args {
    user_query "Multiple sclerosis trials completing after 2027"
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

test TestRouteGetTrialWithReferences {
  functions [RouteQuery]
  args {
    user_query "What papers does #2 cite?"
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

test TestRouteSearchDrugsModalityStage {
  functions [RouteQuery]
  args {
    user_query "What approved antibody drugs target checkpoint inhibition?"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteGetDrugWithRefs {
  functions [RouteQuery]
  args {
    user_query "What trials and FDA/EMA approvals are tied to #1?"
    history "user: Find approved checkpoint inhibitor antibodies\nassistant: (lists 3 drugs)"
    last_results "1. Pembrolizumab — ANTIBODY, APPROVAL — AMDC_example001\n2. Nivolumab — ANTIBODY, APPROVAL — AMDC_example002\n3. Atezolizumab — ANTIBODY, APPROVAL — AMDC_example003"
    scratch ""
  }
}

test TestRouteLookupDrugChembl {
  functions [RouteQuery]
  args {
    user_query "Look up CHEMBL1201583"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchRegulatoryCompareMarkets {
  functions [RouteQuery]
  args {
    user_query "Is pembrolizumab approved in both the US and the EU?"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchRegulatoryDesignation {
  functions [RouteQuery]
  args {
    user_query "Which oncology drugs reached the market on a breakthrough therapy designation?"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchRegulatoryOrphan {
  functions [RouteQuery]
  args {
    user_query "Show me the active EU orphan drugs authorized since 2020"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteSearchRegulatoryDocFullText {
  functions [RouteQuery]
  args {
    user_query "Which approved drugs mention immune-mediated hepatitis in their label?"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteLookupRegulatoryFda {
  functions [RouteQuery]
  args {
    user_query "Resolve FDA application BLA125514"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteGetRegulatory {
  functions [RouteQuery]
  args {
    user_query "Tell me more about #1, including the FDA-specific details"
    history "user: Is pembrolizumab approved in the US and EU?\nassistant: (lists FDA + EMA authorizations)"
    last_results "1. Keytruda — FDA · ACTIVE — AMRC_example001\n2. Keytruda — EMA · ACTIVE — AMRC_example002"
    scratch ""
  }
}

test TestSummarizeSearchDrugs {
  functions [SummarizeResult]
  args {
    user_query "What approved antibody drugs target checkpoint inhibition?"
    history ""
    observations_json "[{\"tool\":\"search_drugs\",\"call\":\"search_drugs(query='checkpoint inhibitor', drug_type=ANTIBODY, max_clinical_stage=APPROVAL)\",\"result\":[{\"amassId\":\"AMDC_ex001\",\"chemblId\":\"CHEMBL3137343\",\"name\":\"Pembrolizumab\",\"description\":\"Anti-PD-1 monoclonal antibody approved for multiple oncology indications.\",\"synonyms\":[\"MK-3475\",\"lambrolizumab\"],\"tradeNames\":[\"Keytruda\"],\"drugType\":\"ANTIBODY\",\"maxClinicalStage\":\"APPROVAL\"},{\"amassId\":\"AMDC_ex002\",\"chemblId\":\"CHEMBL3707227\",\"name\":\"Nivolumab\",\"description\":\"Anti-PD-1 monoclonal antibody.\",\"synonyms\":[\"BMS-936558\"],\"tradeNames\":[\"Opdivo\"],\"drugType\":\"ANTIBODY\",\"maxClinicalStage\":\"APPROVAL\"}]}]"
  }
}

test TestSummarizeGetDrugWithRefs {
  functions [SummarizeResult]
  args {
    user_query "What trials and approvals are tied to pembrolizumab?"
    history ""
    observations_json "[{\"tool\":\"get_drug\",\"call\":\"get_drug(amass_id='AMDC_ex001', include_references_trialcore=True, include_references_regulatorycore=True)\",\"result\":{\"amassId\":\"AMDC_ex001\",\"chemblId\":\"CHEMBL3137343\",\"name\":\"Pembrolizumab\",\"description\":\"Anti-PD-1 monoclonal antibody.\",\"tradeNames\":[\"Keytruda\"],\"drugType\":\"ANTIBODY\",\"maxClinicalStage\":\"APPROVAL\",\"_referencesTrialCore\":[{\"amassId\":\"AMTC_ex001\",\"nctId\":\"NCT02142738\",\"briefTitle\":\"Pembrolizumab vs Chemo in NSCLC\",\"sponsorName\":\"Merck\",\"phase\":\"PHASE3\",\"overallStatus\":\"COMPLETED\"}],\"_referencesRegulatoryCore\":[{\"amassId\":\"AMRC_ex001\",\"agency\":\"FDA\",\"name\":\"Keytruda\",\"authorizationStatus\":\"ACTIVE\"}]}}]"
  }
}

test TestSummarizeSearchRegulatoryCompareMarkets {
  functions [SummarizeResult]
  args {
    user_query "Is pembrolizumab approved in both the US and the EU?"
    history ""
    observations_json "[{\"tool\":\"search_regulatory\",\"call\":\"search_regulatory(query='pembrolizumab')\",\"result\":[{\"amassId\":\"AMRC_ex001\",\"agency\":\"FDA\",\"name\":\"Keytruda\",\"activeSubstance\":\"pembrolizumab\",\"moleculeType\":\"ANTIBODY\",\"authorizationStatus\":\"ACTIVE\",\"marketingAuthorisationHolder\":\"Merck Sharp & Dohme\",\"authorizationDate\":\"2014-09-04\",\"authorizationsByAgency\":[{\"amassId\":\"AMRC_ex002\",\"agency\":\"EMA\",\"name\":\"Keytruda\",\"authorizationStatus\":\"ACTIVE\"}],\"documentSections\":[]}]}]"
  }
}

test TestSummarizeGetRegulatory {
  functions [SummarizeResult]
  args {
    user_query "Tell me more about the FDA authorization for Keytruda"
    history ""
    observations_json "[{\"tool\":\"get_regulatory\",\"call\":\"get_regulatory(amass_id='AMRC_ex001', include_fda_details=True)\",\"result\":{\"amassId\":\"AMRC_ex001\",\"agency\":\"FDA\",\"name\":\"Keytruda\",\"activeSubstance\":\"pembrolizumab\",\"moleculeType\":\"ANTIBODY\",\"authorizationStatus\":\"ACTIVE\",\"procedureType\":\"BLA\",\"therapeuticIndication\":\"Multiple oncology indications including melanoma and NSCLC.\",\"marketingAuthorisationHolder\":\"Merck Sharp & Dohme\",\"authorizationDate\":\"2014-09-04\",\"firstAuthorizationDate\":\"2014-09-04\",\"isOrphan\":false,\"sourceUrl\":\"https://www.accessdata.fda.gov/\",\"designations\":[{\"axis\":\"REVIEW_ACCELERATION\",\"type\":\"BREAKTHROUGH_THERAPY\",\"agency\":\"FDA\",\"nativeName\":\"Breakthrough Therapy\",\"postMarketingObligation\":false},{\"axis\":\"EARLY_ACCESS_BASIS\",\"type\":\"ACCELERATED_APPROVAL\",\"agency\":\"FDA\",\"nativeName\":\"Accelerated Approval\",\"basis\":\"SURROGATE_ENDPOINT\",\"postMarketingObligation\":true}],\"authorizationsByAgency\":[{\"amassId\":\"AMRC_ex002\",\"agency\":\"EMA\",\"name\":\"Keytruda\",\"authorizationStatus\":\"ACTIVE\"}],\"fdaDetails\":{\"applicationNumber\":\"BLA125514\",\"prescriptionClass\":\"Prescription\",\"labelUrl\":\"https://www.accessdata.fda.gov/label.pdf\",\"ndc\":[\"0006-3026\"]}}}]"
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

test TestRouteSearchGenesConstraint {
  functions [RouteQuery]
  args {
    user_query "Which essential kinases are heavily constrained against loss-of-function?"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteLookupGeneSymbol {
  functions [RouteQuery]
  args {
    user_query "Tell me about the EGFR gene"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteLookupGeneEnsembl {
  functions [RouteQuery]
  args {
    user_query "Look up ENSG00000146648"
    history ""
    last_results ""
    scratch ""
  }
}

test TestRouteGetGeneWithDrugRefs {
  functions [RouteQuery]
  args {
    user_query "What drugs target #1?"
    history "user: Find druggable kinases\nassistant: (lists 3 genes)"
    last_results "1. EGFR — epidermal growth factor receptor (PROTEIN_CODING) — AMGC_example001\n2. JAK2 — Janus kinase 2 (PROTEIN_CODING) — AMGC_example002\n3. MTOR — mechanistic target of rapamycin kinase (PROTEIN_CODING) — AMGC_example003"
    scratch ""
  }
}

test TestRouteGetGeneProtein {
  functions [RouteQuery]
  args {
    user_query "Show me the structure and subcellular localization of #3"
    history "user: Find druggable kinases\nassistant: (lists 3 genes)"
    last_results "1. EGFR — epidermal growth factor receptor (PROTEIN_CODING) — AMGC_example001\n2. JAK2 — Janus kinase 2 (PROTEIN_CODING) — AMGC_example002\n3. MTOR — mechanistic target of rapamycin kinase (PROTEIN_CODING) — AMGC_example003"
    scratch ""
  }
}

test TestSummarizeSearchGenes {
  functions [SummarizeResult]
  args {
    user_query "Which essential kinases are heavily constrained against loss-of-function?"
    history ""
    observations_json "[{\"tool\":\"search_genes\",\"call\":\"search_genes(query='kinase', target_class=ENZYME, is_essential=True, max_constraint_loeuf=0.6)\",\"result\":[{\"amassId\":\"AMGC_ex001\",\"ensemblGeneId\":\"ENSG00000198793\",\"symbol\":\"MTOR\",\"name\":\"mechanistic target of rapamycin kinase\",\"geneType\":\"PROTEIN_CODING\",\"location\":\"1p36.22\",\"summary\":\"Serine/threonine kinase that regulates cell growth and metabolism.\",\"gnomadConstraint\":{\"lossOfFunction\":{\"loeuf\":0.09,\"pli\":1.0}},\"depmapEssentiality\":{\"isEssential\":true,\"cellLinesTested\":842,\"dependentCellLines\":712}},{\"amassId\":\"AMGC_ex002\",\"ensemblGeneId\":\"ENSG00000175054\",\"symbol\":\"ATR\",\"name\":\"ATR serine/threonine kinase\",\"geneType\":\"PROTEIN_CODING\",\"location\":\"3q23\",\"gnomadConstraint\":{\"lossOfFunction\":{\"loeuf\":0.14,\"pli\":1.0}},\"depmapEssentiality\":{\"isEssential\":true,\"cellLinesTested\":842,\"dependentCellLines\":684}}]}]"
  }
}

test TestSummarizeGetGeneWithDrugRefs {
  functions [SummarizeResult]
  args {
    user_query "Tell me about EGFR and what drugs target it, including its structure"
    history ""
    observations_json "[{\"tool\":\"get_gene\",\"call\":\"get_gene(amass_id='AMGC_ex001', include_protein=True, include_references_drugcore=True)\",\"result\":{\"amassId\":\"AMGC_ex001\",\"ensemblGeneId\":\"ENSG00000146648\",\"symbol\":\"EGFR\",\"name\":\"epidermal growth factor receptor\",\"synonyms\":[\"ERBB\",\"ERBB1\",\"HER1\"],\"geneType\":\"PROTEIN_CODING\",\"location\":\"7p11.2\",\"chromosome\":\"7\",\"strand\":\"+\",\"entrezGeneId\":\"1956\",\"hgncId\":\"HGNC:3236\",\"uniprotIds\":[\"P00533\"],\"summary\":\"Receptor tyrosine kinase binding EGF; drives proliferation and is frequently mutated in NSCLC.\",\"targetClass\":{\"path\":[\"Enzyme\",\"Kinase\",\"Protein Kinase\"]},\"gnomadConstraint\":{\"lossOfFunction\":{\"loeuf\":0.28,\"pli\":0.98}},\"depmapEssentiality\":{\"isEssential\":true,\"cellLinesTested\":842,\"dependentCellLines\":114},\"protein\":{\"function\":{\"subcellularLocations\":[\"Cell membrane\",\"Endosome\"],\"functionSummary\":\"Receptor tyrosine-protein kinase.\"},\"structure\":{\"has3dStructure\":true,\"pdbIds\":[\"1IVO\",\"1M14\",\"2ITY\"]}},\"_referencesDrugCore\":[{\"amassId\":\"AMDC_ex001\",\"name\":\"Osimertinib\",\"drugType\":\"SMALL_MOLECULE\",\"maxClinicalStage\":\"APPROVAL\"},{\"amassId\":\"AMDC_ex002\",\"name\":\"Amivantamab\",\"drugType\":\"ANTIBODY\",\"maxClinicalStage\":\"APPROVAL\"}]}}]"
  }
}
