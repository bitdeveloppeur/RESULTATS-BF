"""Gestion du pool de connexions PostgreSQL"""
import psycopg2
from psycopg2 import pool
from config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

connection_pool = None


def init_db_pool():
    """Initialise le pool de connexions"""
    global connection_pool
    try:
        connection_pool = psycopg2.pool.SimpleConnectionPool(
            1, 10,
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        print(f"Pool BDD: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    except Exception as e:
        print(f"Erreur BDD: {e}")
        connection_pool = None


def close_db_pool():
    """Ferme le pool de connexions"""
    global connection_pool
    if connection_pool:
        connection_pool.closeall()


def get_db_connection():
    """Récupère une connexion"""
    if connection_pool:
        return connection_pool.getconn()
    return None


def release_db_connection(conn):
    """Libère une connexion"""
    if connection_pool and conn:
        connection_pool.putconn(conn)
