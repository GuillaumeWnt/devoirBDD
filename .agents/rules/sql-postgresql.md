---
trigger: glob
globs: "**/*.sql"
description: Conventions PostgreSQL et normalisation 3NF du projet Exploration Spatiale (devoirBDD).
---

# Règles SQL & Modélisation PostgreSQL (3NF)

1. **Ordre des scripts dans `sql/` :**
   - `01_schema.sql` : nettoyage initial (`DROP TABLE IF EXISTS ... CASCADE` en ordre inverse des dépendances) puis création des tables et contraintes.
   - `02_seed.sql` : insertion de données cohérentes respectant les clés étrangères et l'unicité `1:1`.
   - `03_queries.sql` : requêtes de lecture uniquement (`SELECT`), sans effets de bord destructeurs.
2. **Normalisation 3NF & Contraintes :**
   - Chaque table possède une clé primaire explicite (`SERIAL PRIMARY KEY` ou clé composite `(id_mission, id_instrument)`).
   - Conserver la relation `1:1` sur `echantillon.id_mission` via `NOT NULL UNIQUE REFERENCES mission (id_mission)`.
   - Protéger les domaines métier via `CHECK` (`distance_soleil_ua > 0`, `masse_grammes > 0`) et les suppressions via `ON DELETE RESTRICT` / `ON DELETE CASCADE` adaptés.
   - Ne pas ajouter d'index superflus redondants avec les index implicites (`PRIMARY KEY`, `UNIQUE`).
3. **Cohérence documentaire :**
   - Toute évolution du schéma SQL doit être reportée dans `DIAGRAMME.md` (Mermaid ERD + dictionnaire des données) et dans le diagramme Mermaid de `README.md`.
4. **Encodage :**
   - Enregistrer tous les fichiers `.sql` en **UTF-8 sans BOM**.
