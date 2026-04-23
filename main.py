"""Interactive BAML-driven agent over the amass platform (BioMedCore + TrialCore).

Usage:
    uv run python main.py                        # drop into REPL
    uv run python main.py "your question here"   # seed the first turn, then REPL

Supported question types:
    1. Topic search (papers):    "What are the hallmarks of cancer and how have they changed over time?"
    2. Author follow-up:         "What else has D Hanahan published on cancer biology since 2015?"
    3. Paper detail/full text:   "Show me the full text and author affiliations for #1."
    4. Trial search + filters:   "Find recruiting Phase 3 lung cancer drug trials in the US."
    5. Trial detail (cross-core): "Show me trial #1 with its referenced publications."
    6. Identifier lookup:        "Look up PMID 38123456" or "Show me trial NCT06012345"
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import sys
from typing import Any

from dotenv import load_dotenv
from rich.console import Console
from rich.markdown import Markdown
from rich.markup import escape
from rich.panel import Panel

from amass import AmassClient, AmassError
from baml_client import b
from baml_client.types import (
    FinalAnswer,
    GetPaper,
    GetTrial,
    LookupPaper,
    LookupTrial,
    SearchPapers,
    SearchTrials,
)

# Max tool calls per user turn. If the router hasn't produced a FinalAnswer by then, we inject
# a fake user nudge into the scratchpad and call the router one more time to force it to stop.
# If it still picks a tool after that, SummarizeResult synthesizes from what we have.
TOOL_BUDGET = 5
# Per-observation trimming budget inside the scratchpad passed back to RouteQuery.
SCRATCH_RESULT_CHAR_BUDGET = 2000
# Total observation payload budget passed into SummarizeResult at loop exit.
OBSERVATIONS_JSON_CHAR_BUDGET = 400000

# .env is loaded once at import time so AMASS_API_KEY and other vars are available globally.
load_dotenv()

console = Console(highlight=False)
err_console = Console(stderr=True, highlight=False)

AMASS_COLOR = "#f84016"


_AMASS_ID_RE = re.compile(r"(AM[BT]C_[A-Za-z0-9]+)")


def _amass_id(aid: str) -> str:
    return f"[{AMASS_COLOR}]{escape(aid)}[/{AMASS_COLOR}]"


def _highlight_amass_ids(text: str) -> str:
    return _AMASS_ID_RE.sub(rf"[{AMASS_COLOR}]\1[/{AMASS_COLOR}]", text)

EXAMPLE_QUERIES = [
    # 1. Topic search (BioMedCore) -> SearchPapers
    "How does amylin compare with glp-1 analogues with respect to reduction of peripheral inflammation?",
    # 2. paper follow-up (BioMedCore) -> SearchPapers (runs after a prior search, using a cited paper as the query)
    "Can you look up AMBC_Gp1V4vKuIJ4vqe54evq0XcneZ4U and AMBC_FpuesO7IB2FNlz9A0EQR7MxdvD and summarize their abstracts?",
    # 3. Detail / full-text lookup (BioMedCore) -> GetPaper (runs after a prior search)
    "Show me the full text and author affiliations for #1.",
    # 4. Trial topic + filters (TrialCore) -> SearchTrials
    "Find recruiting Phase 3 lung cancer drug trials.",
    # 5. Trial detail with cross-core references (TrialCore -> BioMedCore)
    "Show me trial #1 with its referenced publications.",
    # 6. Identifier lookup (PMID -> BioMedCore, NCT -> TrialCore)
    "Look up PMID 38123456.",
    # 7. Identifier lookup with NCT -> TrialCore + cross-core refs to BioMedCore
    "Show me trial NCT00953732 with results if available and associated publications.",
    # 8. Get trial by acronym
    "Show me the ALPHA3 trial.",
]

PAPER_SEARCH_FIELDS_KEEP = (
    "amassId", "pmid", "doi", "title", "authors", "journal",
    "publicationDate", "citationCount", "journalQualityJufo",
    "hasFulltext", "isRetracted", "abstract",
)
TRIAL_SEARCH_FIELDS_KEEP = (
    "amassId", "nctId", "briefTitle", "sponsorName", "phase", "overallStatus",
    "studyType", "startDate", "completionDate", "enrollment",
    "conditions", "interventionTypes", "interventionNames",
    "facilityCountries", "hasResults", "briefSummary",
)
TRIAL_GET_FIELDS_KEEP = (
    "amassId", "nctId", "briefTitle", "officialTitle", "briefSummary",
    "phase", "overallStatus", "studyType",
    "startDate", "completionDate", "lastUpdateDate", "hasResults",
    "enrollment", "enrollmentType",
    "sponsorName", "sponsorType", "collaborators",
    "conditions", "conditionMeshTerms",
    "interventionTypes", "interventionNames", "interventionMeshTerms",
    "facilityCountries", "keywords",
    "primaryOutcomeMeasures", "secondaryOutcomeMeasures",
    "designAllocation", "designInterventionModel", "designPrimaryPurpose", "designMasking",
    "resultsFirstPostDate", "whyStopped",
    "isFdaRegulatedDrug", "isFdaRegulatedDevice",
    "armGroups", "referenceAmassIds", "oversightHasDmc",
)
MAX_CROSS_CORE_REFS = 5


def print_banner() -> None:
    first = EXAMPLE_QUERIES[0]
    console.print()
    console.print("[bold cyan]amass agent[/bold cyan] — ask about scientific papers and clinical trials.")
    console.print()
    console.print("[bold]Try one of these[/bold] [dim](type or paste directly):[/dim]")
    for i, q in enumerate(EXAMPLE_QUERIES, 1):
        console.print(f"  [dim]{i}.[/dim] {_highlight_amass_ids(escape(q))}")
    console.print(f"\n[dim]Or seed the first turn from the shell:\n  uv run python main.py \"{escape(first)}\"[/dim]")
    console.print("\n[dim]Type 'exit' or Ctrl-D to quit.[/dim]\n")


def render_history(history: list[dict[str, str]]) -> str:
    if not history:
        return "(no prior turns)"
    return "\n".join(f"{turn['role']}: {turn['content']}" for turn in history[-10:])


def render_digest(last_results: list[dict[str, Any]]) -> str:
    if not last_results:
        return "(no prior search results)"
    lines = []
    for i, rec in enumerate(last_results, 1):
        amass_id = rec.get("amassId") or "?"
        # Trial records have briefTitle + sponsorName + phase/status; papers have title + authors.
        if rec.get("briefTitle") or amass_id.startswith("AMTC_"):
            title = rec.get("briefTitle") or "(untitled)"
            sponsor = rec.get("sponsorName") or "?"
            phase = rec.get("phase") or "?"
            status = rec.get("overallStatus") or "?"
            lines.append(f"{i}. {title} — {sponsor} ({phase}, {status}) — {amass_id}")
        else:
            title = rec.get("title") or "(untitled)"
            authors = rec.get("authors") or []
            first_author = authors[0] if authors else "?"
            year = (rec.get("publicationDate") or "")[:4] or "?"
            lines.append(f"{i}. {title} — {first_author} et al. ({year}) — {amass_id}")
    return "\n".join(lines)


def trim_paper_search_record(rec: dict[str, Any]) -> dict[str, Any]:
    trimmed = {k: rec.get(k) for k in PAPER_SEARCH_FIELDS_KEEP if k in rec}
    abstract = trimmed.get("abstract")
    if isinstance(abstract, str) and len(abstract) > 800:
        trimmed["abstract"] = abstract[:800] + " …[truncated]"
    return trimmed


def trim_paper_record(rec: dict[str, Any]) -> dict[str, Any]:
    trimmed = dict(rec)
    trimmed.pop("meshIds", None)
    trimmed.pop("substanceIds", None)
    return trimmed


def trim_trial_search_record(rec: dict[str, Any]) -> dict[str, Any]:
    trimmed = {k: rec.get(k) for k in TRIAL_SEARCH_FIELDS_KEEP if k in rec}
    summary = trimmed.get("briefSummary")
    if isinstance(summary, str) and len(summary) > 600:
        trimmed["briefSummary"] = summary[:600] + " …[truncated]"
    return trimmed


def trim_trial_record(rec: dict[str, Any]) -> dict[str, Any]:
    trimmed = {k: rec.get(k) for k in TRIAL_GET_FIELDS_KEEP if k in rec}
    summary = trimmed.get("briefSummary")
    if isinstance(summary, str) and len(summary) > 1500:
        trimmed["briefSummary"] = summary[:1500] + " …[truncated]"
    arms = trimmed.get("armGroups")
    if isinstance(arms, list):
        trimmed["armGroups"] = [
            {k: a.get(k) for k in ("type", "title", "description") if k in a}
            for a in arms
            if isinstance(a, dict)
        ]
    # Carry through cross-core enrichment if dispatch added it.
    if "_references" in rec:
        trimmed["_references"] = rec["_references"]
    return trimmed


async def _fetch_trial_with_refs(
    amass: AmassClient, amass_id: str, *, include_outcomes: bool, include_references: bool = False
) -> dict[str, Any] | None:
    raw = await amass.get_trial(amass_id, include_outcomes=include_outcomes, include_references=include_references)
    if raw is None:
        return None
    # Cross-core enrichment: parallel-fetch referenced BioMedCore papers (metadata only).
    ref_ids = (raw.get("referenceAmassIds") or [])[:MAX_CROSS_CORE_REFS]
    if ref_ids:
        refs = await asyncio.gather(
            *(amass.get_paper(rid, include_fulltext=False, include_authors=False) for rid in ref_ids),
            return_exceptions=True,
        )
        raw["_references"] = [
            trim_paper_search_record(r) for r in refs if isinstance(r, dict)
        ]
    return raw


def _extract_lookup_amass_id(
    items: list[dict[str, Any]]
) -> tuple[str | None, str | None]:
    """Return (amass_id, error_message). Per AMASS.md, each item carries either
    amassIds or error — check both."""
    for item in items:
        if not isinstance(item, dict):
            continue
        if item.get("error"):
            return None, str(item["error"])
        ids = item.get("amassIds") or []
        if ids:
            return ids[0], None
    return None, None


async def dispatch(
    amass: AmassClient,
    req: SearchPapers | GetPaper | SearchTrials | GetTrial | LookupPaper | LookupTrial,
) -> tuple[str, Any]:
    if isinstance(req, SearchPapers):
        raw = await amass.search_papers(
            query=req.query,
            limit=req.limit or 10,
            min_publication_date=req.min_publication_date,
            min_journal_quality=req.min_journal_quality,
        )
        return "search_papers", [trim_paper_search_record(r) for r in raw]
    if isinstance(req, GetPaper):
        include_fulltext = True if req.include_fulltext is None else req.include_fulltext
        raw = await amass.get_paper(req.amass_id, include_fulltext=include_fulltext)
        if raw is None:
            return "get_paper", {"error": f"no record found for {req.amass_id}"}
        return "get_paper", trim_paper_record(raw)
    if isinstance(req, SearchTrials):
        raw = await amass.search_trials(
            query=req.query,
            limit=req.limit or 10,
            phase=req.phase,
            overall_status=req.overall_status,
            study_type=req.study_type,
            intervention_type=req.intervention_type,
            min_start_date=req.min_start_date,
            has_results=req.has_results,
        )
        return "search_trials", [trim_trial_search_record(r) for r in raw]
    if isinstance(req, GetTrial):
        include_outcomes = True if req.include_outcomes is None else req.include_outcomes
        raw = await _fetch_trial_with_refs(amass, req.amass_id, include_outcomes=include_outcomes)
        if raw is None:
            return "get_trial", {"error": f"no trial found for {req.amass_id}"}
        return "get_trial", trim_trial_record(raw)
    if isinstance(req, LookupPaper):
        # Prefer pmid when both are set (router prompt asks for exactly one).
        if req.pmid:
            item = {"pmid": req.pmid}
            ident = f"PMID {req.pmid}"
        elif req.doi:
            item = {"doi": req.doi}
            ident = f"DOI {req.doi}"
        else:
            return "get_paper", {"error": "lookup_paper requires pmid or doi"}
        results = await amass.lookup_papers([item])
        amass_id, err = _extract_lookup_amass_id(results)
        if err:
            return "get_paper", {"error": f"lookup failed for {ident}: {err}"}
        if not amass_id:
            return "get_paper", {"error": f"no BioMedCore record found for {ident}"}
        include_fulltext = True if req.include_fulltext is None else req.include_fulltext
        raw = await amass.get_paper(amass_id, include_fulltext=include_fulltext)
        if raw is None:
            return "get_paper", {"error": f"resolved {ident} → {amass_id} but fetch returned 404"}
        return "get_paper", trim_paper_record(raw)
    if isinstance(req, LookupTrial):
        ident = f"NCT {req.nct_id}"
        results = await amass.lookup_trials([{"nctId": req.nct_id}])
        amass_id, err = _extract_lookup_amass_id(results)
        if err:
            return "get_trial", {"error": f"lookup failed for {ident}: {err}"}
        if not amass_id:
            return "get_trial", {"error": f"no TrialCore record found for {ident}"}
        include_outcomes = True if req.include_outcomes is None else req.include_outcomes
        include_references = True if req.include_references is None else req.include_references
        raw = await _fetch_trial_with_refs(amass, amass_id, include_outcomes=include_outcomes, include_references=include_references)
        if raw is None:
            return "get_trial", {"error": f"resolved {ident} → {amass_id} but fetch returned 404"}
        return "get_trial", trim_trial_record(raw)
    raise TypeError(f"Unknown tool request: {type(req).__name__}")


def _format_call(req: SearchPapers | GetPaper | SearchTrials | GetTrial | LookupPaper | LookupTrial) -> str:
    if isinstance(req, SearchPapers):
        bits = [f"query={req.query!r}", f"limit={req.limit or 10}"]
        if req.min_publication_date:
            bits.append(f"min_publication_date={req.min_publication_date}")
        if req.min_journal_quality is not None:
            bits.append(f"min_journal_quality={req.min_journal_quality}")
        return "search_papers(" + ", ".join(bits) + ")"
    if isinstance(req, GetPaper):
        inc_ft = True if req.include_fulltext is None else req.include_fulltext
        return f"get_paper(amass_id={req.amass_id!r}, include_fulltext={inc_ft})"
    if isinstance(req, SearchTrials):
        bits = [f"query={req.query!r}", f"limit={req.limit or 10}"]
        for name in ("phase", "overall_status", "study_type", "intervention_type", "min_start_date"):
            v = getattr(req, name)
            if v:
                bits.append(f"{name}={v}")
        if req.has_results is not None:
            bits.append(f"has_results={req.has_results}")
        return "search_trials(" + ", ".join(bits) + ")"
    if isinstance(req, GetTrial):
        inc_out = True if req.include_outcomes is None else req.include_outcomes
        return f"get_trial(amass_id={req.amass_id!r}, include_outcomes={inc_out})"
    if isinstance(req, LookupPaper):
        inc_ft = True if req.include_fulltext is None else req.include_fulltext
        ident = f"pmid={req.pmid!r}" if req.pmid else f"doi={req.doi!r}"
        return f"lookup_paper({ident}, include_fulltext={inc_ft})"
    inc_out = True if req.include_outcomes is None else req.include_outcomes
    inc_ref = True if req.include_references is None else req.include_references
    return f"lookup_trial(nct_id={req.nct_id!r}, include_outcomes={inc_out}, include_references={inc_ref})"


def print_router_decision(
    route: SearchPapers | GetPaper | SearchTrials | GetTrial | LookupPaper | LookupTrial | FinalAnswer,
    *,
    step: int | None = None,
) -> None:
    prefix = f"[dim]step {step}[/dim] " if step is not None else ""
    if isinstance(route, FinalAnswer):
        title = f"{prefix}[bold yellow]ROUTER[/bold yellow] → [green]final_answer[/green]"
        body = f"[italic]{escape(route.thought)}[/italic]"
    else:
        title = f"{prefix}[bold yellow]ROUTER[/bold yellow] → [bold]{escape(route.tool)}[/bold]"
        body = f"[italic]{escape(route.thought)}[/italic]\n[dim]{escape(_format_call(route))}[/dim]"
    console.print()
    console.print(Panel(body, title=title, title_align="left", border_style="dim", padding=(0, 1)))


def print_amass_results(
    req: SearchPapers | GetPaper | SearchTrials | GetTrial | LookupPaper | LookupTrial,
    tool_name: str,
    tool_result: Any,
) -> None:
    lines: list[str] = []
    border = "blue"

    if tool_name == "search_papers":
        records = tool_result if isinstance(tool_result, list) else []
        if not records:
            lines.append("[dim](no records returned)[/dim]")
        else:
            lines.append(f"[dim]{len(records)} record(s)[/dim]")
            for i, r in enumerate(records, 1):
                title = escape((r.get("title") or "(untitled)").strip())
                all_authors = r.get("authors") or []
                authors = escape(", ".join(all_authors[:3]) or "(no authors)")
                if len(all_authors) > 3:
                    authors += f" [dim]+{len(all_authors) - 3} more[/dim]"
                year = (r.get("publicationDate") or "")[:4] or "?"
                journal = escape((r.get("journal") or "?").strip() or "?")
                amass_id = r.get("amassId") or "?"
                cites = r.get("citationCount")
                jq = r.get("journalQualityJufo")
                ret = "[bold red]RETRACTED [/bold red]" if r.get("isRetracted") else ""
                ft = " [green]★ fulltext[/green]" if r.get("hasFulltext") else ""
                lines.append(f" [bold]{i:>2}.[/bold] {ret}{title}")
                lines.append(f"     {authors} · {journal} · {year}")
                lines.append(f"     {_amass_id(amass_id)} [dim]· cites={cites} · jQ={jq}[/dim]{ft}")

    elif tool_name == "get_paper":
        if isinstance(tool_result, dict) and "error" in tool_result and len(tool_result) == 1:
            lines.append(f"[red]{escape(tool_result['error'])}[/red]")
        elif isinstance(tool_result, dict):
            r = tool_result
            ret = "[bold red]RETRACTED [/bold red]" if r.get("isRetracted") else ""
            lines.append(f"{ret}[bold]{escape((r.get('title') or '(untitled)').strip())}[/bold]")
            lines.append(f"{escape(r.get('journal') or '?')} · {(r.get('publicationDate') or '?')[:10]} · {_amass_id(r.get('amassId') or '?')}")
            lines.append(f"[dim]cites={r.get('citationCount')} · jQ={r.get('journalQualityJufo')}[/dim]")
            authors_meta = r.get("authorsMetadata") or []
            for a in authors_meta[:6]:
                affs = a.get("affiliations") or []
                aff_name = (affs[0].get("name") if affs else "") or ""
                cc = (affs[0].get("countryCode") if affs else "") or ""
                tail = f" — {escape(aff_name)}" if aff_name else ""
                if cc:
                    tail += f" [dim]({cc})[/dim]"
                lines.append(f"  · {escape(a.get('name') or '?')}{tail}")
            if len(authors_meta) > 6:
                lines.append(f"  [dim](+{len(authors_meta) - 6} more authors)[/dim]")
            ft = r.get("fulltext") or ""
            if ft:
                lines.append(f"[green]fulltext: {len(ft):,} chars[/green]")

    elif tool_name == "search_trials":
        border = "cyan"
        records = tool_result if isinstance(tool_result, list) else []
        if not records:
            lines.append("[dim](no records returned)[/dim]")
        else:
            lines.append(f"[dim]{len(records)} trial(s)[/dim]")
            for i, r in enumerate(records, 1):
                title = escape((r.get("briefTitle") or "(untitled)").strip())
                sponsor = escape((r.get("sponsorName") or "?").strip() or "?")
                phase = escape(r.get("phase") or "?")
                status = escape(r.get("overallStatus") or "?")
                amass_id = r.get("amassId") or "?"
                nct = r.get("nctId") or "?"
                enroll = r.get("enrollment")
                countries = escape(", ".join(r.get("facilityCountries") or []) or "?")
                lines.append(f" [bold]{i:>2}.[/bold] {title}")
                lines.append(f"     {sponsor} · {phase} · {status}")
                lines.append(f"     {_amass_id(amass_id)} [dim]· {nct} · enrollment={enroll} · {countries}[/dim]")

    elif tool_name == "get_trial":
        border = "cyan"
        if isinstance(tool_result, dict) and "error" in tool_result and len(tool_result) == 1:
            lines.append(f"[red]{escape(tool_result['error'])}[/red]")
        elif isinstance(tool_result, dict):
            r = tool_result
            lines.append(f"[bold]{escape((r.get('briefTitle') or '(untitled)').strip())}[/bold]")
            lines.append(
                f"{escape(r.get('sponsorName') or '?')} · {escape(r.get('phase') or '?')}"
                f" · {escape(r.get('overallStatus') or '?')} · {escape(r.get('studyType') or '?')}"
            )
            lines.append(f"{_amass_id(r.get('amassId') or '?')} [dim]· {r.get('nctId') or '?'}[/dim]")
            lines.append(
                f"[dim]start={(r.get('startDate') or '?')[:10]}"
                f" · completion={(r.get('completionDate') or '?')[:10]}"
                f" · enrollment={r.get('enrollment')}[/dim]"
            )
            conds = r.get("conditions") or []
            if conds:
                cond_str = escape(", ".join(conds[:6]))
                extra = f" [dim](+{len(conds)-6} more)[/dim]" if len(conds) > 6 else ""
                lines.append(f"conditions: {cond_str}{extra}")
            inames = r.get("interventionNames") or []
            itypes = r.get("interventionTypes") or []
            if inames:
                pairs = [f"{escape(itypes[j] if j < len(itypes) else '?')}: {escape(n)}" for j, n in enumerate(inames[:6])]
                extra = f" [dim](+{len(inames)-6} more)[/dim]" if len(inames) > 6 else ""
                lines.append(f"interventions: {', '.join(pairs)}{extra}")
            refs = r.get("_references") or []
            if refs:
                lines.append(f"[green]cross-core: {len(refs)} BioMedCore reference(s)[/green]")
                for ref in refs[:3]:
                    rt = escape((ref.get("title") or "(untitled)").strip())
                    ra = escape((ref.get("authors") or ["?"])[0])
                    ry = (ref.get("publicationDate") or "?")[:4]
                    lines.append(f"  · {rt} — {ra} ({ry}) {_amass_id(ref.get('amassId') or '?')}")
                if len(refs) > 3:
                    lines.append(f"  [dim](+{len(refs) - 3} more)[/dim]")

    call_str = escape(_format_call(req))
    content = "\n".join(lines)
    console.print()
    console.print(Panel(
        content,
        title=f"[bold]AMASS[/bold] [dim]{call_str}[/dim]",
        title_align="left",
        border_style=border,
        padding=(0, 1),
    ))


def _trim_for_scratch(tool_name: str, tool_result: Any) -> Any:
    """Compact form of a tool result for the scratchpad. Search lists keep only identifying
    fields; detail records keep the short trim. Errors pass through as-is."""
    if isinstance(tool_result, dict) and "error" in tool_result and len(tool_result) == 1:
        return tool_result
    if tool_name == "search_papers" and isinstance(tool_result, list):
        return [
            {k: r.get(k) for k in ("amassId", "title", "authors", "publicationDate", "journal") if k in r}
            for r in tool_result
        ]
    if tool_name == "search_trials" and isinstance(tool_result, list):
        return [
            {k: r.get(k) for k in ("amassId", "nctId", "briefTitle", "sponsorName", "phase", "overallStatus") if k in r}
            for r in tool_result
        ]
    if tool_name in ("get_paper",) and isinstance(tool_result, dict):
        keep = ("amassId", "title", "authors", "publicationDate", "journal",
                "citationCount", "journalQualityJufo", "isRetracted")
        trimmed = {k: tool_result.get(k) for k in keep if k in tool_result}
        ft = tool_result.get("fulltext")
        if isinstance(ft, str):
            trimmed["fulltextChars"] = len(ft)
            trimmed["fulltextPreview"] = ft[:400] + (" …[truncated]" if len(ft) > 400 else "")
        return trimmed
    if tool_name in ("get_trial",) and isinstance(tool_result, dict):
        keep = ("amassId", "nctId", "briefTitle", "sponsorName", "phase", "overallStatus",
                "conditions", "interventionNames", "enrollment", "_references")
        return {k: tool_result.get(k) for k in keep if k in tool_result}
    return tool_result


def render_scratch(observations: list[dict[str, Any]]) -> str:
    if not observations:
        return "(empty)"
    blocks: list[str] = []
    for i, obs in enumerate(observations, 1):
        scratch_result = _trim_for_scratch(obs["tool"], obs["result"])
        payload = json.dumps(scratch_result, default=str, ensure_ascii=False)
        if len(payload) > SCRATCH_RESULT_CHAR_BUDGET:
            payload = payload[:SCRATCH_RESULT_CHAR_BUDGET] + " …[truncated]"
        blocks.append(f"[step {i}] {obs['call']}\n→ {payload}")
    return "\n\n".join(blocks)


async def turn(
    amass: AmassClient,
    user_query: str,
    history: list[dict[str, str]],
    last_results: list[dict[str, Any]],
) -> tuple[str, list[dict[str, Any]]]:
    """Run one user turn. Calls the router in a loop up to TOOL_BUDGET times, executing tool
    calls and appending results to an in-turn scratchpad until the router emits FinalAnswer
    or the budget is exhausted. Returns (reply, possibly-updated last_results)."""
    observations: list[dict[str, Any]] = []
    new_last_results = last_results
    route: Any = None
    budget_exhausted = False

    for step in range(1, TOOL_BUDGET + 1):
        with console.status("[dim]thinking...[/dim]", spinner="dots"):
            route = await b.RouteQuery(
                user_query=user_query,
                history=render_history(history),
                last_results=render_digest(new_last_results),
                scratch=render_scratch(observations),
            )
        print_router_decision(route, step=step)
        if isinstance(route, FinalAnswer):
            break

        tool_name, tool_result = await dispatch(amass, route)
        print_amass_results(route, tool_name, tool_result)
        if tool_name in ("search_papers", "search_trials") and isinstance(tool_result, list):
            new_last_results = tool_result
        observations.append({
            "tool": tool_name,
            "call": _format_call(route),
            "result": tool_result,
        })
    else:
        # Budget exhausted. Inject a fake user message into the scratch and call the router
        # one more time, expecting it to pick FinalAnswer. If it still picks a tool, ignore
        # it and let SummarizeResult synthesize from what we have.
        budget_exhausted = True
        nudge = (
            "\n\nuser: You have used your tool budget. Answer now using only the information "
            "above. Do not request another tool."
        )
        scratch_with_nudge = render_scratch(observations) + nudge
        console.print("\n[yellow]budget exhausted — forcing final answer[/yellow]\n")
        with console.status("[dim]thinking...[/dim]", spinner="dots"):
            route = await b.RouteQuery(
                user_query=user_query,
                history=render_history(history),
                last_results=render_digest(new_last_results),
                scratch=scratch_with_nudge,
            )
        print_router_decision(route, step=TOOL_BUDGET + 1)

    if not observations:
        # Pure direct-answer path (greeting / meta / clarifying question). Use the router's
        # answer directly without a Sonnet synthesis round.
        assert isinstance(route, FinalAnswer)
        return route.answer, new_last_results

    payload = json.dumps(observations, default=str, ensure_ascii=False)
    if len(payload) > OBSERVATIONS_JSON_CHAR_BUDGET:
        payload = payload[:OBSERVATIONS_JSON_CHAR_BUDGET] + " …[truncated]"
    with console.status("[dim]summarizing...[/dim]", spinner="dots"):
        reply = await b.SummarizeResult(
            user_query=user_query,
            history=render_history(history),
            observations_json=payload,
        )
    if budget_exhausted:
        reply = f"[note: stopped after {TOOL_BUDGET} tool calls — budget exhausted]\n\n{reply}"
    return reply, new_last_results


async def run(initial: str | None) -> None:
    api_key = os.environ.get("AMASS_API_KEY", "")
    if not api_key:
        err_console.print("[bold red]error:[/bold red] AMASS_API_KEY is not set in the environment or .env file")
        sys.exit(2)

    amass = AmassClient(api_key)
    history: list[dict[str, str]] = []
    last_results: list[dict[str, Any]] = []

    try:
        print_banner()
        if initial:
            console.print(f"[bold green]you>[/bold green] {escape(initial)}")
            last_results[:] = await handle_turn(amass, initial, history, last_results)

        while True:
            try:
                user = console.input("[bold green]you>[/bold green] ").strip()
            except (EOFError, KeyboardInterrupt):
                console.print()
                break
            if not user:
                continue
            if user.lower() in {"exit", "quit"}:
                break
            new_last = await handle_turn(amass, user, history, last_results)
            last_results[:] = new_last
    finally:
        await amass.aclose()


async def handle_turn(
    amass: AmassClient,
    user: str,
    history: list[dict[str, str]],
    last_results: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    is_error = False
    try:
        reply, new_last_results = await turn(amass, user, history, last_results)
    except AmassError as e:
        reply = f"[amass error] {e}"
        new_last_results = last_results
        is_error = True
    except Exception as e:  # keep the REPL alive on transient issues
        reply = f"[error] {type(e).__name__}: {e}"
        new_last_results = last_results
        is_error = True
    console.print()
    if is_error:
        console.print(f"[bold red]error>[/bold red] {escape(reply)}")
    else:
        console.print("[bold blue]assistant>[/bold blue]")
        console.print(Markdown(reply))
    console.print()
    history.append({"role": "user", "content": user})
    history.append({"role": "assistant", "content": reply})
    # trim history in place
    if len(history) > 10:
        del history[: len(history) - 10]
    return new_last_results


def main() -> None:
    initial = " ".join(sys.argv[1:]).strip() or None
    asyncio.run(run(initial))


if __name__ == "__main__":
    main()
