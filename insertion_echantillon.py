"""
PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
Fichier : insertion_echantillon.py
Description : Script autonome démontrant l'insertion sécurisée paramétrée (%s)
              avec gestion de la relation 1:1 (mission <-> echantillon) via UPSERT.
"""

from db import charger_config_db, configurer_sortie_utf8, ouvrir_connexion


def main() -> None:
    """Exécute l'insertion 1:1 (UPSERT) d'un échantillon puis affiche la table."""
    configurer_sortie_utf8()
    db_config = charger_config_db()

    print("Connexion à la base de données PostgreSQL...")

    # 1. Connexion à la base de données
    with ouvrir_connexion(db_config) as conn, conn.cursor() as cur:
        print(f"[OK] Connecté avec succès à la base '{db_config.dbname}'.\n")

        # 2. Données du nouvel échantillon (attribué à la mission Artemis III, id_mission = 5)
        # En relation 1:1, chaque mission ne peut avoir qu'un seul échantillon
        nouvel_echantillon = (
            "ART-01-REG",                       # code_tube (UNIQUE)
            "Régolithe anorthositique lunaire",  # type_roche
            15.50,                              # masse_grammes
            5,                                  # id_mission (FK UNIQUE -> Artemis III)
        )

        # 3. Insertion sécurisée avec paramètres (%s) et gestion du conflit 1:1 (UPSERT sur id_mission)
        query_insert = """
            INSERT INTO echantillon (
                code_tube,
                type_roche,
                masse_grammes,
                id_mission
            )
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id_mission) DO UPDATE
                SET code_tube = EXCLUDED.code_tube,
                    type_roche = EXCLUDED.type_roche,
                    masse_grammes = EXCLUDED.masse_grammes
            RETURNING id_echantillon;
        """
        cur.execute(query_insert, nouvel_echantillon)
        row_id = cur.fetchone()
        if row_id is None:
            raise RuntimeError("Aucun identifiant retourné après l'insertion.")
        id_genere = row_id[0]
        print(
            f"[INSERT/UPDATE] Échantillon (1:1) associé à la mission #5 "
            f"avec l'identifiant #{id_genere}"
        )

        # 4. Validation explicite de la transaction
        conn.commit()
        print("[COMMIT] Transaction validée en base.\n")

        # 5. Lecture des données avec jointure pour vérifier la relation 1:1
        print("=== LISTE DES ÉCHANTILLONS EN BASE (Relation 1:1 avec les missions) ===")
        query_select = """
            SELECT
                e.id_echantillon,
                e.code_tube,
                e.type_roche,
                e.masse_grammes,
                m.nom_mission,
                c.nom AS planete_cible
            FROM echantillon e
            INNER JOIN mission m ON e.id_mission = m.id_mission
            INNER JOIN corps_celeste c ON m.id_corps = c.id_corps
            ORDER BY e.id_echantillon;
        """
        cur.execute(query_select)
        rows = cur.fetchall()

        for row in rows:
            print(
                f"ID #{row[0]:<2} | Code: {row[1]:<12} | Roche: {row[2]:<35} "
                f"| Masse: {row[3]:>5} g | Mission: {row[4]} ({row[5]})"
            )

    print("\nOpération terminée avec succès !")


if __name__ == "__main__":
    main()
