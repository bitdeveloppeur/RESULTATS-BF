"""Endpoint /resultat"""
from fastapi import APIRouter, HTTPException, Query, status
from app.models import Resultat
from app.database import get_db_connection, release_db_connection

router = APIRouter()


@router.get("/resultat", response_model=Resultat)
async def get_resultat(matricule: str = Query(..., description="Matricule du candidat")):
    """Consulte le résultat d'un candidat"""
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Base inaccessible")
    
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT matricule, nom, serie, moyenne, admis FROM resultats WHERE matricule = %s",
            (matricule,)
        )
        result = cursor.fetchone()
        cursor.close()
        
        if not result:
            raise HTTPException(status.HTTP_404_NOT_FOUND, f"Matricule {matricule} introuvable")
        
        return Resultat(
            matricule=result[0],
            nom=result[1],
            serie=result[2],
            moyenne=float(result[3]),
            admis=result[4]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, str(e))
    finally:
        release_db_connection(conn)
