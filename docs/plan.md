# Plan d'action — Intégration des 2 CSV réels (`data/aidb-*.csv`) sans étendre le schéma

- [x] Adapter `sql/01_schema.sql` (conserver 8 tables 3NF, enrichir `corps_celeste` et `mission` avec les colonnes réelles des 2 CSV, `mission.id_corps` nullable pour les 3 missions sans cible)
- [x] Mettre à jour `import_csv.py` pour charger directement les 2 CSV réels (idempotent), générer un `sql/02_seed.sql` 100 % fidèle aux 2 CSV (zéro corps céleste ni mission inventé) et supprimer l'ancien gabarit `data/exemple_corps_celestes.csv`
- [x] Mettre à jour `sql/03_queries.sql` (3 états multi-tables adaptés aux 15 astres et 279 missions + graphe orbital + auth MD5 + stats pays)
- [x] Adapter `app.py` (recherche sur les 279 missions, CRUD aligné sur les vraies colonnes, 3 états et Dijkstra) et `insertion_echantillon.py` (UPSERT 1:1 sur la vraie mission `Chang'e 5` du CSV)
- [x] Mettre à jour `DIAGRAMME.md`, `README.md`, `docs/architecture-et-modele.md` (incluant `ON DELETE` et mots-clés SQL), `docs/guide-oral-et-demo.md`, `docs/role-script-python.md` et `docs/historique.md`
- [x] Déployer sur PostgreSQL local et valider tout le projet (`ruff`, `01_schema.sql`, `02_seed.sql`, `03_queries.sql`, `import_csv.py`, `insertion_echantillon.py`, `app.py` E2E, contrôle anti-secrets)
