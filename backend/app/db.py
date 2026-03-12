"""MongoDB and GridFS connection."""
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorGridFSBucket
from app.config import settings

client: AsyncIOMotorClient | None = None
gridfs_bucket: AsyncIOMotorGridFSBucket | None = None


def get_database():
    if client is None:
        raise RuntimeError("Database client not initialized")
    return client[settings.database_name]


def get_gridfs():
    if gridfs_bucket is None:
        raise RuntimeError("GridFS bucket not initialized")
    return gridfs_bucket


async def connect_db():
    global client, gridfs_bucket
    client = AsyncIOMotorClient(settings.mongodb_uri)
    db = client[settings.database_name]
    gridfs_bucket = AsyncIOMotorGridFSBucket(db, bucket_name=settings.gridfs_bucket)


async def close_db():
    global client
    if client:
        client.close()
        client = None
