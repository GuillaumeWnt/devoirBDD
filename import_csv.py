"""
PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
Fichier : import_csv.py
Description : Utilitaire léger et optionnel pour importer des corps célestes
              depuis un fichier CSV externe (ex. jeu de données trouvé sur Internet)
              sans altérer le schéma 3NF existant.

Utilisation :
    uv run python import_csv.py data/exemple_corps_celestes.csv --dry-run
    uv run python import_csv.py data/exemple_corps_celestes.csv
"""

import argparse
import csv
from pathlib import Path

from db import charger_config_db, configurer_sortie_utf8, ouvrir_connexion

# Correspondance entre les colonnes SQL et les en-têtes du CSV externe.
# Si votre fichier trouvé sur Internet a des colonnes en anglais (ex. name, type, distance_au),
# il suffit d'adapter les valeurs à droite ci-dessous.
COLONNES_CSV: dict[str, str] = {
    "nom": "nom",
    "type_corps": "type_corps",
    "distance_soleil_ua": "distance_soleil_ua",
}


def parser_distance(valeur_brute: str) -> float | None:
    """Convertit la distance en flottant positif, ou None si la cellule est vide."""
    texte = valeur_brute.strip().replace(",", ".")
    if not texte:
        return None
    distance = float(texte)
    if distance <= 0:
        raise ValueError(f"Distance invalide (doit être > 0) : {distance}")
    return distance


def lire_csv_corps_celestes(chemin_csv: Path) -> list[tuple[str, str, float | None]]:
    """Lit et valide les lignes d'un fichier CSV de corps célestes."""
    if not chemin_csv.is_file():
        raise FileNotFoundError(f"Fichier CSV introuvable : {chemin_csv}")

    enregistrements: list[tuple[str, str, float | None]] = []
    with chemin_csv.open("r", encoding="utf-8-sig", newline="") as fichier:
        lecteur = csv.DictReader(fichier)
        if lecteur.fieldnames is None:
            raise ValueError("Le fichier CSV ne contient pas de ligne d'en-tête.")

        colonnes_manquantes = [
            col for col in COLONNES_CSV.values() if col not in lecteur.fieldnames
        ]
        if colonnes_manquantes:
            raise ValueError(
                f"Colonnes manquantes dans {chemin_csv.name} : {colonnes_manquantes}. "
                "Adaptez le dictionnaire COLONNES_CSV dans import_csv.py."
            )

        for num_ligne, ligne in enumerate(lecteur, start=2):
            nom = ligne[COLONNES_CSV["nom"]].strip()
            type_corps = ligne[COLONNES_CSV["type_corps"]].strip()
            if not nom or not type_corps:
                print(f"[IGNORÉ] Ligne {num_ligne} incomplète (nom ou type manquant).")
                continue
            try:
                distance = parser_distance(ligne[COLONNES_CSV["distance_soleil_ua"]])
            except ValueError as err:
                print(f"[IGNORÉ] Ligne {num_ligne} ({nom}) : {err}")
                continue
            enregistrements.append((nom, type_corps, distance))

    return enregistrements


def importer_en_base(
    enregistrements: list[tuple[str, str, float | None]],
    dry_run: bool = False,
) -> None:
    """Insère les corps célestes en mode idempotent (ON CONFLICT DO NOTHING)."""
    if dry_run:
        print(f"[DRY-RUN] {len(enregistrements)} ligne(s) validée(s), aucune écriture SQL :")
        for nom, type_corps, dist in enregistrements:
            print(f"  - {nom:<20} | {type_corps:<22} | {dist} UA")
        return

    db_config = charger_config_db()
    query = """
        INSERT INTO corps_celeste (nom, type_corps, distance_soleil_ua)
        VALUES (%s, %s, %s)
        ON CONFLICT (nom) DO NOTHING;
    """
    inseres = 0
    with ouvrir_connexion(db_config) as conn, conn.cursor() as cur:
        for ligne in enregistrements:
            cur.execute(query, ligne)
            if cur.rowcount == 1:
                inseres += 1
        conn.commit()

    ignores = len(enregistrements) - inseres
    print(
        f"[OK] Import terminé dans '{db_config.dbname}' : "
        f"{inseres} ajouté(s), {ignores} déjà présent(s) ignoré(s)."
    )


def main() -> None:
    """Point d'entrée CLI de l'import CSV optionnel."""
    configurer_sortie_utf8()
    parser = argparse.ArgumentParser(
        description="Importe un fichier CSV de corps célestes dans PostgreSQL."
    )
    parser.add_argument(
        "fichier_csv",
        type=Path,
        help="Chemin vers le fichier CSV (ex. data/exemple_corps_celestes.csv)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Valide le CSV et affiche un aperçu sans modifier la base de données.",
    )
    args = parser.parse_args()

    lignes = lire_csv_corps_celestes(args.fichier_csv)
    importer_en_base(lignes, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
