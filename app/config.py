"""Configuration de l'application"""
import os

# Configuration base de données
DB_HOST = os.getenv('DB_HOST', '192.168.63.31')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'resultats_bf')
DB_USER = os.getenv('DB_USER', 'resultats_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'changeme_password')
