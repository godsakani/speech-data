"""Pydantic models for API request/response."""
from pydantic import BaseModel, Field
from typing import Optional


class SpeechItemResponse(BaseModel):
    id: str
    length_english: float
    length_swahili: Optional[float] = None
    status: str  # "pending" | "submitted"
    text_english: Optional[str] = None  # source sentence (null for legacy bulk-upload)


class PaginatedListResponse(BaseModel):
    items: list[SpeechItemResponse]
    total: int
    page: int
    limit: int


class BulkUploadResponse(BaseModel):
    created_ids: list[str] = Field(description="List of created document _ids")


class AudioStatsResponse(BaseModel):
    total: int
    submitted: int
    pending: int
