"""Generate English WAV from text using TTS (pyttsx3). Optional dependency."""
import tempfile
from pathlib import Path


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
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    try:
        engine.save_to_file(text, path)
        engine.runAndWait()
        return Path(path).read_bytes()
    finally:
        Path(path).unlink(missing_ok=True)
