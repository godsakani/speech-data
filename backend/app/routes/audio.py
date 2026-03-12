"""Audio API routes: bulk upload, list, stream, submit Swahili."""
import io
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse
from bson import ObjectId

from app.db import get_database, get_gridfs
from app.models import SpeechItemResponse, PaginatedListResponse, BulkUploadResponse, AudioStatsResponse
from app.services.audio_duration import get_wav_duration_seconds

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
            )
        )
    return PaginatedListResponse(items=items, total=total, page=page, limit=limit)


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


@router.post("/{id}/swahili")
async def submit_swahili(id: str, file: UploadFile = File(...)):
    """Upload Swahili .wav for this item; compute length, set status to submitted."""
    doc = await _get_doc(id)
    if doc.get("status") == "submitted":
        raise HTTPException(status_code=400, detail="Already submitted")
    if not file.filename or not file.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Only .wav files allowed")
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    try:
        length_swahili = get_wav_duration_seconds(data)
    except Exception:
        length_swahili = 0.0
    gridfs = get_gridfs()
    file_id = await gridfs.upload_from_stream(
        file.filename or "swahili.wav",
        io.BytesIO(data),
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
    return {"status": "submitted", "id": id}
