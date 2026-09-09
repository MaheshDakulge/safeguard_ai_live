from supabase import create_client, Client
from app.core.config import settings

_client: Client | None = None


def get_supabase_sync() -> Client:
    global _client
    if _client is None:
        if not settings.supabase_url or not settings.supabase_service_key:
            raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env")
        _client = create_client(settings.supabase_url, settings.supabase_service_key)
    return _client


# FIX: was declared `async def` but returned a sync Client directly.
# FastAPI Depends() works fine with a plain def for sync resources.
def get_supabase() -> Client:
    return get_supabase_sync()
