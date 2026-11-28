"""
PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
Fichier : insertion_echantillon.py
Description : Script autonome démontrant l'insertion sécurisée paramétrée (%s)
              avec gestion de la relation 1:1 (mission <-> echantillon) via UPSERT
              sur la vraie mission 'Chang'e 5' issue du CSV.
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

        # 2. Recherche de la vraie mission 'Chang'e 5' issue du CSV
        nom_mission_cible = "Chang'e 5"
        cur.execute(
            "SELECT id_mission FROM mission WHERE nom_mission = %s;",
            (nom_mission_cible,),
        )
        mission_row = cur.fetchone()
        if mission_row is None:
            raise RuntimeError(
                f"Mission '{nom_mission_cible}' introuvable. Exécutez d'abord "
                "sql/01_schema.sql et sql/02_seed.sql (ou import_csv.py)."
            )
        id_mission = int(mission_row[0])

        # 3. Données de l'échantillon lunaire réel ramené par Chang'e 5 (1731 g)
        # En relation 1:1, chaque mission ne peut avoir qu'un seul échantillon
        nouvel_echantillon = (
            "CHG-05-OCE",                                # code_tube (UNIQUE)
            "Régolithe basaltique (Océan des Tempêtes)", # type_roche
            1731.00,                                     # masse_grammes
            id_mission,                                  # id_mission (FK UNIQUE -> Chang'e 5)
        )

        # 4. Insertion sécurisée avec paramètres (%s) et gestion du conflit 1:1 (UPSERT)
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
            f"[INSERT/UPDATE] Échantillon (1:1) associé à '{nom_mission_cible}' "
            f"(mission #{id_mission}) avec l'identifiant #{id_genere}"
        )

        # 5. Validation explicite de la transaction
        conn.commit()
        print("[COMMIT] Transaction validée en base.\n")

        # 6. Lecture des données avec jointure pour vérifier la relation 1:1
        print("=== LISTE DES ÉCHANTILLONS EN BASE (Relation 1:1 avec les missions) ===")
        query_select = """
            SELECT
                e.id_echantillon,
                e.code_tube,
                e.type_roche,
                e.masse_grammes,
                m.nom_mission,
                COALESCE(c.nom, 'Non précisée') AS cible
            FROM echantillon e
            INNER JOIN mission m ON e.id_mission = m.id_mission
            LEFT JOIN corps_celeste c ON m.id_corps = c.id_corps
            ORDER BY e.id_echantillon;
        """
        cur.execute(query_select)
        rows = cur.fetchall()

        for row in rows:
            print(
                f"ID #{row[0]:<2} | Code: {row[1]:<11} | Roche: {row[2]:<43} "
                f"| Masse: {row[3]:>8} g | Mission: {row[4]} ({row[5]})"
            )

    print("\nOpération terminée avec succès !")


if __name__ == "__main__":
    main()
