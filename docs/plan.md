# Plan d'action — Refonte conforme aux nouvelles consignes (8 tables, profils MD5, graphe orienté pondéré, CLI CRUD)

- [x] Mettre à jour `sql/01_schema.sql` (8 tables 3NF : profils, utilisateurs MD5, graphe orienté pondéré `trajectoire_orbitale`, types souples), `sql/02_seed.sql` et `sql/03_queries.sql` (3 états + graphe + auth MD5)
- [x] Créer `db.py` (connexion `.env` typée sans erreur Pylance + UTF-8 `TextIOWrapper`) et corriger `insertion_echantillon.py`
- [x] Développer `app.py` (CLI interactif : authentification MD5 par profil, CRUD complet 2 insertions / 1 modif / 1 suppression vérifiée, 3 états SQL, réseau orbital et plus court chemin Dijkstra)
- [x] Préparer l'accueil léger de données externes (`import_csv.py` + `data/exemple_corps_celestes.csv`) sans altérer l'architecture 3NF
- [x] Mettre à jour `DIAGRAMME.md`, `README.md`, `docs/architecture-et-modele.md`, `docs/guide-oral-et-demo.md`, `docs/role-script-python.md` et créer `docs/historique.md`
- [x] Déployer sur PostgreSQL local et valider de bout en bout (`01_schema.sql`, `02_seed.sql`, `03_queries.sql`, `app.py`, `insertion_echantillon.py`, `import_csv.py`, `ruff`, contrôle anti-secrets)
