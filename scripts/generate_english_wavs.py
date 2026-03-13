#!/usr/bin/env python3
"""
Generate English WAV files from a text file using Coqui TTS and upload to the backend.
Usage:
  pip install -r requirements.txt
  export BASE_URL=http://localhost:8000   # or your API URL
  python generate_english_wavs.py sentences.txt [--no-upload]
One sentence per line in sentences.txt. With --no-upload, WAVs are written to ./output_wavs/ only.
"""
import argparse
import os
import sys
import tempfile
from pathlib import Path

# Optional: add parent so we can import from backend if needed (not required for this script)
SCRIPT_DIR = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description="Generate English WAVs from text and optionally upload")
    parser.add_argument("sentences_file", type=Path, help="Text file, one English sentence per line")
    parser.add_argument("--no-upload", action="store_true", help="Only generate WAVs to output_wavs/, do not upload")
    parser.add_argument("--base-url", default=os.environ.get("BASE_URL", "http://localhost:8000"), help="API base URL")
    parser.add_argument("--output-dir", type=Path, default=SCRIPT_DIR / "output_wavs", help="Directory for WAV files when not uploading")
    parser.add_argument("--model", default="tts_models/en/ljspeech/tacotron2-DDC", help="Coqui TTS model name")
    args = parser.parse_args()

    if not args.sentences_file.exists():
        print(f"Error: {args.sentences_file} not found", file=sys.stderr)
        sys.exit(1)

    lines = args.sentences_file.read_text(encoding="utf-8").strip().splitlines()
    sentences = [line.strip() for line in lines if line.strip()]
    if not sentences:
        print("No non-empty sentences found.", file=sys.stderr)
        sys.exit(1)

    try:
        from TTS.api import TTS
    except ImportError:
        print("Install TTS: pip install TTS", file=sys.stderr)
        sys.exit(1)

    print(f"Loading TTS model: {args.model}")
    tts = TTS(model_name=args.model, progress_bar=False, gpu=False)
    output_dir = args.output_dir
    if args.no_upload:
        output_dir.mkdir(parents=True, exist_ok=True)

    uploaded = 0
    temp_dir = Path(tempfile.gettempdir()) / "speech_parallel_tts" if not args.no_upload else None
    if temp_dir is not None:
        temp_dir.mkdir(parents=True, exist_ok=True)
    for i, text in enumerate(sentences):
        if args.no_upload:
            wav_path = output_dir / f"en_{i:04d}.wav"
        else:
            wav_path = temp_dir / f"en_{i:04d}.wav"
        print(f"[{i+1}/{len(sentences)}] {text[:50]}...")
        tts.tts_to_file(text=text, file_path=str(wav_path))

        if not args.no_upload:
            try:
                import httpx
            except ImportError:
                print("Install httpx: pip install httpx", file=sys.stderr)
                sys.exit(1)
            url = f"{args.base_url.rstrip('/')}/api/audio/english/with-text"
            with open(wav_path, "rb") as f:
                files = {"file": (wav_path.name, f, "audio/wav")}
                data = {"text_english": text}
                r = httpx.post(url, files=files, data=data, timeout=30.0)
            wav_path.unlink(missing_ok=True)
            if r.status_code != 200:
                print(f"  Upload failed: {r.status_code} {r.text}", file=sys.stderr)
            else:
                uploaded += 1
                print(f"  -> id={r.json().get('id', '')}")

    if not args.no_upload:
        print(f"Uploaded {uploaded}/{len(sentences)} items to {args.base_url}")
    else:
        print(f"Generated {len(sentences)} WAVs in {output_dir}")


if __name__ == "__main__":
    main()
