#!/usr/bin/env python3

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

API_BASE_URL = "https://api.appstoreconnect.apple.com"
TOKEN_AUDIENCE = "appstoreconnect-v1"


class AppStoreConnectError(RuntimeError):
    pass


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def read_length(data: bytes, offset: int) -> tuple[int, int]:
    first = data[offset]
    offset += 1
    if first < 0x80:
        return first, offset

    length_bytes = first & 0x7F
    if length_bytes == 0 or length_bytes > 4:
        raise AppStoreConnectError("Unsupported DER length encoding")

    end = offset + length_bytes
    return int.from_bytes(data[offset:end], "big"), end


def der_signature_to_raw(signature: bytes, part_size: int = 32) -> bytes:
    if not signature or signature[0] != 0x30:
        raise AppStoreConnectError("Unexpected DER signature format")

    sequence_length, offset = read_length(signature, 1)
    end = offset + sequence_length

    def read_integer(cursor: int) -> tuple[bytes, int]:
        if signature[cursor] != 0x02:
            raise AppStoreConnectError("Unexpected DER integer marker")
        integer_length, cursor = read_length(signature, cursor + 1)
        integer_end = cursor + integer_length
        return signature[cursor:integer_end], integer_end

    r_bytes, offset = read_integer(offset)
    s_bytes, offset = read_integer(offset)
    if offset != end:
        raise AppStoreConnectError("Unexpected trailing bytes in DER signature")

    r_bytes = r_bytes.lstrip(b"\x00")
    s_bytes = s_bytes.lstrip(b"\x00")
    if len(r_bytes) > part_size or len(s_bytes) > part_size:
        raise AppStoreConnectError("ECDSA signature component is too large")

    return r_bytes.rjust(part_size, b"\x00") + s_bytes.rjust(part_size, b"\x00")


def build_jwt(key_id: str, issuer_id: str, private_key_path: Path, ttl_seconds: int = 900) -> str:
    if ttl_seconds <= 0:
        raise AppStoreConnectError("Token lifetime must be positive")

    issued_at = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer_id,
        "iat": issued_at,
        "exp": issued_at + ttl_seconds,
        "aud": TOKEN_AUDIENCE,
    }

    signing_input = ".".join(
        [
            b64url(json.dumps(header, separators=(",", ":"), sort_keys=True).encode("utf-8")),
            b64url(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")),
        ]
    ).encode("ascii")

    try:
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", str(private_key_path), "-binary"],
            input=signing_input,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
    except FileNotFoundError as exc:
        raise AppStoreConnectError("openssl is required but was not found in PATH") from exc
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.decode("utf-8", errors="replace").strip() or "openssl signing failed"
        raise AppStoreConnectError(message) from exc

    raw_signature = der_signature_to_raw(result.stdout)
    return signing_input.decode("ascii") + "." + b64url(raw_signature)


def load_credentials(args: argparse.Namespace) -> tuple[str, str, Path]:
    issuer_id = getattr(args, "issuer_id", None) or os.environ.get("ASC_ISSUER_ID")
    key_id = getattr(args, "key_id", None) or os.environ.get("ASC_KEY_ID")
    private_key_path = getattr(args, "private_key_path", None) or os.environ.get("ASC_PRIVATE_KEY_PATH")

    missing = []
    if not issuer_id:
        missing.append("ASC_ISSUER_ID")
    if not key_id:
        missing.append("ASC_KEY_ID")
    if not private_key_path:
        missing.append("ASC_PRIVATE_KEY_PATH")
    if missing:
        raise AppStoreConnectError("Missing credentials: " + ", ".join(missing))

    key_path = Path(private_key_path).expanduser()
    if not key_path.exists():
        raise AppStoreConnectError(f"Private key not found: {key_path}")

    return issuer_id, key_id, key_path


def build_url(path_or_url: str, params: dict[str, Any] | None = None) -> str:
    if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
        url = path_or_url
    else:
        url = API_BASE_URL.rstrip("/") + path_or_url

    if not params:
        return url

    query = urllib.parse.urlencode(params, doseq=True)
    separator = "&" if urllib.parse.urlparse(url).query else "?"
    return url + separator + query


def parse_error_response(body: bytes) -> str:
    if not body:
        return "Unknown App Store Connect API error"

    try:
        payload = json.loads(body.decode("utf-8"))
    except Exception:
        return body.decode("utf-8", errors="replace")

    errors = payload.get("errors")
    if isinstance(errors, list) and errors:
        parts = []
        for error in errors:
            status = error.get("status")
            code = error.get("code")
            title = error.get("title")
            detail = error.get("detail")
            piece = " ".join(str(value) for value in [status, code, title] if value)
            if detail:
                piece = f"{piece}: {detail}" if piece else str(detail)
            parts.append(piece)
        return "; ".join(parts)

    return json.dumps(payload, indent=2)


def request_bytes(
    method: str,
    path_or_url: str,
    *,
    token: str | None = None,
    params: dict[str, Any] | None = None,
    payload: dict[str, Any] | None = None,
) -> tuple[bytes, dict[str, str]]:
    url = build_url(path_or_url, params=params)
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Accept": "application/json",
        "User-Agent": "ResetMinute-AppStoreConnect/1.0",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if payload is not None:
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, method=method, headers=headers)

    try:
        with urllib.request.urlopen(request) as response:
            body = response.read()
            response_headers = {key.lower(): value for key, value in response.headers.items()}
            return body, response_headers
    except urllib.error.HTTPError as exc:
        body = exc.read()
        message = parse_error_response(body)
        raise AppStoreConnectError(f"{exc.code} {url}: {message}") from exc
    except urllib.error.URLError as exc:
        raise AppStoreConnectError(f"Request failed for {url}: {exc.reason}") from exc


def request_json(
    method: str,
    path_or_url: str,
    token: str,
    *,
    params: dict[str, Any] | None = None,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    body, _ = request_bytes(method, path_or_url, token=token, params=params, payload=payload)
    try:
        return json.loads(body.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise AppStoreConnectError("Expected JSON response from App Store Connect") from exc


def iter_json_pages(path: str, token: str, params: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    pages: list[dict[str, Any]] = []
    seen_urls: set[str] = set()
    next_url = build_url(path, params)

    for _ in range(50):
        if next_url in seen_urls:
            raise AppStoreConnectError(f"Pagination loop detected for {next_url}")
        seen_urls.add(next_url)

        page = request_json("GET", next_url, token)
        pages.append(page)
        next_url = page.get("links", {}).get("next")
        if not next_url:
            return pages

    raise AppStoreConnectError("Pagination exceeded the safety limit of 50 pages")


def flatten_json_api_data(pages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    data: list[dict[str, Any]] = []
    for page in pages:
        page_data = page.get("data", [])
        if isinstance(page_data, list):
            data.extend(page_data)
        elif isinstance(page_data, dict):
            data.append(page_data)
    return data

