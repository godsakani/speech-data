#!/usr/bin/env python3
"""
Export the speech dataset via the API: English/Swahili WAVs + metadata (lengths, text).
Usage:
  pip install requests
  export BASE_URL=https://speech-data-production.up.railway.app   # or default below
  python export_dataset.py [--output-dir ./export_dataset] [--format json|csv] [--limit N]
"""
import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Install requests: pip install requests", file=sys.stderr)
    sys.exit(1)

DEFAULT_BASE_URL = "https://speech-data-production.up.railway.app"
PAGE_SIZE = 100


def sanitize_id(id_str: str) -> str:
    """Use id in filenames; replace any character unsafe for filesystems."""
    return re.sub(r"[^\w\-.]", "_", id_str) or "item"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export speech dataset (English/Swahili WAVs + metadata) via API"
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("BASE_URL", DEFAULT_BASE_URL),
        help="API base URL (default: env BASE_URL or production)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("export_dataset"),
        help="Output directory for WAVs and metadata",
    )
    parser.add_argument(
        "--format",
        choices=("json", "csv"),
        default="csv",
        help="Metadata format: json or csv (default: csv)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max number of items to export (default: all)",
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=PAGE_SIZE,
        help=f"Items per page when listing (default: {PAGE_SIZE})",
    )
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    out_dir = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    session = requests.Session()
    session.headers["Accept"] = "application/json"

    # Paginate list
    items: list[dict] = []
    page = 1
    while True:
        r = session.get(
            f"{base}/api/audio",
            params={"page": page, "limit": args.page_size},
            timeout=30,
        )
        r.raise_for_status()
        data = r.json()
        batch = data.get("items") or []
        if not batch:
            break
        items.extend(batch)
        if args.limit and len(items) >= args.limit:
            items = items[: args.limit]
            break
        if len(batch) < args.page_size:
            break
        page += 1

    if not items:
        print("No items to export.", file=sys.stderr)
        return

    metadata_rows: list[dict] = []

    for i, item in enumerate(items):
        id_ = item.get("id") or str(i)
        sid = sanitize_id(id_)
        length_english = item.get("length_english")
        length_swahili = item.get("length_swahili")
        text_english = item.get("text_english")
        status = item.get("status", "pending")
        is_submitted = status == "submitted"

        # English WAV
        try:
            r_en = session.get(f"{base}/api/audio/{id_}/english", timeout=60)
            r_en.raise_for_status()
            (out_dir / f"{sid}_english.wav").write_bytes(r_en.content)
            has_english = True
        except Exception as e:
            print(f"Warning: could not fetch English audio for {id_}: {e}", file=sys.stderr)
            has_english = False

        # Swahili WAV only when submitted
        has_swahili = False
        if is_submitted:
            try:
                r_sw = session.get(f"{base}/api/audio/{id_}/swahili", timeout=60)
                r_sw.raise_for_status()
                (out_dir / f"{sid}_swahili.wav").write_bytes(r_sw.content)
                has_swahili = True
            except Exception as e:
                print(f"Warning: could not fetch Swahili audio for {id_}: {e}", file=sys.stderr)

        english_audio_file = f"{sid}_english.wav"
        swahili_audio_file = f"{sid}_swahili.wav" if has_swahili else ""
        metadata_rows.append({
            "id": id_,
            "english_audio_file": english_audio_file,
            "swahili_audio_file": swahili_audio_file,
            "length_english": length_english,
            "length_swahili": length_swahili,
            "text_english": text_english or "",
            "status": status,
            "has_english_audio": has_english,
            "has_swahili_audio": has_swahili,
        })

    # Write metadata
    if args.format == "json":
        (out_dir / "metadata.json").write_text(
            json.dumps(metadata_rows, indent=2), encoding="utf-8"
        )
    else:
        if metadata_rows:
            with open(out_dir / "metadata.csv", "w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(
                    f,
                    fieldnames=[
                        "id", "english_audio_file", "swahili_audio_file",
                        "length_english", "length_swahili", "text_english",
                        "status", "has_english_audio", "has_swahili_audio",
                    ],
                )
                w.writeheader()
                w.writerows(metadata_rows)

    print(f"Exported {len(items)} items to {out_dir}")
    print(f"Metadata: metadata.{args.format}")


if __name__ == "__main__":
    main()
