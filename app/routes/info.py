"""Endpoint /info - Informations serveur"""
import socket
from fastapi import APIRouter
from app.models import InfoResponse
from app.config import DB_HOST, DB_PORT, DB_NAME

router = APIRouter()


@router.get("/info", response_model=InfoResponse)
async def info():
    """Retourne le hostname - pour tester la répartition de charge"""
    return InfoResponse(
        hostname=socket.gethostname(),
        database=f"{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
