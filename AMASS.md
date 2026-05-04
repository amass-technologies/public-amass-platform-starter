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
3. **Amass IDs are canonical.** The get-by-ID endpoints take Amass IDs only (`AMBC_...`, `AMTC_...`). If you have PMIDs/DOIs/NCTs, convert them via the lookup endpoints first.
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
| **RegulatoryCore** | `/v1/cores/regulatorycore/` | Coming soon |

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
| `include` | no | string | Repeat for multiple: `include=fulltext&include=authorsMetadata` |
| `minPublicationDate` | no | ISO date | e.g. `2023-01-01` |
| `maxPublicationDate` | no | ISO date | e.g. `2026-01-01` |
| `minCitationCount` | no | int | 0–100000 |
| `minJournalQualityJufo` | no | enum | `0`, `1`, `2`, or `3` (3 = top-tier) |
| `isRetracted` | no | bool | `true` or `false` |

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
| `include` | no | string | `outcomes`, `detailedDescription` |
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

For full walkthroughs of these patterns with real response data, see [API Workflows](use-cases).

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
