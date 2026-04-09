#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

import app_store_connect_fetch as asc


ROOT = Path(__file__).resolve().parent.parent
PROJECT_FILE = ROOT / "DeskWellness.xcodeproj/project.pbxproj"
METADATA_ROOT = ROOT / "marketing/app_store/metadata/en-US"
RAW_SCREENSHOT_ROOT = ROOT / "marketing/app_store/screenshots/iphone-6.9/en-US/raw"
FINAL_SCREENSHOT_ROOT = ROOT / "marketing/app_store/screenshots/iphone-6.9/en-US/final"
DEFAULT_APP_ID = "6745263811"
DEFAULT_BUNDLE_ID = "chv.desk.wellness"
DEFAULT_LOCALE = "en-US"
IPHONE_SLOT = "APP_IPHONE_67"
DEFAULT_PRIMARY_CATEGORY = "Health & Fitness"
DEFAULT_SECONDARY_CATEGORY = "Productivity"
DEFAULT_REVIEW_CONTACT_NAME = "Petro Kulakov"
DEFAULT_REVIEW_CONTACT_EMAIL = "support@familyfund.app"
DEFAULT_COPYRIGHT = "2026 Petro Kulakov"


class ReleasePreparationError(RuntimeError):
    pass


def load_token(args: argparse.Namespace) -> str:
    issuer_id, key_id, key_path = asc.load_credentials(args)
    return asc.build_jwt(key_id, issuer_id, key_path, ttl_seconds=args.ttl_seconds)


def project_marketing_version(project_path: Path = PROJECT_FILE) -> str | None:
    if not project_path.exists():
        return None

    matches = re.findall(r"MARKETING_VERSION = ([^;]+);", project_path.read_text(encoding="utf-8"))
    return matches[0] if matches else None


def project_deployment_targets(project_path: Path = PROJECT_FILE) -> list[str]:
    if not project_path.exists():
        return []

    matches = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);", project_path.read_text(encoding="utf-8"))
    return sorted(set(matches))


def read_metadata(locale: str = DEFAULT_LOCALE) -> dict[str, str]:
    metadata_dir = METADATA_ROOT.parent / locale
    fields = [
        "name",
        "subtitle",
        "promotional_text",
        "description",
        "keywords",
        "review_notes",
        "marketing_url",
        "support_url",
        "privacy_url",
    ]
    metadata: dict[str, str] = {}
    for field in fields:
        path = metadata_dir / f"{field}.txt"
        if path.exists():
            metadata[field] = path.read_text(encoding="utf-8").strip()
    return metadata


def local_screenshot_paths(root: Path = FINAL_SCREENSHOT_ROOT) -> list[Path]:
    if not root.exists():
        return []
    return sorted(path for path in root.iterdir() if path.suffix.lower() == ".png")


def ensure_final_screenshots(root: Path = FINAL_SCREENSHOT_ROOT, source_root: Path = RAW_SCREENSHOT_ROOT) -> list[Path]:
    source_paths = sorted(path for path in source_root.iterdir() if path.suffix.lower() == ".png")
    if not source_paths:
        raise ReleasePreparationError(f"No raw screenshots found in {source_root}")

    root.mkdir(parents=True, exist_ok=True)
    for existing in root.iterdir():
        if existing.suffix.lower() == ".png":
            existing.unlink()

    synced: list[Path] = []
    for source_path in source_paths:
        destination = root / source_path.name
        shutil.copy2(source_path, destination)
        synced.append(destination)
    return synced


def find_app_id(token: str, bundle_id: str) -> str:
    apps = asc.flatten_json_api_data(
        asc.iter_json_pages("/v1/apps", token, params={"filter[bundleId]": bundle_id, "limit": 10})
    )
    if not apps:
        raise ReleasePreparationError(f"App {bundle_id} not found in App Store Connect")
    return apps[0]["id"]


def resolve_app_id(token: str, bundle_id: str, explicit_app_id: str | None) -> str:
    return explicit_app_id or find_app_id(token, bundle_id)


def list_versions(app_id: str, token: str) -> list[dict[str, Any]]:
    return asc.flatten_json_api_data(
        asc.iter_json_pages(
            f"/v1/apps/{app_id}/appStoreVersions",
            token,
            params={"filter[platform]": "IOS", "limit": 50},
        )
    )


def find_version(app_id: str, token: str, version_string: str | None) -> dict[str, Any]:
    versions = list_versions(app_id, token)
    if version_string:
        for version in versions:
            if version.get("attributes", {}).get("versionString") == version_string:
                return version
        raise ReleasePreparationError(f"App Store version {version_string} not found for app {app_id}")

    for version in versions:
        if version.get("attributes", {}).get("appStoreState") == "PREPARE_FOR_SUBMISSION":
            return version
    raise ReleasePreparationError(f"No PREPARE_FOR_SUBMISSION app store version found for app {app_id}")


def ensure_version(app_id: str, token: str, version_string: str) -> dict[str, Any]:
    try:
        return find_version(app_id, token, version_string)
    except ReleasePreparationError:
        payload = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": version_string,
                },
                "relationships": {
                    "app": {
                        "data": {
                            "type": "apps",
                            "id": app_id,
                        }
                    }
                },
            }
        }
        response = asc.request_json("POST", "/v1/appStoreVersions", token, payload=payload)
        return response["data"]


def list_version_localizations(version_id: str, token: str) -> list[dict[str, Any]]:
    response = asc.request_json(
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        token,
        params={"limit": 50},
    )
    return response.get("data", [])


def list_app_infos(app_id: str, token: str) -> list[dict[str, Any]]:
    response = asc.request_json(
        "GET",
        f"/v1/apps/{app_id}/appInfos",
        token,
        params={"limit": 50},
    )
    return response.get("data", [])


def list_app_info_localizations(app_info_id: str, token: str) -> list[dict[str, Any]]:
    response = asc.request_json(
        "GET",
        f"/v1/appInfos/{app_info_id}/appInfoLocalizations",
        token,
        params={"limit": 50},
    )
    return response.get("data", [])


def app_info_for_app(app_id: str, token: str) -> dict[str, Any]:
    app_infos = list_app_infos(app_id, token)
    if not app_infos:
        raise ReleasePreparationError(f"No app info records found for app {app_id}")
    return app_infos[0]


def get_app_info(app_info_id: str, token: str, *, include: str | None = None) -> dict[str, Any]:
    params = {"include": include} if include else None
    response = asc.request_json("GET", f"/v1/appInfos/{app_info_id}", token, params=params)
    return response


def list_app_categories(token: str) -> list[dict[str, Any]]:
    return asc.flatten_json_api_data(
        asc.iter_json_pages(
            "/v1/appCategories",
            token,
            params={"limit": 200},
        )
    )


def find_category(category_name: str, token: str) -> dict[str, Any]:
    normalized_query = normalize_category_token(category_name)
    matches = [
        category
        for category in list_app_categories(token)
        if (
            category.get("attributes", {}).get("name", "").casefold() == category_name.casefold()
            or category.get("id", "").upper() == normalized_query
        )
    ]
    if not matches:
        raise ReleasePreparationError(f"App Store category '{category_name}' not found")
    if len(matches) > 1:
        raise ReleasePreparationError(f"App Store category '{category_name}' is ambiguous")
    return matches[0]


def category_name_by_id(included: list[dict[str, Any]], category_id: str | None) -> str | None:
    if not category_id:
        return None
    for item in included:
        if item.get("type") == "appCategories" and item.get("id") == category_id:
            return item.get("attributes", {}).get("name") or item.get("id")
    return category_id


def normalize_category_token(value: str | None) -> str | None:
    if not value:
        return None
    normalized = value.upper().replace("&", "AND")
    return re.sub(r"[^A-Z0-9]+", "_", normalized).strip("_")


def split_contact_name(full_name: str) -> tuple[str, str]:
    parts = [part for part in full_name.strip().split() if part]
    if not parts:
        raise ReleasePreparationError("Review contact name cannot be empty")
    if len(parts) == 1:
        return parts[0], parts[0]
    return parts[0], " ".join(parts[1:])


def review_contact_phone(args: argparse.Namespace) -> str | None:
    return getattr(args, "contact_phone", None) or os.environ.get("ASC_REVIEW_CONTACT_PHONE")


def find_localization(localizations: list[dict[str, Any]], locale: str) -> dict[str, Any] | None:
    for localization in localizations:
        if localization.get("attributes", {}).get("locale") == locale:
            return localization
    return None


def get_version_localization(localization_id: str, token: str) -> dict[str, Any]:
    response = asc.request_json("GET", f"/v1/appStoreVersionLocalizations/{localization_id}", token)
    return response["data"]


def ensure_app_info_localization(app_info_id: str, token: str, locale: str) -> dict[str, Any]:
    existing = find_localization(list_app_info_localizations(app_info_id, token), locale)
    if existing:
        return existing

    payload = {
        "data": {
            "type": "appInfoLocalizations",
            "attributes": {"locale": locale},
            "relationships": {
                "appInfo": {
                    "data": {
                        "type": "appInfos",
                        "id": app_info_id,
                    }
                }
            },
        }
    }
    response = asc.request_json("POST", "/v1/appInfoLocalizations", token, payload=payload)
    return response["data"]


def ensure_version_localization(version_id: str, token: str, locale: str) -> dict[str, Any]:
    existing = find_localization(list_version_localizations(version_id, token), locale)
    if existing:
        return existing

    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": locale},
            "relationships": {
                "appStoreVersion": {
                    "data": {
                        "type": "appStoreVersions",
                        "id": version_id,
                    }
                }
            },
        }
    }
    response = asc.request_json("POST", "/v1/appStoreVersionLocalizations", token, payload=payload)
    return response["data"]


def patch_app_info_localization(
    localization_id: str,
    token: str,
    *,
    name: str,
    subtitle: str,
    privacy_url: str,
) -> None:
    payload = {
        "data": {
            "type": "appInfoLocalizations",
            "id": localization_id,
            "attributes": {
                "name": name,
                "subtitle": subtitle,
                "privacyPolicyUrl": privacy_url,
            },
        }
    }
    asc.request_json("PATCH", f"/v1/appInfoLocalizations/{localization_id}", token, payload=payload)


def patch_version_localization(localization_id: str, token: str, metadata: dict[str, str]) -> None:
    payload = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": localization_id,
            "attributes": {
                "promotionalText": metadata["promotional_text"],
                "description": metadata["description"],
                "keywords": metadata["keywords"],
                "marketingUrl": metadata["marketing_url"],
                "supportUrl": metadata["support_url"],
            },
        }
    }
    asc.request_json("PATCH", f"/v1/appStoreVersionLocalizations/{localization_id}", token, payload=payload)


def patch_app_info_categories(
    app_info_id: str,
    token: str,
    *,
    primary_category_id: str,
    secondary_category_id: str | None,
) -> None:
    relationships: dict[str, Any] = {
        "primaryCategory": {
            "data": {
                "type": "appCategories",
                "id": primary_category_id,
            }
        }
    }
    if secondary_category_id:
        relationships["secondaryCategory"] = {
            "data": {
                "type": "appCategories",
                "id": secondary_category_id,
            }
        }

    payload = {
        "data": {
            "type": "appInfos",
            "id": app_info_id,
            "relationships": relationships,
        }
    }
    asc.request_json("PATCH", f"/v1/appInfos/{app_info_id}", token, payload=payload)


def get_app_store_review_detail(version_id: str, token: str) -> dict[str, Any] | None:
    response = asc.request_json(
        "GET",
        f"/v1/appStoreVersions/{version_id}",
        token,
        params={"include": "appStoreReviewDetail"},
    )
    relationship = response.get("data", {}).get("relationships", {}).get("appStoreReviewDetail", {}).get("data")
    if relationship:
        for item in response.get("included", []):
            if item.get("type") == "appStoreReviewDetails" and item.get("id") == relationship.get("id"):
                return item
    return None


def ensure_app_store_review_detail(version_id: str, token: str) -> dict[str, Any]:
    existing = get_app_store_review_detail(version_id, token)
    if existing:
        return existing

    payload = {
        "data": {
            "type": "appStoreReviewDetails",
            "attributes": {
                "demoAccountRequired": False,
            },
            "relationships": {
                "appStoreVersion": {
                    "data": {
                        "type": "appStoreVersions",
                        "id": version_id,
                    }
                }
            },
        }
    }
    response = asc.request_json("POST", "/v1/appStoreReviewDetails", token, payload=payload)
    return response["data"]


def patch_app_store_review_detail(
    review_detail_id: str,
    token: str,
    *,
    contact_name: str,
    contact_email: str,
    contact_phone: str | None,
    notes: str,
) -> None:
    first_name, last_name = split_contact_name(contact_name)
    attributes: dict[str, Any] = {
        "contactFirstName": first_name,
        "contactLastName": last_name,
        "contactEmail": contact_email,
        "demoAccountRequired": False,
        "notes": notes,
    }
    if contact_phone:
        attributes["contactPhone"] = contact_phone

    payload = {
        "data": {
            "type": "appStoreReviewDetails",
            "id": review_detail_id,
            "attributes": attributes,
        }
    }
    asc.request_json("PATCH", f"/v1/appStoreReviewDetails/{review_detail_id}", token, payload=payload)


def patch_app_store_version(version_id: str, token: str, *, copyright_text: str) -> None:
    payload = {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "attributes": {
                "copyright": copyright_text,
            },
        }
    }
    asc.request_json("PATCH", f"/v1/appStoreVersions/{version_id}", token, payload=payload)


def screenshot_sets_for_localization(localization_id: str, token: str) -> list[dict[str, Any]]:
    response = asc.request_json(
        "GET",
        f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets",
        token,
        params={"include": "appScreenshots", "limit": 50, "limit[appScreenshots]": 20},
    )
    return response.get("data", [])


def request_no_content(method: str, path: str, token: str, payload: dict[str, Any] | None = None) -> None:
    asc.request_bytes(method, path, token=token, payload=payload)


def delete_screenshot_set(set_id: str, token: str) -> None:
    request_no_content("DELETE", f"/v1/appScreenshotSets/{set_id}", token)


def create_screenshot_set(localization_id: str, token: str, screenshot_display_type: str = IPHONE_SLOT) -> str:
    payload = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": screenshot_display_type},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization_id,
                    }
                }
            },
        }
    }
    response = asc.request_json("POST", "/v1/appScreenshotSets", token, payload=payload)
    return response["data"]["id"]


def recreate_screenshot_set(localization_id: str, token: str, screenshot_display_type: str = IPHONE_SLOT) -> str:
    for existing in screenshot_sets_for_localization(localization_id, token):
        if existing.get("attributes", {}).get("screenshotDisplayType") == screenshot_display_type:
            delete_screenshot_set(existing["id"], token)

    deadline = time.time() + 120
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            return create_screenshot_set(localization_id, token, screenshot_display_type)
        except asc.AppStoreConnectError as exc:
            last_error = exc
            message = str(exc).lower()
            if "already exists" not in message and "screenshotset" not in message:
                raise
            time.sleep(2)

    raise ReleasePreparationError(
        f"Timed out recreating screenshot set for {localization_id}/{screenshot_display_type}: {last_error}"
    )


def upload_operations(upload_operations: list[dict[str, Any]], bytes_data: bytes) -> None:
    for operation in upload_operations:
        headers = {item["name"]: item["value"] for item in operation["requestHeaders"]}
        start = operation["offset"]
        end = start + operation["length"]
        chunk = bytes_data[start:end]
        request = urllib.request.Request(operation["url"], data=chunk, headers=headers, method=operation["method"])
        with urllib.request.urlopen(request, timeout=300) as response:
            if response.status < 200 or response.status >= 300:
                raise ReleasePreparationError(f"Upload failed with status {response.status} for {operation['url']}")


def create_screenshot(set_id: str, path: Path, token: str) -> str:
    bytes_data = path.read_bytes()
    payload = {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(bytes_data), "fileName": path.name},
            "relationships": {
                "appScreenshotSet": {
                    "data": {
                        "type": "appScreenshotSets",
                        "id": set_id,
                    }
                }
            },
        }
    }
    response = asc.request_json("POST", "/v1/appScreenshots", token, payload=payload)
    screenshot = response["data"]
    upload_operations(screenshot["attributes"]["uploadOperations"], bytes_data)
    asc.request_json(
        "PATCH",
        f"/v1/appScreenshots/{screenshot['id']}",
        token,
        payload={
            "data": {
                "type": "appScreenshots",
                "id": screenshot["id"],
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": hashlib.md5(bytes_data).hexdigest(),
                },
            }
        },
    )
    return screenshot["id"]


def wait_for_screenshot(screenshot_id: str, token: str, timeout_seconds: int = 1200) -> None:
    started = time.time()
    while True:
        response = asc.request_json("GET", f"/v1/appScreenshots/{screenshot_id}", token)
        state = response["data"]["attributes"]["assetDeliveryState"]["state"]
        if state == "COMPLETE":
            return
        if state == "FAILED":
            errors = response["data"]["attributes"]["assetDeliveryState"].get("errors") or []
            raise ReleasePreparationError(f"Screenshot processing failed for {screenshot_id}: {errors}")
        if time.time() - started > timeout_seconds:
            raise ReleasePreparationError(f"Timed out waiting for screenshot {screenshot_id} to finish processing")
        time.sleep(2)


def sync_iphone_screenshots(version_id: str, token: str, locale: str = DEFAULT_LOCALE) -> list[str]:
    localization = ensure_version_localization(version_id, token, locale)
    screenshot_paths = local_screenshot_paths()
    if not screenshot_paths:
        raise ReleasePreparationError(f"No approved screenshots found in {FINAL_SCREENSHOT_ROOT}")

    set_id = recreate_screenshot_set(localization["id"], token, IPHONE_SLOT)
    uploaded: list[str] = []
    for screenshot_path in screenshot_paths:
        screenshot_id = create_screenshot(set_id, screenshot_path, token)
        wait_for_screenshot(screenshot_id, token)
        uploaded.append(screenshot_path.name)
    return uploaded


def build_release_report(args: argparse.Namespace) -> dict[str, Any]:
    metadata = read_metadata(args.locale)
    token = load_token(args)
    app_id = resolve_app_id(token, args.bundle_id, args.app_id)
    version = find_version(app_id, token, args.version)
    version_id = version["id"]

    app_response = asc.request_json("GET", f"/v1/apps/{app_id}", token)
    app_attributes = app_response["data"]["attributes"]

    app_info = app_info_for_app(app_id, token)
    app_info_detail = get_app_info(app_info["id"], token, include="primaryCategory,secondaryCategory")
    app_info_localization = find_localization(list_app_info_localizations(app_info["id"], token), args.locale)
    version_localization = find_localization(list_version_localizations(version_id, token), args.locale)
    if version_localization is not None:
        version_localization = get_version_localization(version_localization["id"], token)

    detail = asc.request_json(
        "GET",
        f"/v1/appStoreVersions/{version_id}",
        token,
        params={"include": "build,appStoreReviewDetail"},
    )
    build_rel = detail["data"].get("relationships", {}).get("build", {}).get("data")
    build_id = build_rel.get("id") if build_rel else None
    build = next((item for item in detail.get("included", []) if item.get("type") == "builds"), None)
    build_attributes = build.get("attributes", {}) if build else {}
    review_detail_rel = detail["data"].get("relationships", {}).get("appStoreReviewDetail", {}).get("data")
    review_detail = next(
        (
            item
            for item in detail.get("included", [])
            if item.get("type") == "appStoreReviewDetails" and item.get("id") == (review_detail_rel or {}).get("id")
        ),
        None,
    )
    review_attrs = review_detail.get("attributes", {}) if review_detail else {}

    screenshot_sets = screenshot_sets_for_localization(version_localization["id"], token) if version_localization else []
    screenshot_counts = {
        item.get("attributes", {}).get("screenshotDisplayType"): len(
            item.get("relationships", {}).get("appScreenshots", {}).get("data", [])
        )
        for item in screenshot_sets
    }

    final_paths = local_screenshot_paths()
    raw_paths = sorted(path for path in RAW_SCREENSHOT_ROOT.iterdir() if path.suffix.lower() == ".png")
    project_version = project_marketing_version()
    project_targets = project_deployment_targets()

    app_info_attrs = app_info_localization.get("attributes", {}) if app_info_localization else {}
    version_attrs = version_localization.get("attributes", {}) if version_localization else {}
    app_info_detail_data = app_info_detail.get("data", {})
    app_info_detail_relationships = app_info_detail_data.get("relationships", {})
    app_info_included = app_info_detail.get("included", [])
    primary_category_rel = app_info_detail_relationships.get("primaryCategory", {}).get("data") or {}
    secondary_category_rel = app_info_detail_relationships.get("secondaryCategory", {}).get("data") or {}
    primary_category_id = primary_category_rel.get("id")
    secondary_category_id = secondary_category_rel.get("id")
    primary_category_name = category_name_by_id(app_info_included, primary_category_id)
    secondary_category_name = category_name_by_id(app_info_included, secondary_category_id)
    desired_primary_category = getattr(args, "primary_category", DEFAULT_PRIMARY_CATEGORY)
    desired_secondary_category = getattr(args, "secondary_category", DEFAULT_SECONDARY_CATEGORY)
    desired_copyright = getattr(args, "copyright", DEFAULT_COPYRIGHT)
    desired_contact_name = getattr(args, "contact_name", DEFAULT_REVIEW_CONTACT_NAME)
    desired_contact_email = getattr(args, "contact_email", DEFAULT_REVIEW_CONTACT_EMAIL)
    desired_contact_phone = review_contact_phone(args)
    live_min_os = build_attributes.get("minOsVersion")

    blockers: list[str] = []
    if app_attributes.get("name") != metadata["name"]:
        blockers.append(f"App record name is {app_attributes.get('name') or 'nil'} expected {metadata['name']}")
    if app_info_localization is None:
        blockers.append(f"Missing {args.locale} app info localization")
    elif app_info_attrs.get("name") != metadata["name"]:
        blockers.append(f"en-US app name is {app_info_attrs.get('name') or 'nil'} expected {metadata['name']}")
    if app_info_localization is not None and app_info_attrs.get("subtitle") != metadata["subtitle"]:
        blockers.append(f"subtitle is {app_info_attrs.get('subtitle') or 'nil'} expected {metadata['subtitle']}")
    if app_info_localization is not None and app_info_attrs.get("privacyPolicyUrl") != metadata["privacy_url"]:
        blockers.append(
            f"privacy URL is {app_info_attrs.get('privacyPolicyUrl') or 'nil'} expected {metadata['privacy_url']}"
        )
    if normalize_category_token(primary_category_name) != normalize_category_token(desired_primary_category):
        blockers.append(
            f"primary category is {primary_category_name or 'nil'} expected {desired_primary_category}"
        )
    if normalize_category_token(secondary_category_name) != normalize_category_token(desired_secondary_category):
        blockers.append(
            f"secondary category is {secondary_category_name or 'nil'} expected {desired_secondary_category}"
        )
    if version_localization is None:
        blockers.append(f"Missing {args.locale} version localization")
    if version_localization is not None and version_attrs.get("description") != metadata["description"]:
        blockers.append("description is not aligned to the repo baseline")
    if version_localization is not None and version_attrs.get("promotionalText") != metadata["promotional_text"]:
        blockers.append("promotional text is not aligned to the repo baseline")
    if version_localization is not None and version_attrs.get("keywords") != metadata["keywords"]:
        blockers.append("keywords are not aligned to the repo baseline")
    if version_localization is not None and version_attrs.get("supportUrl") != metadata["support_url"]:
        blockers.append(f"support URL is {version_attrs.get('supportUrl') or 'nil'} expected {metadata['support_url']}")
    if version_localization is not None and version_attrs.get("marketingUrl") != metadata["marketing_url"]:
        blockers.append(
            f"marketing URL is {version_attrs.get('marketingUrl') or 'nil'} expected {metadata['marketing_url']}"
        )
    if version.get("attributes", {}).get("copyright") != desired_copyright:
        blockers.append(
            f"copyright is {version.get('attributes', {}).get('copyright') or 'nil'} expected {desired_copyright}"
        )
    if not review_detail:
        blockers.append("Missing App Store review detail")
    if review_detail and review_attrs.get("contactFirstName") != split_contact_name(desired_contact_name)[0]:
        blockers.append(
            f"review contact first name is {review_attrs.get('contactFirstName') or 'nil'} expected {split_contact_name(desired_contact_name)[0]}"
        )
    if review_detail and review_attrs.get("contactLastName") != split_contact_name(desired_contact_name)[1]:
        blockers.append(
            f"review contact last name is {review_attrs.get('contactLastName') or 'nil'} expected {split_contact_name(desired_contact_name)[1]}"
        )
    if review_detail and review_attrs.get("contactEmail") != desired_contact_email:
        blockers.append(
            f"review contact email is {review_attrs.get('contactEmail') or 'nil'} expected {desired_contact_email}"
        )
    if desired_contact_phone:
        if review_detail and review_attrs.get("contactPhone") != desired_contact_phone:
            blockers.append(
                f"review contact phone is {review_attrs.get('contactPhone') or 'nil'} expected {desired_contact_phone}"
            )
    elif review_detail and not review_attrs.get("contactPhone"):
        blockers.append("review contact phone is missing")
    if project_version and version.get("attributes", {}).get("versionString") != project_version:
        blockers.append(
            f"App Store version is {version.get('attributes', {}).get('versionString')} but project marketing version is {project_version}"
        )
    if not final_paths:
        blockers.append("Approved final screenshots are empty")
    if screenshot_counts.get(IPHONE_SLOT, 0) < len(final_paths):
        blockers.append(
            f"App Store Connect has {screenshot_counts.get(IPHONE_SLOT, 0)}/{len(final_paths)} iPhone 6.9 screenshots"
        )
    if not build_id:
        blockers.append("No build is attached to the selected App Store version")
    if build_id and build_attributes.get("processingState") != "VALID":
        blockers.append(f"Attached build processing state is {build_attributes.get('processingState') or 'nil'}")
    if live_min_os and project_targets and live_min_os not in project_targets:
        blockers.append(
            f"Attached build minimum OS {live_min_os} does not match project deployment target(s) {', '.join(project_targets)}"
        )

    return {
        "app": {
            "id": app_id,
            "bundleId": app_attributes.get("bundleId"),
            "name": app_attributes.get("name"),
            "sku": app_attributes.get("sku"),
            "primaryLocale": app_attributes.get("primaryLocale"),
        },
        "project": {
            "marketingVersion": project_version,
            "deploymentTargets": project_targets,
            "finalScreenshotCount": len(final_paths),
            "rawScreenshotCount": len(raw_paths),
        },
        "version": {
            "id": version_id,
            "versionString": version.get("attributes", {}).get("versionString"),
            "state": version.get("attributes", {}).get("appStoreState"),
        },
        "appInfoLocalization": {
            "locale": args.locale,
            "name": app_info_attrs.get("name"),
            "subtitle": app_info_attrs.get("subtitle"),
            "privacyPolicyUrl": app_info_attrs.get("privacyPolicyUrl"),
            "primaryCategory": primary_category_name,
            "secondaryCategory": secondary_category_name,
        },
        "versionLocalization": {
            "locale": args.locale,
            "promotionalText": version_attrs.get("promotionalText"),
            "description": version_attrs.get("description"),
            "keywords": version_attrs.get("keywords"),
            "supportUrl": version_attrs.get("supportUrl"),
            "marketingUrl": version_attrs.get("marketingUrl"),
        },
        "screenshots": {
            "slot": IPHONE_SLOT,
            "count": screenshot_counts.get(IPHONE_SLOT, 0),
            "expectedCount": len(final_paths),
            "files": [path.name for path in final_paths],
        },
        "liveBuild": {
            "id": build_id,
            "version": build_attributes.get("version"),
            "processingState": build_attributes.get("processingState"),
            "uploadedDate": build_attributes.get("uploadedDate"),
            "minOsVersion": live_min_os,
        },
        "reviewDetail": {
            "id": review_detail.get("id") if review_detail else None,
            "contactFirstName": review_attrs.get("contactFirstName"),
            "contactLastName": review_attrs.get("contactLastName"),
            "contactEmail": review_attrs.get("contactEmail"),
            "contactPhone": review_attrs.get("contactPhone"),
            "notesPresent": bool(review_attrs.get("notes")),
            "demoAccountRequired": review_attrs.get("demoAccountRequired"),
        },
        "versionMetadata": {
            "copyright": version.get("attributes", {}).get("copyright"),
        },
        "manualBlockers": blockers,
        "manualSteps": [
            "Complete the App Privacy answers in App Store Connect so they match the current local-first camera and reminder behavior.",
            "Set Content Rights Information in App Store Connect so it matches the final bundled assets and their ownership.",
            "Choose the final App Store price tier in App Store Connect if it has not already been saved.",
            "Run and record the real-device release checklist before submitting the first version.",
            "Archive and upload a signed build that matches the selected App Store version, then attach it if no VALID build is present.",
        ],
    }


def write_report(report: dict[str, Any], output_path: Path | None) -> None:
    payload = json.dumps(report, indent=2, ensure_ascii=False)
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(payload + "\n", encoding="utf-8")
        print(f"Wrote release report to {output_path}")
    print(payload)


def command_approve_screenshots(args: argparse.Namespace) -> int:
    synced = ensure_final_screenshots()
    print(json.dumps({"approvedScreenshots": [path.name for path in synced]}, indent=2))
    return 0


def command_sync_metadata(args: argparse.Namespace) -> int:
    metadata = read_metadata(args.locale)
    token = load_token(args)
    app_id = resolve_app_id(token, args.bundle_id, args.app_id)
    version_string = args.version or project_marketing_version()
    if args.create_version_if_missing and version_string:
        version = ensure_version(app_id, token, version_string)
    else:
        version = find_version(app_id, token, args.version)

    app_info = app_info_for_app(app_id, token)
    app_info_localization = ensure_app_info_localization(app_info["id"], token, args.locale)
    version_localization = ensure_version_localization(version["id"], token, args.locale)

    patch_app_info_localization(
        app_info_localization["id"],
        token,
        name=metadata["name"],
        subtitle=metadata["subtitle"],
        privacy_url=metadata["privacy_url"],
    )
    patch_version_localization(version_localization["id"], token, metadata)
    refreshed_version_localization = get_version_localization(version_localization["id"], token)
    refreshed_attrs = refreshed_version_localization.get("attributes", {})

    print(
        json.dumps(
            {
                "appId": app_id,
                "versionId": version["id"],
                "versionLocalizationId": refreshed_version_localization["id"],
                "versionString": version.get("attributes", {}).get("versionString"),
                "locale": args.locale,
                "livePromotionalText": refreshed_attrs.get("promotionalText"),
                "synced": [
                    "app name",
                    "subtitle",
                    "privacy URL",
                    "promotional text",
                    "description",
                    "keywords",
                    "support URL",
                    "marketing URL",
                ],
            },
            indent=2,
        )
    )
    return 0


def command_sync_app_record(args: argparse.Namespace) -> int:
    metadata = read_metadata(args.locale)
    token = load_token(args)
    app_id = resolve_app_id(token, args.bundle_id, args.app_id)
    version_string = args.version or project_marketing_version()
    if args.create_version_if_missing and version_string:
        version = ensure_version(app_id, token, version_string)
    else:
        version = find_version(app_id, token, args.version)

    app_info = app_info_for_app(app_id, token)
    primary_category = find_category(args.primary_category, token)
    secondary_category = find_category(args.secondary_category, token) if args.secondary_category else None
    patch_app_info_categories(
        app_info["id"],
        token,
        primary_category_id=primary_category["id"],
        secondary_category_id=secondary_category["id"] if secondary_category else None,
    )

    patch_app_store_version(version["id"], token, copyright_text=args.copyright)

    review_detail = ensure_app_store_review_detail(version["id"], token)
    patch_app_store_review_detail(
        review_detail["id"],
        token,
        contact_name=args.contact_name,
        contact_email=args.contact_email,
        contact_phone=review_contact_phone(args),
        notes=metadata["review_notes"],
    )

    refreshed_app_info = get_app_info(app_info["id"], token, include="primaryCategory,secondaryCategory")
    refreshed_version = asc.request_json("GET", f"/v1/appStoreVersions/{version['id']}", token)
    refreshed_review_detail = get_app_store_review_detail(version["id"], token)

    relationships = refreshed_app_info.get("data", {}).get("relationships", {})
    included = refreshed_app_info.get("included", [])
    refreshed_primary = category_name_by_id(
        included,
        (relationships.get("primaryCategory", {}).get("data") or {}).get("id"),
    )
    refreshed_secondary = category_name_by_id(
        included,
        (relationships.get("secondaryCategory", {}).get("data") or {}).get("id"),
    )
    refreshed_review_attrs = refreshed_review_detail.get("attributes", {}) if refreshed_review_detail else {}

    print(
        json.dumps(
            {
                "appId": app_id,
                "versionId": version["id"],
                "versionString": version.get("attributes", {}).get("versionString"),
                "primaryCategory": refreshed_primary,
                "secondaryCategory": refreshed_secondary,
                "copyright": refreshed_version.get("data", {}).get("attributes", {}).get("copyright"),
                "reviewContactName": " ".join(
                    part
                    for part in [
                        refreshed_review_attrs.get("contactFirstName"),
                        refreshed_review_attrs.get("contactLastName"),
                    ]
                    if part
                ),
                "reviewContactEmail": refreshed_review_attrs.get("contactEmail"),
                "reviewContactPhone": refreshed_review_attrs.get("contactPhone"),
                "reviewNotesPresent": bool(refreshed_review_attrs.get("notes")),
                "synced": [
                    "primary category",
                    "secondary category",
                    "copyright",
                    "review contact",
                    "review notes",
                ],
            },
            indent=2,
        )
    )
    return 0


def command_sync_iphone_screenshots(args: argparse.Namespace) -> int:
    token = load_token(args)
    app_id = resolve_app_id(token, args.bundle_id, args.app_id)
    version_string = args.version or project_marketing_version()
    if args.create_version_if_missing and version_string:
        version = ensure_version(app_id, token, version_string)
    else:
        version = find_version(app_id, token, args.version)

    uploaded = sync_iphone_screenshots(version["id"], token, args.locale)
    print(
        json.dumps(
            {
                "appId": app_id,
                "versionId": version["id"],
                "versionString": version.get("attributes", {}).get("versionString"),
                "locale": args.locale,
                "uploadedScreenshots": uploaded,
            },
            indent=2,
        )
    )
    return 0


def command_verify(args: argparse.Namespace) -> int:
    report = build_release_report(args)
    write_report(report, Path(args.report_path) if args.report_path else None)
    return 0


def command_list_categories(args: argparse.Namespace) -> int:
    token = load_token(args)
    categories = list_app_categories(token)
    payload = [
        {
            "id": category.get("id"),
            "type": category.get("type"),
            "name": category.get("attributes", {}).get("name"),
            "parent": category.get("relationships", {}).get("parent", {}).get("data"),
            "subcategories": category.get("relationships", {}).get("subcategories", {}).get("data"),
        }
        for category in categories
    ]
    print(json.dumps(payload, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ResetMinute App Store release preparation system.")
    parser.add_argument("--issuer-id", help="App Store Connect API issuer ID. Defaults to ASC_ISSUER_ID.")
    parser.add_argument("--key-id", help="App Store Connect API key ID. Defaults to ASC_KEY_ID.")
    parser.add_argument("--private-key-path", help="Path to the App Store Connect .p8 private key.")
    parser.add_argument("--ttl-seconds", type=int, default=900, help="JWT lifetime in seconds.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    approve_parser = subparsers.add_parser(
        "approve-screenshots",
        help="Copy the current raw screenshot set into the approved final upload set.",
    )
    approve_parser.set_defaults(func=command_approve_screenshots)

    sync_metadata_parser = subparsers.add_parser(
        "sync-metadata",
        help="Sync the repo metadata baseline into the live App Store Connect listing.",
    )
    sync_metadata_parser.add_argument("--app-id", default=DEFAULT_APP_ID)
    sync_metadata_parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    sync_metadata_parser.add_argument("--version", help="Explicit App Store version string.")
    sync_metadata_parser.add_argument("--locale", default=DEFAULT_LOCALE)
    sync_metadata_parser.add_argument("--create-version-if-missing", action="store_true")
    sync_metadata_parser.set_defaults(func=command_sync_metadata)

    sync_app_record_parser = subparsers.add_parser(
        "sync-app-record",
        help="Sync App Store app-record fields that are not part of localized metadata.",
    )
    sync_app_record_parser.add_argument("--app-id", default=DEFAULT_APP_ID)
    sync_app_record_parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    sync_app_record_parser.add_argument("--version", help="Explicit App Store version string.")
    sync_app_record_parser.add_argument("--locale", default=DEFAULT_LOCALE)
    sync_app_record_parser.add_argument("--create-version-if-missing", action="store_true")
    sync_app_record_parser.add_argument("--primary-category", default=DEFAULT_PRIMARY_CATEGORY)
    sync_app_record_parser.add_argument("--secondary-category", default=DEFAULT_SECONDARY_CATEGORY)
    sync_app_record_parser.add_argument("--contact-name", default=DEFAULT_REVIEW_CONTACT_NAME)
    sync_app_record_parser.add_argument("--contact-email", default=DEFAULT_REVIEW_CONTACT_EMAIL)
    sync_app_record_parser.add_argument(
        "--contact-phone",
        help="Review contact phone number. Defaults to ASC_REVIEW_CONTACT_PHONE if set.",
    )
    sync_app_record_parser.add_argument("--copyright", default=DEFAULT_COPYRIGHT)
    sync_app_record_parser.set_defaults(func=command_sync_app_record)

    sync_screenshots_parser = subparsers.add_parser(
        "sync-iphone-screenshots",
        help="Upload the approved iPhone 6.9 screenshot set for the selected App Store version.",
    )
    sync_screenshots_parser.add_argument("--app-id", default=DEFAULT_APP_ID)
    sync_screenshots_parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    sync_screenshots_parser.add_argument("--version", help="Explicit App Store version string.")
    sync_screenshots_parser.add_argument("--locale", default=DEFAULT_LOCALE)
    sync_screenshots_parser.add_argument("--create-version-if-missing", action="store_true")
    sync_screenshots_parser.set_defaults(func=command_sync_iphone_screenshots)

    verify_parser = subparsers.add_parser(
        "verify",
        help="Inspect the current ResetMinute App Store state and emit a readiness report.",
    )
    verify_parser.add_argument("--app-id", default=DEFAULT_APP_ID)
    verify_parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    verify_parser.add_argument("--version", help="Explicit App Store version string.")
    verify_parser.add_argument("--locale", default=DEFAULT_LOCALE)
    verify_parser.add_argument("--primary-category", default=DEFAULT_PRIMARY_CATEGORY)
    verify_parser.add_argument("--secondary-category", default=DEFAULT_SECONDARY_CATEGORY)
    verify_parser.add_argument("--contact-name", default=DEFAULT_REVIEW_CONTACT_NAME)
    verify_parser.add_argument("--contact-email", default=DEFAULT_REVIEW_CONTACT_EMAIL)
    verify_parser.add_argument(
        "--contact-phone",
        help="Expected review contact phone number. Defaults to ASC_REVIEW_CONTACT_PHONE if set.",
    )
    verify_parser.add_argument("--copyright", default=DEFAULT_COPYRIGHT)
    verify_parser.add_argument("--report-path")
    verify_parser.set_defaults(func=command_verify)

    categories_parser = subparsers.add_parser(
        "list-categories",
        help="List App Store categories visible to the API key.",
    )
    categories_parser.set_defaults(func=command_list_categories)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except (ReleasePreparationError, asc.AppStoreConnectError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
