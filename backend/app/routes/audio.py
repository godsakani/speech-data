"""Audio API routes: bulk upload, list, stream, submit Swahili."""
import asyncio
import io
import json
import zipfile
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import StreamingResponse
from bson import ObjectId

from app.db import get_database, get_gridfs
from app.models import SpeechItemResponse, PaginatedListResponse, BulkUploadResponse, AudioStatsResponse
from app.services.audio_duration import get_wav_duration_seconds
from app.services.tts_english import generate_wav_from_text

router = APIRouter(prefix="/api/audio", tags=["audio"])
COLLECTION = "speech_parallel"


def _serialize_id(oid: ObjectId) -> str:
    return str(oid)


async def _get_doc(id: str):
    db = get_database()
    try:
        oid = ObjectId(id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid id")
    doc = await db[COLLECTION].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="Not found")
    return doc


@router.get("/stats", response_model=AudioStatsResponse)
async def audio_stats():
    """Return total, submitted, and pending counts for progress."""
    db = get_database()
    total = await db[COLLECTION].count_documents({})
    submitted = await db[COLLECTION].count_documents({"status": "submitted"})
    pending = total - submitted
    return AudioStatsResponse(total=total, submitted=submitted, pending=pending)


@router.post("/english/bulk", response_model=BulkUploadResponse)
async def bulk_upload_english(files: list[UploadFile] = File(...)):
    """Upload multiple English .wav files; store in GridFS, compute length, create docs."""
    db = get_database()
    gridfs = get_gridfs()
    created_ids = []
    for f in files:
        if not f.filename or not f.filename.lower().endswith(".wav"):
            continue
        data = await f.read()
        if not data:
            continue
        try:
            length_english = get_wav_duration_seconds(data)
        except Exception:
            length_english = 0.0
        file_id = await gridfs.upload_from_stream(
            f.filename or "audio.wav",
            io.BytesIO(data),
            metadata={"language": "english"},
        )
        doc = {
            "audio_english": file_id,
            "audio_swahili": None,
            "length_english": length_english,
            "length_swahili": None,
            "status": "pending",
        }
        result = await db[COLLECTION].insert_one(doc)
        created_ids.append(_serialize_id(result.inserted_id))
    return BulkUploadResponse(created_ids=created_ids)


@router.post("/english/with-text", response_model=dict)
async def create_english_with_text(
    file: UploadFile = File(...),
    text_english: str = Form(""),
):
    """Create one item: upload English WAV + optional source text. Used by script and client upload."""
    if not file.filename or not file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Only .wav files allowed")
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    try:
        length_english = get_wav_duration_seconds(data)
    except Exception:
        length_english = 0.0
    db = get_database()
    gridfs = get_gridfs()
    file_id = await gridfs.upload_from_stream(
        file.filename or "audio.wav",
        io.BytesIO(data),
        metadata={"language": "english"},
    )
    doc = {
        "audio_english": file_id,
        "audio_swahili": None,
        "length_english": length_english,
        "length_swahili": None,
        "status": "pending",
        "text_english": text_english.strip() or None,
    }
    result = await db[COLLECTION].insert_one(doc)
    return {"id": _serialize_id(result.inserted_id)}


@router.post("/english/speak", response_model=dict)
async def create_english_speak(text_english: str = Form(..., min_length=1)):
    """Create one item from English text: backend TTS generates WAV, stores text + audio. Requires pyttsx3."""
    text_english = text_english.strip()
    if not text_english:
        raise HTTPException(status_code=400, detail="text_english is required")
    try:
        wav_data = await asyncio.to_thread(generate_wav_from_text, text_english)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    try:
        length_english = get_wav_duration_seconds(wav_data)
    except Exception:
        length_english = 0.0
    db = get_database()
    gridfs = get_gridfs()
    file_id = await gridfs.upload_from_stream(
        "english.wav",
        io.BytesIO(wav_data),
        metadata={"language": "english"},
    )
    doc = {
        "audio_english": file_id,
        "audio_swahili": None,
        "length_english": length_english,
        "length_swahili": None,
        "status": "pending",
        "text_english": text_english,
    }
    result = await db[COLLECTION].insert_one(doc)
    return {"id": _serialize_id(result.inserted_id)}


@router.get("", response_model=PaginatedListResponse)
async def list_audio(page: int = 1, limit: int = 20):
    """Paginated list of speech items."""
    if page < 1:
        page = 1
    if limit < 1 or limit > 100:
        limit = 20
    db = get_database()
    skip = (page - 1) * limit
    total = await db[COLLECTION].count_documents({})
    cursor = db[COLLECTION].find({}).skip(skip).limit(limit).sort("_id", 1)
    items = []
    async for doc in cursor:
        items.append(
            SpeechItemResponse(
                id=_serialize_id(doc["_id"]),
                length_english=doc.get("length_english", 0),
                length_swahili=doc.get("length_swahili"),
                status=doc.get("status", "pending"),
                text_english=doc.get("text_english"),
            )
        )
    return PaginatedListResponse(items=items, total=total, page=page, limit=limit)


EXPORT_MAX_LIMIT = 500


@router.get("/export")
async def export_dataset(limit: int = 500):
    """Export dataset as ZIP: English/Swahili WAVs + metadata.json. Optional ?limit= (max 500)."""
    if limit < 1 or limit > EXPORT_MAX_LIMIT:
        limit = EXPORT_MAX_LIMIT
    db = get_database()
    gridfs = get_gridfs()
    cursor = db[COLLECTION].find({}).sort("_id", 1).limit(limit)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        metadata_list: list[dict] = []
        async for doc in cursor:
            id_str = _serialize_id(doc["_id"])
            length_english = doc.get("length_english")
            length_swahili = doc.get("length_swahili")
            text_english = doc.get("text_english")
            status = doc.get("status", "pending")
            has_swahili = bool(doc.get("audio_swahili"))

            # English WAV
            try:
                grid_out = await gridfs.open_download_stream(doc["audio_english"])
                en_data = await grid_out.read()
                zf.writestr(f"{id_str}_english.wav", en_data)
            except Exception:
                pass
            # Swahili WAV when submitted
            if has_swahili:
                try:
                    grid_out = await gridfs.open_download_stream(doc["audio_swahili"])
                    sw_data = await grid_out.read()
                    zf.writestr(f"{id_str}_swahili.wav", sw_data)
                except Exception:
                    has_swahili = False
            metadata_list.append({
                "id": id_str,
                "length_english": length_english,
                "length_swahili": length_swahili,
                "text_english": text_english or "",
                "status": status,
                "has_english_audio": True,
                "has_swahili_audio": has_swahili,
            })
        zf.writestr("metadata.json", json.dumps(metadata_list, indent=2))
    buffer.seek(0)
    return StreamingResponse(
        buffer,
        media_type="application/zip",
        headers={"Content-Disposition": 'attachment; filename="speech_export.zip"'},
    )


@router.get("/{id}/english")
async def stream_english(id: str):
    """Stream English .wav from GridFS for playback."""
    doc = await _get_doc(id)
    gridfs = get_gridfs()
    file_id = doc.get("audio_english")
    if not file_id:
        raise HTTPException(status_code=404, detail="English audio not found")
    try:
        grid_out = await gridfs.open_download_stream(file_id)
        data = await grid_out.read()
    except Exception:
        raise HTTPException(status_code=404, detail="Audio file not found")
    return StreamingResponse(
        io.BytesIO(data),
        media_type="audio/wav",
        headers={"Content-Disposition": "inline; filename=english.wav"},
    )


@router.get("/{id}/swahili")
async def stream_swahili(id: str):
    """Stream submitted Swahili .wav from GridFS for playback."""
    doc = await _get_doc(id)
    gridfs = get_gridfs()
    file_id = doc.get("audio_swahili")
    if not file_id:
        raise HTTPException(status_code=404, detail="Swahili audio not found (not submitted yet)")
    try:
        grid_out = await gridfs.open_download_stream(file_id)
        data = await grid_out.read()
    except Exception:
        raise HTTPException(status_code=404, detail="Audio file not found")
    return StreamingResponse(
        io.BytesIO(data),
        media_type="audio/wav",
        headers={"Content-Disposition": "inline; filename=swahili.wav"},
    )


async def _save_swahili_for_doc(doc: dict, file_data: bytes, filename: str) -> dict:
    """Upload Swahili bytes to GridFS and return update payload."""
    try:
        length_swahili = get_wav_duration_seconds(file_data)
    except Exception:
        length_swahili = 0.0
    gridfs = get_gridfs()
    file_id = await gridfs.upload_from_stream(
        filename or "swahili.wav",
        io.BytesIO(file_data),
        metadata={"language": "swahili"},
    )
    db = get_database()
    await db[COLLECTION].update_one(
        {"_id": doc["_id"]},
        {
            "$set": {
                "audio_swahili": file_id,
                "length_swahili": length_swahili,
                "status": "submitted",
            }
        },
    )
    return {"status": "submitted", "id": str(doc["_id"])}


@router.put("/{id}/swahili")
async def replace_swahili(id: str, file: UploadFile = File(...)):
    """Replace existing Swahili .wav for this item (full overwrite). Use for resubmit."""
    doc = await _get_doc(id)
    if not file.filename or not file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Only .wav files allowed")
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    return await _save_swahili_for_doc(doc, data, file.filename or "swahili.wav")


@router.post("/{id}/swahili")
async def submit_swahili(id: str, file: UploadFile = File(...)):
    """Upload Swahili .wav for this item (first-time submit). Returns 400 if already submitted."""
    doc = await _get_doc(id)
    if doc.get("status") == "submitted":
        raise HTTPException(status_code=400, detail="Already submitted. Use PUT /api/audio/{id}/swahili to replace.")
    if not file.filename or not file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Only .wav files allowed")
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    return await _save_swahili_for_doc(doc, data, file.filename or "swahili.wav")
