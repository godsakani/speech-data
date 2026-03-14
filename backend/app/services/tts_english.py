"""Generate English WAV from text using TTS (pyttsx3). Optional dependency."""
import tempfile
from pathlib import Path


def _set_english_voice(engine) -> None:
    """Set engine to an available English voice (avoids gmw/en etc. not in minimal espeak)."""
    voices = engine.getProperty("voices") or []
    # Prefer voice ids that are standard English in espeak: en, en-us, en-gb, en-us, default
    for preferred in ("en-us", "en-gb", "en", "english", "en-us"):
        for v in voices:
            vid = (getattr(v, "id", None) or "").lower()
            if vid == preferred or vid.startswith(preferred + "/") or f"/{preferred}" in vid:
                try:
                    engine.setProperty("voice", v.id)
                    return
                except Exception:
                    continue
    # Fallback: use first voice that has 'en' in id (e.g. en-us, en-gb) but not gmw/en
    for v in voices:
        vid = (getattr(v, "id", None) or "").lower()
        if "en" in vid and "gmw" not in vid:
            try:
                engine.setProperty("voice", v.id)
                return
            except Exception:
                continue
    # Last resort: use first available voice to avoid broken default (e.g. gmw/en)
    if voices:
        try:
            engine.setProperty("voice", voices[0].id)
        except Exception:
            pass


def generate_wav_from_text(text: str) -> bytes:
    """Generate a WAV file (bytes) from English text. Raises RuntimeError if TTS unavailable."""
    text = (text or "").strip()
    if not text:
        raise ValueError("text_english is required")
    try:
        import pyttsx3
    except ImportError:
        raise RuntimeError(
            "Backend TTS not installed. Install pyttsx3 or use POST /api/audio/english/with-text with client-generated WAV."
        ) from None
    engine = pyttsx3.init()
    _set_english_voice(engine)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    try:
        engine.save_to_file(text, path)
        engine.runAndWait()
        return Path(path).read_bytes()
    finally:
        Path(path).unlink(missing_ok=True)
