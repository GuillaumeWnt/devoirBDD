---
name: deploy-et-test-bdd
description: >-
  Déploie la base PostgreSQL exploration_spatiale (8 tables 3NF), exécute les scripts SQL
  (schéma, jeu d'essai, requêtes) et valide app.py, insertion_echantillon.py et import_csv.py.
  Utiliser lors d'une mise en place locale, d'un reset complet ou d'une vérification BDD.
---

# Déploiement et Validation de la Base `exploration_spatiale`

Suivre ces étapes dans l'ordre pour initialiser, peupler et tester le projet sur PostgreSQL local.

## 1. Vérifier la configuration `.env`

1. S'assurer que `.env` existe à la racine (sinon le copier depuis `.env.example` et renseigner `PGPASSWORD`).
2. Ne jamais afficher le contenu brut de `.env` dans le terminal ou les journaux.

## 2. Déployer le schéma et les données SQL

Sous PowerShell (avec `psql` dans le `PATH` ou chemin complet PostgreSQL, par exemple `C:\Program Files\PostgreSQL\17\bin\psql.exe`) :

1. Créer la base si elle n'existe pas encore :
   ```powershell
   psql -h localhost -U postgres -c "CREATE DATABASE exploration_spatiale;"
   ```
2. Exécuter le schéma DDL puis les données initiales :
   ```powershell
   psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/01_schema.sql
   psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/02_seed.sql
   ```
3. Exécuter les 3 requêtes de vérification :
   ```powershell
   psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/03_queries.sql
   ```

## 3. Valider les scripts Python et le linter

1. Avec `uv` :
   ```powershell
   uv sync
   uv run ruff check .
   uv run python import_csv.py --dry-run
   uv run python app.py
   uv run python insertion_echantillon.py
   ```
2. Avec un `venv` classique (collaborateur sans `uv`) :
   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   python app.py
   ```

## 4. Critères de réussite

- `01_schema.sql` (8 tables), `02_seed.sql` (15 corps célestes, 279 missions réelles) et `03_queries.sql` (6 requêtes) s'exécutent sans erreur SQL.
- `uv run ruff check .` retourne 0 erreur.
- `import_csv.py --dry-run` valide les 15 corps célestes et 279 missions des 2 CSV de `data/`.
- `app.py` authentifie les 3 profils via `md5(%s)`, contrôle les droits, exécute CRUD + vérifications, les 3 états et Dijkstra.
- `insertion_echantillon.py` effectue l'UPSERT `1:1` sur `Chang'e 5` (`CHG-05-OCE`) et affiche les 6 échantillons.
