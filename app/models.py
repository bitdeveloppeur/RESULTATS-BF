"""Modèles de données Pydantic"""
from pydantic import BaseModel


class Resultat(BaseModel):
    """Résultat d'un candidat"""
    matricule: str
    nom: str
    serie: str
    moyenne: float
    admis: bool


class HealthStatus(BaseModel):
    """Statut de santé du service"""
    status: str
    database: str
    hostname: str


class InfoResponse(BaseModel):
    """Informations serveur"""
    hostname: str
    database: str
