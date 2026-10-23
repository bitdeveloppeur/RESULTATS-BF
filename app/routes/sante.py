"""Endpoint /sante - Health check pour HAProxy"""
import socket
from fastapi import APIRouter, status
from fastapi.responses import JSONResponse
from models import HealthStatus
from database import get_db_connection, release_db_connection

router = APIRouter()


@router.get("/sante", response_model=HealthStatus)
async def health_check():
    """Sonde de santé interrogée par HAProxy toutes les 3s"""
    conn = get_db_connection()
    hostname = socket.gethostname()
    
    if not conn:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "unhealthy", "database": "unreachable", "hostname": hostname}
        )
    
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        return HealthStatus(status="healthy", database="connected", hostname=hostname)
    except Exception:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "unhealthy", "database": "error", "hostname": hostname}
        )
    finally:
        release_db_connection(conn)
