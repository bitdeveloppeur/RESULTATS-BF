#!/usr/bin/env python3
"""
RÉSULTATS-BF - Point d'entrée de l'application
Rôle : Ingénieur applicatif
"""
import socket
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import uvicorn
import os

from database import init_db_pool, close_db_pool
from routes import resultat, sante, info


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Cycle de vie de l'application"""
    print("=" * 60)
    print(" RÉSULTATS-BF")
    print(f"Hostname: {socket.gethostname()}")
    print("=" * 60)
    init_db_pool()
    yield
    close_db_pool()


# Application FastAPI
app = FastAPI(
    title="RÉSULTATS-BF",
    description="API de consultation des résultats d'examens",
    version="1.0.0",
    lifespan=lifespan
)

# Enregistrement des routes API
app.include_router(resultat.router, prefix="/api")
app.include_router(sante.router, prefix="/api")
app.include_router(info.router, prefix="/api")

# Servir les fichiers statiques (interface web)
web_dir = os.path.join(os.path.dirname(__file__), "web")
if os.path.exists(web_dir):
    app.mount("/static", StaticFiles(directory=web_dir), name="static")

@app.get("/")
async def root():
    """Page d'accueil - Interface Web"""
    web_file = os.path.join(os.path.dirname(__file__), "web", "index.html")
    if os.path.exists(web_file):
        return FileResponse(web_file)
    return {
        "service": "RÉSULTATS-BF",
        "version": "1.0.0",
        "hostname": socket.gethostname(),
        "docs": "/docs"
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3000, log_level="info")
