# Speech Parallel Data App

Speech-to-Speech parallel data collection: English audio is listed in the app; users record and submit the corresponding Swahili audio after testing playback.

## Architecture

- **Backend**: FastAPI + MongoDB (GridFS for `.wav` files)
- **Mobile**: Flutter (GetX pattern), Material 3

## Backend

### Requirements

- Python 3.10+
- MongoDB running locally (or set `MONGODB_URI`)

### Setup and run

```bash
cd backend
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS/Linux:
# source venv/bin/activate
pip install -r requirements.txt
```

Optional: create `backend/.env`:

```
MONGODB_URI=mongodb://localhost:27017
DATABASE_NAME=speech_parallel
CORS_ORIGINS=*
```

Run the API:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API docs: http://localhost:8000/docs  
- Bulk upload English .wav: `POST /api/audio/english/bulk` (multipart form, multiple files)  
- List: `GET /api/audio?page=1&limit=20`  
- Stream English: `GET /api/audio/{id}/english`  
- Submit Swahili: `POST /api/audio/{id}/swahili` (multipart file)

## Mobile app

### Requirements

- Flutter SDK

### Setup and run

```bash
cd mobile
flutter pub get
flutter run
```

**Base URL**: The app uses `http://10.0.2.2:8000` by default (Android emulator → host machine). For a **real device** (e.g. Infinix), set `kBaseUrl` in `mobile/lib/core/config/api_config.dart` to your PC’s LAN IP (e.g. `http://192.168.1.5:8000`). Run the backend with `--host 0.0.0.0` and use the same Wi‑Fi for phone and PC.

**API**: The app calls the same backend as in the docs (e.g. `GET /api/audio?page=1&limit=20`). The response `{ "items": [...], "total", "page", "limit" }` with each item `id`, `length_english`, `length_swahili`, `status` is parsed and shown in the Recordings list and Home progress.

### Flow

1. **Splash** → Dashboard  
2. **Dashboard**: Paginated list of speech items (id, length_english, status). Pull to refresh; tap “Load more” for next page. Tap an item → Detail.  
3. **Detail**: Play English → Record Swahili → Play back to verify → Submit. Submit is enabled only after playback has been tested.

## MongoDB schema (collection: `speech_parallel`)

| Field           | Type     | Description                          |
|-----------------|----------|--------------------------------------|
| `_id`           | ObjectId  | Assigned on bulk upload              |
| `audio_english` | ObjectId  | GridFS file id (English .wav)       |
| `audio_swahili` | ObjectId? | GridFS file id (Swahili .wav), null until submitted |
| `length_english`| float     | Duration in seconds                  |
| `length_swahili`| float?    | Set on submit                        |
| `status`        | string    | `"pending"` \| `"submitted"`         |

## Run backend with Docker (API + MongoDB)

From the project root:

```bash
cd backend
docker compose up --build
```

- API: http://localhost:8000 (docs: http://localhost:8000/docs)
- MongoDB: localhost:27017 (data in volume `mongo_data`)
- Stop: `Ctrl+C` then `docker compose down`

To run in the background: `docker compose up -d --build`. Point the mobile app at your machine’s IP (e.g. `http://192.168.1.5:8000`) when using a physical device.

## Optional: Docker for MongoDB only

If you run the API locally (not in Docker) but want MongoDB in Docker:

```bash
docker run -d -p 27017:27017 --name mongo-speech mongo:7
```

Then use `MONGODB_URI=mongodb://localhost:27017` (default).

## Deploy backend to Railway

Railway runs long-lived services and will build this backend with its **default builder** (no Docker required): it detects Python, installs from `requirements.txt`, and runs the `Procfile` command. Use either **Railway’s MongoDB** or **MongoDB Atlas**.

### 1. Create a project and API service

1. Go to [railway.app](https://railway.app) and sign in (e.g. with GitHub).
2. **New Project** → **Deploy from GitHub repo** (or **Empty Project** and connect the repo later).
3. If the repo is the whole project (not just `backend/`):
   - Add a **service** → **GitHub Repo** → select the repo.
   - In the new service: **Settings** → **Root Directory** → set to `backend`.
4. Railway will build the Python app and start it with the `Procfile` (`uvicorn` on `$PORT`).

### 2. MongoDB: Railway or Atlas

**Option A – MongoDB on Railway**

1. In the same project: **New** → **Database** → **Add MongoDB** (or **Plugin** → MongoDB).
2. After it’s created, open the MongoDB service → **Variables** (or **Connect**) and copy the connection URL (often `MONGO_URL` or similar).
3. In your **API service** → **Variables**: add  
   `MONGODB_URI` = that URL (e.g. `mongodb://mongo:27017` if Railway gives a private hostname, or the full URL with user/password if provided).  
   Also set:
   - `DATABASE_NAME` = `speech_parallel`
   - `CORS_ORIGINS` = `*` (or your app’s origins, e.g. `https://your-app.vercel.app` if you add a web client later).

**Option B – MongoDB Atlas**

1. Create a cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas), get the connection string.
2. In the **API service** → **Variables**:  
   `MONGODB_URI` = your Atlas connection string (e.g. `mongodb+srv://user:pass@cluster.mongodb.net/`).  
   Set `DATABASE_NAME` = `speech_parallel` and `CORS_ORIGINS` as above.

### 3. Public URL and port

1. API service → **Settings** → **Networking** → **Generate Domain** (e.g. `your-api.up.railway.app`).
2. The `Procfile` runs uvicorn with `$PORT`, so the service will listen on Railway’s assigned port.

### 4. Point the mobile app at Railway

In the Flutter app, set the **Server URL** (in-app settings or `api_config.dart`) to your Railway API URL, e.g. `https://your-api.up.railway.app`. No port needed if you use the generated HTTPS domain.

### Env vars summary (API service on Railway)

| Variable        | Required | Example / note                          |
|-----------------|----------|-----------------------------------------|
| `MONGODB_URI`   | Yes      | Railway MongoDB URL or Atlas connection string |
| `DATABASE_NAME` | No       | `speech_parallel` (default)             |
| `CORS_ORIGINS`  | No       | `*` or comma-separated origins          |

Optional: use **Railway CLI** (`railway link`, `railway up`) to deploy from the `backend` directory instead of GitHub.

**Option A – MongoDB on Railway**

1. In the same project: **New** → **Database** → **Add MongoDB** (or **Plugin** → MongoDB).
2. After it’s created, open the MongoDB service → **Variables** (or **Connect**) and copy the connection URL (often `MONGO_URL` or similar).
3. In your **API service** → **Variables**: add  
   `MONGODB_URI` = that URL (e.g. `mongodb://mongo:27017` if Railway gives a private hostname, or the full URL with user/password if provided).  
   Also set:
   - `DATABASE_NAME` = `speech_parallel`
   - `CORS_ORIGINS` = `*` (or your app’s origins, e.g. `https://your-app.vercel.app` if you add a web client later).

**Option B – MongoDB Atlas**

1. Create a cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas), get the connection string.
2. In the **API service** → **Variables**:  
   `MONGODB_URI` = your Atlas connection string (e.g. `mongodb+srv://user:pass@cluster.mongodb.net/`).  
   Set `DATABASE_NAME` = `speech_parallel` and `CORS_ORIGINS` as above.

### 3. Public URL and port

1. API service → **Settings** → **Networking** → **Generate Domain** (e.g. `your-api.up.railway.app`).
2. The `Procfile` runs uvicorn with `$PORT`, so the service will listen on Railway’s assigned port.

### 4. Point the mobile app at Railway

In the Flutter app, set the **Server URL** (in-app settings or `api_config.dart`) to your Railway API URL, e.g. `https://your-api.up.railway.app`. No port needed if you use the generated HTTPS domain.

### Env vars summary (API service on Railway)

| Variable        | Required | Example / note                          |
|-----------------|----------|-----------------------------------------|
| `MONGODB_URI`   | Yes      | Railway MongoDB URL or Atlas connection string |
| `DATABASE_NAME` | No       | `speech_parallel` (default)             |
| `CORS_ORIGINS`  | No       | `*` or comma-separated origins          |

Optional: use **Railway CLI** (`railway link`, `railway up`) to deploy from the `backend` directory instead of GitHub.
