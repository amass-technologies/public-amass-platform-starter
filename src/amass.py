"""Async client for the amass platform API (BioMedCore + TrialCore)."""

from __future__ import annotations

import asyncio
from typing import Any, Iterable

import httpx


class AmassError(Exception):
    pass


class AmassClient:
    BASE = "https://api.amass.tech/api/v1"

    def __init__(self, api_key: str, *, timeout: float = 30.0) -> None:
        if not api_key:
            raise AmassError("AMASS_API_KEY is empty or missing.")
        self._client = httpx.AsyncClient(
            timeout=timeout,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Accept": "application/json",
            },
        )

    async def aclose(self) -> None:
        await self._client.aclose()

    async def search_papers(
        self,
        query: str,
        *,
        limit: int = 10,
        min_publication_date: str | None = None,
        min_journal_quality: int | None = None,
        include: Iterable[str] | None = None,
        is_retracted: bool | None = False,
    ) -> list[dict[str, Any]]:
        params: list[tuple[str, str]] = [
            ("query", query),
            ("limit", str(max(1, min(limit, 1000)))),
        ]
        if min_publication_date:
            params.append(("minPublicationDate", min_publication_date))
        if min_journal_quality is not None:
            params.append(("minJournalQualityJufo", str(min_journal_quality)))
        if is_retracted is not None:
            params.append(("isRetracted", "true" if is_retracted else "false"))
        for inc in include or ():
            params.append(("include", inc))
        data = await self._request("GET", "/cores/biomedcore/records", params=params)
        return data if isinstance(data, list) else []

    async def get_paper(
        self,
        amass_id: str,
        *,
        include_fulltext: bool = True,
        include_authors: bool = True,
    ) -> dict[str, Any] | None:
        params: list[tuple[str, str]] = []
        if include_authors:
            params.append(("include", "authorsMetadata"))
        if include_fulltext:
            params.append(("include", "fulltext"))
        try:
            data = await self._request(
                "GET", f"/cores/biomedcore/records/{amass_id}", params=params
            )
        except AmassError as e:
            if "404" in str(e):
                return None
            raise
        return data if isinstance(data, dict) else None

    async def search_trials(
        self,
        query: str,
        *,
        limit: int = 10,
        phase: str | None = None,
        overall_status: str | None = None,
        study_type: str | None = None,
        intervention_type: str | None = None,
        min_start_date: str | None = None,
        has_results: bool | None = None,
    ) -> list[dict[str, Any]]:
        params: list[tuple[str, str]] = [
            ("query", query),
            ("limit", str(max(1, min(limit, 1000)))),
        ]
        if phase:
            params.append(("phase", phase))
        if overall_status:
            params.append(("overallStatus", overall_status))
        if study_type:
            params.append(("studyType", study_type))
        if intervention_type:
            params.append(("interventionType", intervention_type))
        if min_start_date:
            params.append(("minStartDate", min_start_date))
        if has_results is not None:
            params.append(("hasResults", "true" if has_results else "false"))
        data = await self._request("GET", "/cores/trialcore/records", params=params)
        return data if isinstance(data, list) else []

    async def get_trial(
        self,
        amass_id: str,
        *,
        include_outcomes: bool = True,
        include_detailed_description: bool = False,
        include_references: bool = False,
    ) -> dict[str, Any] | None:
        params: list[tuple[str, str]] = []
        if include_outcomes:
            params.append(("include", "outcomes"))
        if include_detailed_description:
            params.append(("include", "detailedDescription"))
        if include_references:
            params.append(("include", "referencesBiomedCore"))
        try:
            data = await self._request(
                "GET", f"/cores/trialcore/records/{amass_id}", params=params
            )
        except AmassError as e:
            if "404" in str(e):
                return None
            raise
        return data if isinstance(data, dict) else None

    async def lookup_papers(
        self, items: list[dict[str, str]]
    ) -> list[dict[str, Any]]:
        """POST /cores/biomedcore/records/lookup. Each item: exactly one of pmid or doi.

        Returns the per-item list as-is. Each entry has either `amassIds` (a list,
        usually length 1) or `error`. Callers must check both.
        """
        data = await self._request(
            "POST", "/cores/biomedcore/records/lookup", json_body={"items": items}
        )
        if isinstance(data, list):
            return data
        if isinstance(data, dict) and isinstance(data.get("items"), list):
            return data["items"]
        return []

    async def lookup_trials(
        self, items: list[dict[str, str]]
    ) -> list[dict[str, Any]]:
        """POST /cores/trialcore/records/lookup. Each item: nctId."""
        data = await self._request(
            "POST", "/cores/trialcore/records/lookup", json_body={"items": items}
        )
        if isinstance(data, list):
            return data
        if isinstance(data, dict) and isinstance(data.get("items"), list):
            return data["items"]
        return []

    async def _request(
        self,
        method: str,
        path: str,
        *,
        params: list[tuple[str, str]] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> Any:
        url = f"{self.BASE}{path}"
        for attempt in range(4):
            resp = await self._client.request(method, url, params=params, json=json_body)
            if resp.status_code == 200:
                payload = resp.json()
                return payload.get("data")
            if resp.status_code == 401:
                raise AmassError("401: auth failed — check AMASS_API_KEY.")
            if resp.status_code == 404:
                raise AmassError(f"404: not found — {method} {path}")
            if resp.status_code in (429, 500, 502, 503, 504) and attempt < 3:
                wait = _retry_after(resp) or (2**attempt)
                await asyncio.sleep(wait)
                continue
            raise AmassError(
                f"{resp.status_code}: {method} {path} failed — {resp.text[:500]}"
            )
        raise AmassError(f"{method} {path} failed after retries")


def _retry_after(resp: httpx.Response) -> int | None:
    value = resp.headers.get("Retry-After")
    if not value:
        return None
    try:
        return max(1, int(float(value)))
    except ValueError:
        return None
