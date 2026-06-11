# LLM Quick Reference

Are you an LLM? Start here. This page is self-contained.

```
Base URL:       https://api.amass.tech/api/v1
Auth:           Authorization: Bearer amass_YOUR_KEY  (required on every request)
Content-Type:   application/json  (for POST bodies)
Rate limit:     60 requests / 60 seconds
Response shape: { "data": ... }
Errors:         { "error": { "status", "code", "message" } }
OpenAPI spec:   https://api.amass.tech/api/doc/openapi.json
```

---

## CRITICAL — Read First

1. **Responses are wrapped in `{"data": ...}`.** Always read from the `data` key, not the top-level object. Errors use a different shape: `{"error": {...}}`.
2. **Every request needs auth.** No anonymous access. Omitting `Authorization` -> 401.
3. **Amass IDs are canonical.** The get-by-ID endpoints take Amass IDs only (`AMBC_...`, `AMTC_...`, `AMDC_...`, `AMRC_...`). If you have PMIDs/DOIs/NCTs/ChEMBL IDs or FDA/EMA identifiers, convert them via the lookup endpoints first.
4. **Batch lookup items can fail independently.** Always check each item for `error` before reading `amassIds`. Each item takes exactly one identifier (e.g. `pmid` or `doi`, not both).
5. **Don't request `fulltext` unless you need it.** It massively increases response size. Use the `include` param only when required.
6. **Rate limits are per user+org, not per key.** Multiple keys for the same user share the same quota. On 429, read `Retry-After` and back off exponentially.

---

## Cores

Cores are domain-specific datasets. Each Core lives under `/v1/cores/{coreName}/`. All Cores share auth, error format, and rate limits. Endpoints and schemas are Core-specific.

| Core | Path | Status |
| --- | --- | --- |
| **BiomedCore** | `/v1/cores/biomedcore/` | Available |
| **TrialCore** | `/v1/cores/trialcore/` | Available |
| **DrugCore** | `/v1/cores/drugcore/` | Available |
| **RegulatoryCore** | `/v1/cores/regulatorycore/` | Available |

---

## BiomedCore Endpoints

### 1. Search

```
GET /v1/cores/biomedcore/records?query={text}
```

| Param | Required | Type | Notes |
| --- | --- | --- | --- |
| `query` | yes | string | Search across titles, abstracts, fulltext, metadata |
| `limit` | no | int | 1–300, default 20 |
| `include` | no | string | One or more of: `fulltext`, `authorsMetadata`, `meshIds`, `substanceIds`, `referencesTrialCore`, `references`, `citedBy`. Repeat for multiple: `include=fulltext&include=authorsMetadata` |
| `minPublicationDate` | no | ISO date | e.g. `2023-01-01` |
| `maxPublicationDate` | no | ISO date | e.g. `2026-01-01` |
| `minCitationCount` | no | int | 0–100000 |
| `minJournalQualityJufo` | no | enum | `0`, `1`, `2`, or `3` (3 = top-tier) |
| `isRetracted` | no | bool | `true` or `false` |
| `authorOrcids` | no | string | Repeat for multiple. OR within param. Bare (`0000-...`) or URL form. |
| `authorNames` | no | string | Repeat for multiple. OR within param. Free-text token (PubMed indexes as `LastName Initials`). |
| `institutionRors` | no | string | Repeat for multiple. OR within param. Bare (`03vek6s52`) or URL form. |
| `institutionNames` | no | string | Repeat for multiple. OR within param. Free-text token. |

Author/institution filters: **OR within one filter, AND across filters.** `?authorNames=Hassabis&institutionNames=DeepMind` means *(any Hassabis author) AND (any DeepMind affiliation)* — they don't have to be the same author. Pair with `include=authorsMetadata` to verify the match.

```bash
curl "https://api.amass.tech/api/v1/cores/biomedcore/records?query=CRISPR&limit=5&minJournalQualityJufo=2" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

### 2. Get by Amass ID

```
GET /v1/cores/biomedcore/records/{amassId}
```

Returns 404 if not found.

### 3. Batch Lookup (PMID/DOI -> Amass ID)

```
POST /v1/cores/biomedcore/records/lookup
```

Each item must have exactly one of `pmid` or `doi`. Not both.

```json
{"items": [{"pmid": "38123456"}, {"doi": "10.1038/s41586-024-00001-x"}]}
```

Returns `[{"amassIds": ["AMBC_..."]}, {"error": "..."}]` — one entry per input item.

---

## BiomedCore Record Schema

**Default fields:**

```
amassId           string       AMBC_... (canonical ID)
pmid              string|null  PubMed ID
pmcid             string|null  PubMed Central ID
doi               string|null  Digital Object Identifier
title             string|null
abstract          string|null
authors           string[]     e.g. ["Smith J", "Doe A"]
journal           string|null
issn              string|null
volumeIssue       string|null
publicationDate   string|null  ISO date
publicationTypes  string[]     e.g. ["Journal Article", "Review"]
language          string|null  e.g. "eng"
citationCount     number|null
journalQualityJufo number|null 0=low, 1=peer-reviewed, 2=domain-leading, 3=highest, null=not evaluated
meshTerms         string[]
keywords          string[]
substances        string[]
hasFulltext       boolean|null
isRetracted       boolean|null
```

**Optional fields (`include` param):** `fulltext`, `authorsMetadata`, `meshIds`, `substanceIds`, `referencesTrialCore`, `references`, `citedBy`

Reference fields:

- `references`, `citedBy` — **intra-core links within BiomedCore.** Arrays of `AMBC_...` IDs pointing to other publications.
- `referencesTrialCore` — **cross-core link to TrialCore.** Array of `AMTC_...` IDs pointing to associated clinical trials.

```
intra-core (within BiomedCore):

   AMBC_aaa ─cites─┐                  ┌─► AMBC_p001
                   │                  ├─► AMBC_p002
                   │   ┌──────────┐   │
                   ├──►│  AMBC_X  │───┤      ⋮
                   │   └──────────┘   │
                   │                  ├─► AMBC_p051
   AMBC_bbb ─cites─┘                  └─► AMBC_p052

   AMBC_X.citedBy    = [AMBC_aaa, AMBC_bbb]            ← 2 IDs
   AMBC_X.references = [AMBC_p001, …, AMBC_p052]      ← 52 IDs

cross-core (BiomedCore → TrialCore):

                          ┌─► AMTC_t01
                          ├─► AMTC_t02
   ┌──────────┐           │
   │  AMBC_X  │ ─────────►┤      ⋮
   └──────────┘           │
                          ├─► AMTC_t04
                          └─► AMTC_t05

   AMBC_X.referencesTrialCore = [AMTC_t01, …, AMTC_t05]    ← 5 IDs
```

---

## TrialCore Endpoints

### 1. Search

```
GET /v1/cores/trialcore/records?query={text}
```

| Param | Required | Type | Notes |
| --- | --- | --- | --- |
| `query` | yes | string | Search text |
| `limit` | no | int | 1–300, default 20 |
| `include` | no | string | One or more of: `detailedDescription`, `outcomes`, `referencesBiomedCore`. Repeat for multiple: `include=outcomes&include=referencesBiomedCore` |
| `phase` | no | enum | `EARLY_PHASE1`, `PHASE1`, `PHASE1/PHASE2`, `PHASE2`, `PHASE2/PHASE3`, `PHASE3`, `PHASE4`, `NA` |
| `overallStatus` | no | enum | `RECRUITING`, `NOT_YET_RECRUITING`, `ENROLLING_BY_INVITATION`, `ACTIVE_NOT_RECRUITING`, `SUSPENDED`, `TERMINATED`, `COMPLETED`, `WITHDRAWN`, `UNKNOWN`, `WITHHELD`, `AVAILABLE`, `NO_LONGER_AVAILABLE`, `TEMPORARILY_NOT_AVAILABLE`, `APPROVED_FOR_MARKETING` |
| `studyType` | no | enum | `INTERVENTIONAL`, `OBSERVATIONAL`, `EXPANDED_ACCESS` |
| `sponsorType` | no | enum | `NIH`, `FED`, `INDUSTRY`, `OTHER`, `OTHER_GOV`, `INDIV`, `NETWORK` |
| `interventionType` | no | enum | `DRUG`, `DEVICE`, `BIOLOGICAL`, `PROCEDURE`, `RADIATION`, `BEHAVIORAL`, `GENETIC`, `DIETARY_SUPPLEMENT`, `DIAGNOSTIC_TEST`, `COMBINATION_PRODUCT`, `OTHER` |
| `facilityCountries` | no | string | Comma-separated ISO codes, e.g. `DE,US` |
| `hasResults` | no | bool | `true` or `false` |
| `minStartDate` | no | ISO date | e.g. `2020-01-01` |
| `maxStartDate` | no | ISO date | |
| `minCompletionDate` | no | ISO date | |
| `maxCompletionDate` | no | ISO date | |
| `minEnrollment` | no | int | Minimum participants |

```bash
curl "https://api.amass.tech/api/v1/cores/trialcore/records?query=breast+cancer&phase=PHASE3&overallStatus=RECRUITING&limit=10" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

### 2. Get by Amass ID

```
GET /v1/cores/trialcore/records/{amassId}
```

Returns 404 if not found.

### 3. Batch Lookup (NCT ID -> Amass ID)

```
POST /v1/cores/trialcore/records/lookup
```

Each item must have `nctId`.

```json
{"items": [{"nctId": "NCT06012345"}, {"nctId": "NCT05999999"}]}
```

Returns `[{"amassIds": ["AMTC_..."]}, {"error": "..."}]` — one entry per input item.

---

## TrialCore Record Schema

**Default fields:**

```
amassId                   string       AMTC_... (canonical ID)
nctId                     string|null  ClinicalTrials.gov ID
briefTitle                string|null
officialTitle             string|null
briefSummary              string|null
acronym                   string|null  e.g. KEYNOTE-189
phase                     string|null  e.g. PHASE3
overallStatus             string|null  e.g. RECRUITING
studyType                 string|null  e.g. INTERVENTIONAL
startDate                 string|null  ISO date
completionDate            string|null  ISO date
lastUpdateDate            string|null  ISO date
hasResults                boolean
enrollment                number|null
enrollmentType            string|null  ACTUAL or ESTIMATED
sponsorName               string|null
sponsorType               string|null
collaborators             string[]
conditions                string[]
conditionMeshTerms        string[]
interventionTypes         string[]
interventionNames         string[]
interventionMeshTerms     string[]
facilityCountries         string[]     ISO country codes
keywords                  string[]
orgStudyId                string|null
secondaryIds              string[]
primaryOutcomeMeasures    string[]
secondaryOutcomeMeasures  string[]
designAllocation          string|null  RANDOMIZED, NON_RANDOMIZED, NA
designInterventionModel   string|null  SINGLE_GROUP, PARALLEL, CROSSOVER, FACTORIAL, SEQUENTIAL
designPrimaryPurpose      string|null  TREATMENT, PREVENTION, DIAGNOSTIC, etc.
designMasking             string|null  NONE, SINGLE, DOUBLE, TRIPLE, QUADRUPLE
resultsFirstPostDate      string|null  ISO date
whyStopped                string|null
isFdaRegulatedDrug        boolean|null
isFdaRegulatedDevice      boolean|null
armGroups                 object[]     [{type, title, description}]
oversightHasDmc           boolean|null
```

**Optional fields (`include` param):** `detailedDescription`, `outcomes`, `referencesBiomedCore`

---

## DrugCore Endpoints

### 1. Search

```
GET /v1/cores/drugcore/records?query={text}
```

| Param | Required | Type | Notes |
| --- | --- | --- | --- |
| `query` | yes | string | Search across drug names, trade names, synonyms, descriptions |
| `limit` | no | int | 1–300, default 20 |
| `include` | no | string | One or more of: `parent`, `children`, `referencesTrialCore`, `referencesBiomedCore`. Repeat for multiple: `include=parent&include=children` |
| `drugType` | no | enum | `SMALL_MOLECULE`, `ANTIBODY`, `PROTEIN`, `OLIGONUCLEOTIDE`, `GENE`, `ENZYME`, `ANTIBODY_DRUG_CONJUGATE`, `VACCINE_COMPONENT`, `CELL`, `OLIGOSACCHARIDE`, `VACCINE`, `UNKNOWN` |
| `maxClinicalStage` | no | enum | `PRECLINICAL`, `IND`, `EARLY_PHASE1`, `PHASE1`, `PHASE1/PHASE2`, `PHASE2`, `PHASE2/PHASE3`, `PHASE3`, `PREAPPROVAL`, `APPROVAL`, `UNKNOWN` |

```bash
curl "https://api.amass.tech/api/v1/cores/drugcore/records?query=pembrolizumab&drugType=ANTIBODY&limit=5" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

### 2. Get by Amass ID

```
GET /v1/cores/drugcore/records/{amassId}
```

Returns 404 if not found, 400 if the Amass ID is malformed.

### 3. Batch Lookup (ChEMBL ID -> Amass ID)

```
POST /v1/cores/drugcore/records/lookup
```

Each item must have `chemblId`.

```json
{"items": [{"chemblId": "CHEMBL1201583"}, {"chemblId": "CHEMBL9999999"}]}
```

Returns `[{"amassIds": ["AMDC_..."]}, {"error": "..."}]` — one entry per input item. A single ChEMBL ID can resolve to multiple Amass IDs, so `amassIds` is always an array.

---

## DrugCore Record Schema

**Default fields:**

```
amassId           string       AMDC_... (canonical ID)
chemblId          string|null  ChEMBL molecule ID
name              string|null  Primary drug name
description       string|null  A short free-text description of the drug, its clinical stage, and/or its indications
synonyms          string[]     Alternative names
tradeNames        string[]     Brand / trade names
drugType          string|null  e.g. SMALL_MOLECULE, ANTIBODY
maxClinicalStage  string|null  Highest stage reached, e.g. PHASE3, APPROVAL
inchiKey          string|null  InChIKey structure hash
canonicalSmiles   string|null  Canonical SMILES string
```

**Optional fields (`include` param):** `parent`, `children`, `referencesTrialCore`, `referencesBiomedCore`

Reference fields:

- `parent`, `children` — **intra-core links within DrugCore.** `parent` is a single `AMDC_...` ID; `children` is an array of `AMDC_...` IDs (drug hierarchy).
- `referencesTrialCore` — **cross-core link to TrialCore.** Array of `AMTC_...` IDs for associated clinical trials.
- `referencesBiomedCore` — **cross-core link to BiomedCore.** Array of `AMBC_...` IDs for associated publications.

---

## RegulatoryCore Endpoints

Cross-agency drug regulatory authorizations from the FDA (US) and EMA (EU), normalized onto a shared schema. One record = one authorization. Updated weekly.

### 1. Search

```
GET /v1/cores/regulatorycore/records?query={text}
```

| Param | Required | Type | Notes |
| --- | --- | --- | --- |
| `query` | yes | string | Product name, active substance, indication, or holder |
| `limit` | no | int | 1–300, default 20 |
| `include` | no | string | One or more of: `emaDetails`, `fdaDetails`, `referencesDrugCore`. Repeat for multiple. |
| `agency` | no | enum | `FDA`, `EMA`. Repeat for multiple (OR). |
| `moleculeType` | no | enum | `SMALL_MOLECULE`, `ANTIBODY`, `PROTEIN`, `ENZYME`, `OLIGONUCLEOTIDE`, `GENE`, `CELL`, `ANTIBODY_DRUG_CONJUGATE`, `VACCINE_COMPONENT`, `VACCINE`, `OLIGOSACCHARIDE`, `UNKNOWN`. Repeat for multiple (OR). |
| `authorizationStatus` | no | enum | `ACTIVE`, `APPROVED_NOT_MARKETED`, `CONDITIONAL`, `SUSPENDED`, `WITHDRAWN_VOLUNTARY`, `WITHDRAWN_FORCED`, `REVOKED`, `LAPSED_SUNSET`, `REFUSED`, `WITHDRAWN_DURING_REVIEW`, `EXPIRED`, `UNKNOWN`. Repeat for multiple (OR). Case-insensitive on input. |
| `hasDesignation` | no | enum | `PRIORITY_REVIEW`, `BREAKTHROUGH_THERAPY`, `FAST_TRACK`, `RMAT`, `ACCELERATED_APPROVAL`, `ACCELERATED_ASSESSMENT`, `PRIME`, `CONDITIONAL_MA`, `EXCEPTIONAL_CIRCUMSTANCES`. Repeat for multiple (OR). Each applies only to the agency that owns it. |
| `isOrphan` | no | bool | `true`/`false`. Cross-walk: FDA Orphan Drug / EMA Orphan Medicine. |
| `minAuthorizationDate` | no | ISO date | e.g. `2020-01-01` |
| `maxAuthorizationDate` | no | ISO date | e.g. `2026-01-01` |

Enum filters combine **OR within one filter, AND across filters**.

```bash
curl "https://api.amass.tech/api/v1/cores/regulatorycore/records?query=pembrolizumab&agency=FDA&agency=EMA&limit=10" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

### 2. Get by Amass ID

```
GET /v1/cores/regulatorycore/records/{amassId}
```

Returns 404 if not found.

### 3. Batch Lookup (FDA/EMA identifier -> Amass ID)

```
POST /v1/cores/regulatorycore/records/lookup
```

Each item must have **exactly one** of `fdaApplicationNumber`, `emaProductNumber`, `ndc`, or `splSetId`.

```json
{"items": [{"fdaApplicationNumber": "BLA125514"}, {"emaProductNumber": "EMEA/H/C/003820"}, {"ndc": "0169-4404"}, {"splSetId": "ee06186f-2aa3-4990-a760-757579d8f77b"}]}
```

Returns one entry per input item — `amassIds` (always an array; one identifier can resolve to multiple) or `error`.

---

## RegulatoryCore Record Schema

**Default fields:**

```
amassId                       string       AMRC_... (canonical ID)
agency                        string       FDA or EMA
name                          string|null  Primary product / brand name
activeSubstance               string|null
moleculeType                  string|null  Projected from DrugCore
authorizationStatus           string|null  Unified FDA + EMA status
procedureType                 string|null  FDA: NDA/BLA/ANDA; EMA: CENTRALISED_HUMAN, etc.
therapeuticIndication         string|null
marketingAuthorisationHolder  string|null
authorizationDate             string|null  ISO date
firstAuthorizationDate        string|null  ISO date
lastUpdateDate                string|null  ISO date
sourceUrl                     string|null
isOrphan                      boolean|null
designations                  object[]     {axis, type, agency, nativeName, basis, indication, postMarketingObligation}
authorizationsByAgency        object[]     Cross-market link, always populated: {amassId, agency, name, authorizationStatus}
```

**Optional fields (`include` param):** `fdaDetails`, `emaDetails`, `referencesDrugCore`

Reference fields:

- `authorizationsByAgency` — **cross-market link within RegulatoryCore.** Array of `AMRC_...` IDs for the same product's other-market authorizations (self excluded), each carrying its own `authorizationStatus`. Always present — cannot be requested or suppressed.
- `referencesDrugCore` — **cross-core link to DrugCore.** Array of `AMDC_...` IDs for the product's active ingredients.

---

## Common Patterns


**Find recent high-impact papers on a topic:**

```bash
curl "https://api.amass.tech/api/v1/cores/biomedcore/records\
?query=CAR-T+therapy\
&minPublicationDate=2024-01-01\
&minCitationCount=10\
&minJournalQualityJufo=2\
&limit=20" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Find recruiting Phase 3 drug trials:**

```bash
curl "https://api.amass.tech/api/v1/cores/trialcore/records\
?query=lung+cancer\
&phase=PHASE3\
&overallStatus=RECRUITING\
&interventionType=DRUG\
&limit=20" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Find trials with results in a specific country:**

```bash
curl "https://api.amass.tech/api/v1/cores/trialcore/records\
?query=diabetes\
&hasResults=true\
&facilityCountries=US\
&limit=50" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Find approved drugs of a given modality:**

```bash
curl "https://api.amass.tech/api/v1/cores/drugcore/records\
?query=checkpoint+inhibitor\
&drugType=ANTIBODY\
&maxClinicalStage=APPROVAL\
&limit=20" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Compare a drug's US vs EU authorization status:**

```bash
curl "https://api.amass.tech/api/v1/cores/regulatorycore/records\
?query=pembrolizumab\
&limit=50" \
  -H "Authorization: Bearer amass_YOUR_KEY"
# Read authorizationsByAgency on each record for the cross-market status.
```

**Find expedited-pathway approvals across both agencies:**

```bash
curl "https://api.amass.tech/api/v1/cores/regulatorycore/records\
?query=oncology\
&hasDesignation=BREAKTHROUGH_THERAPY\
&hasDesignation=ACCELERATED_APPROVAL\
&hasDesignation=PRIME\
&limit=100" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Convert PMIDs to Amass IDs, then fetch full records:**

```bash
# Step 1: lookup
curl -X POST "https://api.amass.tech/api/v1/cores/biomedcore/records/lookup" \
  -H "Authorization: Bearer amass_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"items": [{"pmid": "38123456"}]}'

# Step 2: fetch details
curl "https://api.amass.tech/api/v1/cores/biomedcore/records/{amassId}\
?include=authorsMetadata" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```


**Convert NCT IDs to Amass IDs, then fetch trial details:**

```bash
# Step 1: lookup
curl -X POST "https://api.amass.tech/api/v1/cores/trialcore/records/lookup" \
  -H "Authorization: Bearer amass_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"items": [{"nctId": "NCT06012345"}]}'

# Step 2: fetch details with outcomes
curl "https://api.amass.tech/api/v1/cores/trialcore/records/{amassId}\
?include=outcomes" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Cross-reference trials with publications:**

```bash
# Step 1: get trial with referencesBiomedCore IDs
curl "https://api.amass.tech/api/v1/cores/trialcore/records/{amassId}\
?include=referencesBiomedCore" \
  -H "Authorization: Bearer amass_YOUR_KEY"

# Step 2: fetch a referenced publication (BiomedCore record)
# Use one of the AMBC_ IDs from referencesBiomedCore in the response above.
curl "https://api.amass.tech/api/v1/cores/biomedcore/records/{biomedCoreAmassId}" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

**Resolve FDA/EMA identifiers to Amass IDs, then fetch authorizations:**

```bash
# Step 1: lookup (each item carries exactly one identifier)
curl -X POST "https://api.amass.tech/api/v1/cores/regulatorycore/records/lookup" \
  -H "Authorization: Bearer amass_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"items": [{"fdaApplicationNumber": "BLA125514"}, {"ndc": "0169-4404"}, {"splSetId": "ee06186f-2aa3-4990-a760-757579d8f77b"}]}'

# Step 2: fetch details with the agency-specific block
curl "https://api.amass.tech/api/v1/cores/regulatorycore/records/{amassId}\
?include=fdaDetails" \
  -H "Authorization: Bearer amass_YOUR_KEY"
```

For full walkthroughs of these patterns with real response data, see [API Workflows](examples/use-cases).

---

## Error Handling

```
200  Success
400  Bad request — check error.fields for per-field details
401  Missing or invalid API key
403  Valid key, insufficient permissions
404  Record not found (GET by ID only)
422  Semantically invalid input
429  Rate limited — read Retry-After header, back off exponentially
500  Server error — retry with backoff
```

Error shape:

```json
{"error": {"status": 429, "code": "TOO_MANY_REQUESTS", "message": "Too many requests"}}
```

---

```
Docs: https://api.amass.tech/api/doc
Spec: https://api.amass.tech/api/doc/openapi.json
Maintained for: LLM agents, AI applications, and automated tools
```
