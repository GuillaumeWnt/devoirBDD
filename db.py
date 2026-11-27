"""
PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
Fichier : db.py
Description : Utilitaires partagés pour la configuration UTF-8 sous Windows,
              le chargement sécurisé des identifiants PostgreSQL depuis .env
              et l'ouverture de connexion psycopg v3 (typage strict Pylance).
"""

import io
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import psycopg
from dotenv import load_dotenv


@dataclass(frozen=True)
class DbConfig:
    """Paramètres de connexion PostgreSQL chargés depuis le fichier .env."""

    dbname: str
    user: str
    password: str
    host: str
    port: int


def configurer_sortie_utf8() -> None:
    """Configure la console standard en UTF-8 pour les accents sous Windows."""
    for flux in (sys.stdout, sys.stderr):
        if isinstance(flux, io.TextIOWrapper):
            flux.reconfigure(encoding="utf-8", errors="replace")


def charger_config_db() -> DbConfig:
    """Charge la configuration PostgreSQL depuis le fichier .env et l'environnement."""
    env_path = Path(__file__).resolve().parent / ".env"
    load_dotenv(env_path)

    mot_de_passe = os.getenv("PGPASSWORD")
    if not mot_de_passe:
        raise RuntimeError(
            "Variable PGPASSWORD manquante. Copiez '.env.example' vers '.env' "
            "puis renseignez votre mot de passe PostgreSQL."
        )

    return DbConfig(
        dbname=os.getenv("PGDATABASE", "exploration_spatiale"),
        user=os.getenv("PGUSER", "postgres"),
        password=mot_de_passe,
        host=os.getenv("PGHOST", "localhost"),
        port=int(os.getenv("PGPORT", "5432")),
    )


def ouvrir_connexion(
    config: DbConfig | None = None,
) -> psycopg.Connection[tuple[Any, ...]]:
    """Ouvre une connexion PostgreSQL avec arguments nommés explicites."""
    cfg = config if config is not None else charger_config_db()
    return psycopg.connect(
        dbname=cfg.dbname,
        user=cfg.user,
        password=cfg.password,
        host=cfg.host,
        port=cfg.port,
    )
