# AGENTS.md — Directives Locales (`devoirBDD`)

> **Portée :** Ce fichier complète les directives globales (`GEMINI.md`) pour le projet collaboratif PostgreSQL **Exploration Spatiale & Planétologie (3NF)** (`devoirBDD`).

---

## 1. Vue d'ensemble & Règles Propres au Dépôt

1. **Modèle relationnel PostgreSQL (3NF — 8 tables) :**
   - Les 8 tables (`profil`, `utilisateur`, `corps_celeste`, `trajectoire_orbitale`, `mission`, `instrument_scientifique`, `mission_instrument`, `echantillon`) modélisent des relations `1:N`, `M:N`, `1:1` stricte (`UNIQUE` sur `echantillon.id_mission`), l'authentification par empreinte `md5()` et un graphe orienté pondéré (double sens autorisé).
   - Respecter l'ordre d'exécution : `sql/01_schema.sql` ➔ `sql/02_seed.sql` ➔ `sql/03_queries.sql`.
   - Toute modification de table ou contrainte doit être répercutée dans [`DIAGRAMME.md`](DIAGRAMME.md), [`README.md`](README.md) et [`docs/architecture-et-modele.md`](docs/architecture-et-modele.md).
2. **Collaboration Python hybride (`uv` + `venv`) :**
   - Environnement principal géré par `uv` (`pyproject.toml` + `uv.lock`, Python 3.11+ / `.python-version` `3.12`).
   - Après toute modification de dépendance (`uv add` / `uv remove`), régénérer **`requirements.txt`** via `uv export --format requirements.txt --no-hashes --no-dev --no-emit-project -o requirements.txt` pour les collaborateurs utilisant `python -m venv` + `pip`.
   - Ne jamais versionner `.venv/`.
3. **Sécurité & Identifiants PostgreSQL :**
   - Aucun mot de passe en clair dans le code ou la documentation.
   - Lire la configuration depuis `.env` (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`), exclu par `.gitignore`, `.aiexclude` et `.geminiignore`. Maintenir `.env.example` à jour.

---

## 2. Navigation dans `.agents/`

| Ressource | Déclenchement | Rôle |
| :--- | :--- | :--- |
| [`.agents/rules/sql-postgresql.md`](.agents/rules/sql-postgresql.md) | `glob` (`**/*.sql`) | Conventions DDL/DML PostgreSQL, 3NF et synchronisation des diagrammes |
| [`.agents/rules/python-environnement.md`](.agents/rules/python-environnement.md) | `glob` (`**/*.py`, `pyproject.toml`, `requirements.txt`) | Requêtes paramétrées `psycopg`, `.env`, Ruff et sync `uv` ➔ `requirements.txt` |
| [`.agents/rules/securite-git.md`](.agents/rules/securite-git.md) | `model_decision` | Contrôle anti-secrets avant commit/push et hygiène Git |
| [`.agents/skills/deploy-et-test-bdd/`](.agents/skills/deploy-et-test-bdd/SKILL.md) | Skill à la demande | Procédure complète de déploiement et test PostgreSQL + Python |
