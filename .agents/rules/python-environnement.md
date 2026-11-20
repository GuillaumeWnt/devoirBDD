---
trigger: glob
globs: "**/*.py, **/pyproject.toml, **/requirements.txt"
description: Règles Python psycopg, chargement .env et synchronisation uv / requirements.txt pour travail collaboratif.
---

# Règles Python & Environnement Hybride (`uv` / `venv`)

1. **Sécurité des requêtes SQL (`psycopg` v3) :**
   - Toujours utiliser des requêtes paramétrées avec `%s` et passer les valeurs en tuple/séquence à `cur.execute(query, params)`.
   - Interdiction absolue d'utiliser des f-strings ou de la concaténation de chaînes pour injecter des valeurs dans une requête SQL.
   - Gérer explicitement les conflits `1:1` (`ON CONFLICT (id_mission) DO UPDATE`) et valider les transactions (`conn.commit()`).
2. **Identifiants PostgreSQL via `.env` :**
   - Charger les variables (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`) avec `python-dotenv` depuis le fichier `.env` à la racine du projet.
   - Ne jamais écrire de mot de passe ou chaîne de connexion sensible en dur dans le code Python.
3. **Compatibilité `uv` + `venv` classique (pour collaborateurs) :**
   - En local avec `uv`, utiliser exclusivement `uv add`, `uv remove`, `uv sync` et `uv run`.
   - **Obligation de synchronisation :** après chaque `uv add`, `uv remove` ou mise à jour de `uv.lock`, régénérer `requirements.txt` sans hashes ni dépendances de dev ni chemin local :
     ```powershell
     uv export --format requirements.txt --no-hashes --no-dev --no-emit-project -o requirements.txt
     ```
   - Écrire du code compatible avec `requires-python` défini dans `pyproject.toml` (`>=3.11`).
4. **Qualité & Encodage :**
   - Vérifier les scripts avec `uv run ruff check .` avant commit.
   - Configurer UTF-8 sur `sys.stdout` / `sys.stderr` pour éviter les erreurs d'affichage sous console Windows.
