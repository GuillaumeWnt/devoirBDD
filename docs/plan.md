# Plan d'action — Création et mise en ligne de devoirBDD

- [x] Initialiser le dépôt `devoirBDD` avec `uv` et Git (branche `main`) à `C:\Users\guill\dev\M1\devoirBDD`
- [x] Copier et adapter les fichiers SQL et documentation depuis `exploration_spatiale` (`sql/`, `DIAGRAMME.md`, `README.md`)
- [x] Adapter `insertion_echantillon.py` avec chargement sécurisé `.env` et ajouter `.env.example`, `.gitignore`, `.aiexclude` et `.geminiignore`
- [x] Configurer les dépendances `uv` (`psycopg[binary]`, `python-dotenv`, dev `ruff`) et exporter `requirements.txt` pour le mode `venv`
- [x] Créer `AGENTS.md`, les règles/skills dans `.agents/`, ainsi que `docs/environnement-python.md`
- [x] Valider l'exécution complète (`ruff`, déploiement PostgreSQL local, `03_queries.sql` et `insertion_echantillon.py` via `uv` et `venv`)
- [x] Vérifier l'absence de secrets suivis par Git, commiter et pousser sur `git@github.com:GuillaumeWnt/devoirBDD.git`
