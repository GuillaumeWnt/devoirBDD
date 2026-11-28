"""
PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
Fichier : import_csv.py
Description : Chargeur officiel et idempotent des 2 jeux de données réels :
              - data/aidb-solar-system-planets.csv (planètes & données physiques)
              - data/aidb-lunar-and-planetary-missions.csv (279 missions réelles)
              Permet aussi de régénérer sql/02_seed.sql à l'identique (--generate-seed)
              afin que les scripts SQL restent 100 % autonomes dans psql/pgAdmin.

Utilisation :
    uv run python import_csv.py --dry-run
    uv run python import_csv.py
    uv run python import_csv.py --generate-seed
"""

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

from db import charger_config_db, configurer_sortie_utf8, ouvrir_connexion

DOSSIER_DATA = Path(__file__).resolve().parent / "data"
CSV_PLANETES_DEFAUT = DOSSIER_DATA / "aidb-solar-system-planets.csv"
CSV_MISSIONS_DEFAUT = DOSSIER_DATA / "aidb-lunar-and-planetary-missions.csv"
SEED_SQL_DEFAUT = Path(__file__).resolve().parent / "sql" / "02_seed.sql"

# Normalisation minimale des cibles du CSV des missions pour éviter les doublons
# (ex. les missions en orbite terrestre sont rattachées au corps céleste 'Earth').
ALIASES_CIBLES: dict[str, str] = {
    "Earth / near-Earth space": "Earth",
}

# Classe par défaut pour les cibles présentes dans missions.csv mais absentes de planets.csv
# (catégories factuelles sans inventer de mesures physiques).
CLASSES_CIBLES_COMPLEMENTAIRES: dict[str, str] = {
    "Moon": "Moon",
    "Titan": "Moon",
    "Ganymede": "Moon",
    "Sun": "Star",
    "Asteroid": "Small body",
    "Comet": "Small body",
}


@dataclass(frozen=True)
class CorpsCelesteRow:
    """Ligne normalisée prête à être insérée dans corps_celeste."""

    nom: str
    code_wikidata: str | None
    type_corps: str
    distance_soleil_ua: float | None
    diametre_km: float | None
    masse_kg: float | None
    gravite_m_s2: float | None
    vitesse_liberation_km_s: float | None
    periode_orbitale_jours: float | None
    temperature_moyenne_c: float | None
    nb_lunes: int | None
    a_des_anneaux: bool | None
    champ_magnetique: bool | None
    date_decouverte: str | None


@dataclass(frozen=True)
class MissionRow:
    """Ligne normalisée prête à être insérée dans mission."""

    nom_mission: str
    date_lancement: str | None
    pays_operateur: str
    type_mission: str
    tentative: bool
    echec_lancement: bool
    lanceur: str | None
    masse_kg: float | None
    nom_corps_cible: str | None


def _parse_float(valeur: str) -> float | None:
    texte = valeur.strip().replace(",", ".")
    return float(texte) if texte else None


def _parse_int(valeur: str) -> int | None:
    texte = valeur.strip()
    return int(texte) if texte else None


def _parse_bool(valeur: str) -> bool | None:
    texte = valeur.strip().lower()
    if texte == "true":
        return True
    if texte == "false":
        return False
    return None


def _parse_str(valeur: str) -> str | None:
    texte = valeur.strip()
    return texte if texte else None


def charger_corps_depuis_planetes(chemin_csv: Path) -> list[CorpsCelesteRow]:
    """Lit les planètes et leurs propriétés physiques depuis aidb-solar-system-planets.csv."""
    if not chemin_csv.is_file():
        raise FileNotFoundError(f"Fichier CSV introuvable : {chemin_csv}")

    corps: list[CorpsCelesteRow] = []
    with chemin_csv.open("r", encoding="utf-8-sig", newline="") as fichier:
        for ligne in csv.DictReader(fichier):
            corps.append(
                CorpsCelesteRow(
                    nom=ligne["name"].strip(),
                    code_wikidata=_parse_str(ligne["wikidata"]),
                    type_corps=ligne["body_class"].strip(),
                    distance_soleil_ua=_parse_float(ligne["semi_major_axis_au"]),
                    diametre_km=_parse_float(ligne["diameter_km"]),
                    masse_kg=_parse_float(ligne["mass_kg"]),
                    gravite_m_s2=_parse_float(ligne["gravity_m_s2"]),
                    vitesse_liberation_km_s=_parse_float(ligne["escape_velocity_km_s"]),
                    periode_orbitale_jours=_parse_float(ligne["orbital_period_days"]),
                    temperature_moyenne_c=_parse_float(ligne["mean_temperature_c"]),
                    nb_lunes=_parse_int(ligne["moons"]),
                    a_des_anneaux=_parse_bool(ligne["has_rings"]),
                    champ_magnetique=_parse_bool(ligne["global_magnetic_field"]),
                    date_decouverte=_parse_str(ligne["discovery_date"]),
                )
            )
    return corps


def charger_missions_et_cibles(
    chemin_csv: Path,
    noms_corps_connus: set[str],
) -> tuple[list[CorpsCelesteRow], list[MissionRow]]:
    """Lit les 279 missions et extrait les cibles non-planétaires réelles du CSV."""
    if not chemin_csv.is_file():
        raise FileNotFoundError(f"Fichier CSV introuvable : {chemin_csv}")

    cibles_supplementaires: list[CorpsCelesteRow] = []
    cibles_ajoutees: set[str] = set()
    missions: list[MissionRow] = []

    with chemin_csv.open("r", encoding="utf-8-sig", newline="") as fichier:
        for ligne in csv.DictReader(fichier):
            cible_brute = ligne["target"].strip()
            cible_norm: str | None = None
            if cible_brute:
                cible_norm = ALIASES_CIBLES.get(cible_brute, cible_brute)
                if cible_norm not in noms_corps_connus and cible_norm not in cibles_ajoutees:
                    cibles_ajoutees.add(cible_norm)
                    cibles_supplementaires.append(
                        CorpsCelesteRow(
                            nom=cible_norm,
                            code_wikidata=None,
                            type_corps=CLASSES_CIBLES_COMPLEMENTAIRES.get(
                                cible_norm, "Celestial target"
                            ),
                            distance_soleil_ua=None,
                            diametre_km=None,
                            masse_kg=None,
                            gravite_m_s2=None,
                            vitesse_liberation_km_s=None,
                            periode_orbitale_jours=None,
                            temperature_moyenne_c=None,
                            nb_lunes=None,
                            a_des_anneaux=None,
                            champ_magnetique=None,
                            date_decouverte=None,
                        )
                    )

            missions.append(
                MissionRow(
                    nom_mission=ligne["mission"].strip(),
                    date_lancement=_parse_str(ligne["launch_date"]),
                    pays_operateur=ligne["country"].strip(),
                    type_mission=ligne["mission_type"].strip(),
                    tentative=bool(_parse_bool(ligne["attempted"])),
                    echec_lancement=bool(_parse_bool(ligne["launch_failure"])),
                    lanceur=_parse_str(ligne["launch_vehicle"]),
                    masse_kg=_parse_float(ligne["mass_kg"]),
                    nom_corps_cible=cible_norm,
                )
            )

    return cibles_supplementaires, missions


def importer_en_base(
    corps: list[CorpsCelesteRow],
    missions: list[MissionRow],
    dry_run: bool = False,
) -> None:
    """Importe/met à jour corps_celeste et mission en mode idempotent (priorité aux CSV)."""
    if dry_run:
        print(
            f"[DRY-RUN] Validation réussie : {len(corps)} corps célestes "
            f"et {len(missions)} missions prêts à importer."
        )
        sans_cible = [m.nom_mission for m in missions if m.nom_corps_cible is None]
        print(f"  - Missions sans cible planétaire (id_corps = NULL) : {sans_cible}")
        return

    db_config = charger_config_db()
    sql_corps = """
        INSERT INTO corps_celeste (
            nom, code_wikidata, type_corps, distance_soleil_ua, diametre_km,
            masse_kg, gravite_m_s2, vitesse_liberation_km_s, periode_orbitale_jours,
            temperature_moyenne_c, nb_lunes, a_des_anneaux, champ_magnetique,
            date_decouverte
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (nom) DO UPDATE
            SET code_wikidata = EXCLUDED.code_wikidata,
                type_corps = EXCLUDED.type_corps,
                distance_soleil_ua = EXCLUDED.distance_soleil_ua,
                diametre_km = EXCLUDED.diametre_km,
                masse_kg = EXCLUDED.masse_kg,
                gravite_m_s2 = EXCLUDED.gravite_m_s2,
                vitesse_liberation_km_s = EXCLUDED.vitesse_liberation_km_s,
                periode_orbitale_jours = EXCLUDED.periode_orbitale_jours,
                temperature_moyenne_c = EXCLUDED.temperature_moyenne_c,
                nb_lunes = EXCLUDED.nb_lunes,
                a_des_anneaux = EXCLUDED.a_des_anneaux,
                champ_magnetique = EXCLUDED.champ_magnetique,
                date_decouverte = EXCLUDED.date_decouverte;
    """
    sql_mission = """
        INSERT INTO mission (
            nom_mission, date_lancement, pays_operateur, type_mission,
            tentative, echec_lancement, lanceur, masse_kg, id_corps
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (nom_mission) DO UPDATE
            SET date_lancement = EXCLUDED.date_lancement,
                pays_operateur = EXCLUDED.pays_operateur,
                type_mission = EXCLUDED.type_mission,
                tentative = EXCLUDED.tentative,
                echec_lancement = EXCLUDED.echec_lancement,
                lanceur = EXCLUDED.lanceur,
                masse_kg = EXCLUDED.masse_kg,
                id_corps = EXCLUDED.id_corps;
    """

    with ouvrir_connexion(db_config) as conn, conn.cursor() as cur:
        for c in corps:
            cur.execute(
                sql_corps,
                (
                    c.nom,
                    c.code_wikidata,
                    c.type_corps,
                    c.distance_soleil_ua,
                    c.diametre_km,
                    c.masse_kg,
                    c.gravite_m_s2,
                    c.vitesse_liberation_km_s,
                    c.periode_orbitale_jours,
                    c.temperature_moyenne_c,
                    c.nb_lunes,
                    c.a_des_anneaux,
                    c.champ_magnetique,
                    c.date_decouverte,
                ),
            )

        cur.execute("SELECT nom, id_corps FROM corps_celeste;")
        ids_par_nom = {str(row[0]): int(row[1]) for row in cur.fetchall()}

        for m in missions:
            id_corps = ids_par_nom[m.nom_corps_cible] if m.nom_corps_cible else None
            cur.execute(
                sql_mission,
                (
                    m.nom_mission,
                    m.date_lancement,
                    m.pays_operateur,
                    m.type_mission,
                    m.tentative,
                    m.echec_lancement,
                    m.lanceur,
                    m.masse_kg,
                    id_corps,
                ),
            )
        conn.commit()

    print(
        f"[OK] Synchronisation terminée dans '{db_config.dbname}' : "
        f"{len(corps)} corps célestes et {len(missions)} missions (priorité aux CSV)."
    )


def _sql_lit(valeur: str | float | bool | None) -> str:
    """Formate proprement un littéral SQL PostgreSQL."""
    if valeur is None:
        return "NULL"
    if isinstance(valeur, bool):
        return "TRUE" if valeur else "FALSE"
    if isinstance(valeur, (int, float)):
        return str(valeur)
    echappe = valeur.replace("'", "''")
    return f"'{echappe}'"


def generer_seed_sql(
    corps: list[CorpsCelesteRow],
    missions: list[MissionRow],
    chemin_sortie: Path,
) -> None:
    """Génère sql/02_seed.sql à partir des 2 CSV réels + tables complémentaires."""
    lignes: list[str] = [
        "-- ====================================================================",
        "-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)",
        "-- Fichier : 02_seed.sql",
        "-- Description : Jeu de données généré fidèlement depuis les 2 CSV de data/",
        "--   - corps_celeste : 9 planètes (aidb-solar-system-planets.csv) +",
        "--     6 cibles réelles issues de aidb-lunar-and-planetary-missions.csv",
        "--   - mission : les 279 vraies missions du CSV (aucune mission inventée)",
        "--   - Tables absentes des CSV (consignes du cours) : profil, utilisateur",
        "--     (md5), trajectoire_orbitale (graphe), instrument_scientifique,",
        "--     mission_instrument (M:N) et echantillon (1:1 sur missions réelles)",
        "-- Régénération : uv run python import_csv.py --generate-seed",
        "-- ====================================================================",
        "",
        "-- 1. profil",
        "INSERT INTO profil (nom_profil, peut_ecrire, peut_supprimer, description) VALUES",
        "('administrateur', TRUE,  TRUE,  'Accès complet : consultation, saisie, modification et suppression'),",
        "('scientifique',   TRUE,  FALSE, 'Consultation, saisie et modification des données scientifiques'),",
        "('observateur',    FALSE, FALSE, 'Consultation seule des états et du réseau orbital');",
        "",
        "-- 2. utilisateur (mots de passe jamais en clair : empreinte md5())",
        "INSERT INTO utilisateur (username, nom_complet, password_hash, id_profil) VALUES",
        "('tlenfant', 'Thomas Lenfant',         md5('password'),   1),",
        "('admin',    'Administrateur Mission', md5('admin123'),   1),",
        "('s.curie',  'Sophie Curie',           md5('science123'), 2),",
        "('invite',   'Observateur Public',     md5('invite123'),  3);",
        "",
        "-- 3. corps_celeste (100 % issu des 2 CSV de data/ : 9 planètes + 6 cibles)",
        "INSERT INTO corps_celeste (",
        "    nom, code_wikidata, type_corps, distance_soleil_ua, diametre_km,",
        "    masse_kg, gravite_m_s2, vitesse_liberation_km_s, periode_orbitale_jours,",
        "    temperature_moyenne_c, nb_lunes, a_des_anneaux, champ_magnetique,",
        "    date_decouverte",
        ") VALUES",
    ]

    valeurs_corps: list[str] = []
    for c in corps:
        valeurs_corps.append(
            "("
            + ", ".join(
                [
                    _sql_lit(c.nom),
                    _sql_lit(c.code_wikidata),
                    _sql_lit(c.type_corps),
                    _sql_lit(c.distance_soleil_ua),
                    _sql_lit(c.diametre_km),
                    _sql_lit(c.masse_kg),
                    _sql_lit(c.gravite_m_s2),
                    _sql_lit(c.vitesse_liberation_km_s),
                    _sql_lit(c.periode_orbitale_jours),
                    _sql_lit(c.temperature_moyenne_c),
                    _sql_lit(c.nb_lunes),
                    _sql_lit(c.a_des_anneaux),
                    _sql_lit(c.champ_magnetique),
                    _sql_lit(c.date_decouverte),
                ]
            )
            + ")"
        )
    lignes.append(",\n".join(valeurs_corps) + ";")
    lignes.append("")

    # Table 4 : trajectoire_orbitale (sommets exclusivement issus des 15 corps des CSV)
    lignes.extend(
        [
            "-- 4. trajectoire_orbitale (graphe orienté et pondéré, double sens autorisé)",
            "-- Tous les sommets proviennent exclusivement des corps célestes des 2 CSV.",
            "INSERT INTO trajectoire_orbitale (",
            "    id_corps_depart, id_corps_arrivee, delta_v_ms, duree_jours, type_transfert",
            ")",
            "SELECT cd.id_corps, ca.id_corps, v.delta_v_ms, v.duree_jours, v.type_transfert",
            "FROM (VALUES",
            "    -- Double sens asymétrique Earth <-> Moon",
            "    ('Earth',    'Moon',     13200.00,    3.0, 'Injection translunaire et alunissage'),",
            "    ('Moon',     'Earth',     2800.00,    3.0, 'Retour balistique avec aérofreinage'),",
            "    -- Double sens asymétrique Earth <-> Mars",
            "    ('Earth',    'Mars',     13600.00,  210.0, 'Transfert de Hohmann aller'),",
            "    ('Mars',     'Earth',     6300.00,  210.0, 'Retour martien avec aérofreinage'),",
            "    -- Double sens asymétrique Earth <-> Venus",
            "    ('Earth',    'Venus',    12800.00,  146.0, 'Transfert de Hohmann vers Vénus'),",
            "    ('Venus',    'Earth',    10500.00,  146.0, 'Retour vénusien avec aérofreinage'),",
            "    -- Double sens asymétrique Saturn <-> Titan",
            "    ('Saturn',   'Titan',     1800.00,   16.0, 'Insertion orbitale saturnienne vers Titan'),",
            "    ('Titan',    'Saturn',    2100.00,   16.0, 'Remontée orbitale de Titan vers Saturne'),",
            "    -- Liaisons orientées stratégiques (optimisation multi-critères Dijkstra)",
            "    ('Moon',     'Mars',      4800.00,  215.0, 'Transfert interplanétaire depuis orbite lunaire'),",
            "    ('Venus',    'Mercury',   5100.00,  105.0, 'Assistance gravitationnelle vénusienne'),",
            "    ('Earth',    'Jupiter',  16500.00, 1800.0, 'Transfert direct vers système jovien'),",
            "    ('Mars',     'Jupiter',   5200.00,  950.0, 'Assistance gravitationnelle martienne'),",
            "    ('Jupiter',  'Ganymede',  2600.00,    7.0, 'Capture orbitale autour de Ganymède'),",
            "    ('Jupiter',  'Saturn',    4200.00, 1100.0, 'Assistance gravitationnelle jovienne'),",
            "    ('Saturn',   'Uranus',    3900.00, 1800.0, 'Transfert système externe vers Uranus'),",
            "    ('Uranus',   'Neptune',   3200.00, 1500.0, 'Transfert système externe vers Neptune'),",
            "    ('Jupiter',  'Pluto',     5800.00, 2900.0, 'Trajectoire hyperbolique type New Horizons'),",
            "    ('Earth',    'Asteroid', 12900.00,  450.0, 'Rendez-vous géocroiseur (Bennu / Ryugu)'),",
            "    ('Earth',    'Comet',    14100.00, 3650.0, 'Assistance gravitationnelle cométaire')",
            ") AS v(depart, arrivee, delta_v_ms, duree_jours, type_transfert)",
            "INNER JOIN corps_celeste cd ON cd.nom = v.depart",
            "INNER JOIN corps_celeste ca ON ca.nom = v.arrivee;",
            "",
            "-- 5. mission (100 % issu de data/aidb-lunar-and-planetary-missions.csv : 279 missions)",
            "INSERT INTO mission (",
            "    nom_mission, date_lancement, pays_operateur, type_mission,",
            "    tentative, echec_lancement, lanceur, masse_kg, id_corps",
            ")",
            "SELECT",
            "    v.nom_mission, v.date_lancement::DATE, v.pays_operateur, v.type_mission,",
            "    v.tentative, v.echec_lancement, v.lanceur, v.masse_kg, c.id_corps",
            "FROM (VALUES",
        ]
    )

    valeurs_missions: list[str] = []
    for m in missions:
        valeurs_missions.append(
            "    ("
            + ", ".join(
                [
                    _sql_lit(m.nom_mission),
                    _sql_lit(m.date_lancement),
                    _sql_lit(m.pays_operateur),
                    _sql_lit(m.type_mission),
                    _sql_lit(m.tentative),
                    _sql_lit(m.echec_lancement),
                    _sql_lit(m.lanceur),
                    _sql_lit(m.masse_kg),
                    _sql_lit(m.nom_corps_cible),
                ]
            )
            + ")"
        )
    lignes.append(",\n".join(valeurs_missions))
    lignes.extend(
        [
            ") AS v(",
            "    nom_mission, date_lancement, pays_operateur, type_mission,",
            "    tentative, echec_lancement, lanceur, masse_kg, nom_corps_cible",
            ")",
            "LEFT JOIN corps_celeste c ON c.nom = v.nom_corps_cible;",
            "",
            "-- Affectation de responsables applicatifs sur quelques missions réelles phares du CSV",
            "UPDATE mission SET id_responsable = (SELECT id_utilisateur FROM utilisateur WHERE username = 's.curie')",
            "WHERE nom_mission IN ('Mars 2020', 'Mars Science Laboratory', 'JUpiter ICy moons Explorer (JUICE)');",
            "UPDATE mission SET id_responsable = (SELECT id_utilisateur FROM utilisateur WHERE username = 'tlenfant')",
            "WHERE nom_mission IN ('Cassini', 'Rosetta', 'Voyager 1');",
            "UPDATE mission SET id_responsable = (SELECT id_utilisateur FROM utilisateur WHERE username = 'admin')",
            "WHERE nom_mission IN ('Artemis 1', 'Chang''e 5');",
            "",
            "-- 6. instrument_scientifique (catégorie absente des CSV — équipements réels)",
            "INSERT INTO instrument_scientifique (nom_instrument, type_mesure) VALUES",
            "('SuperCam',      'Spectrométrie laser & Raman'),",
            "('Mastcam-Z',     'Imagerie couleur stéréoscopique'),",
            "('PIXL',          'Fluorescence X haute précision'),",
            "('ChemCam',       'Spectroscopie laser LIBS'),",
            "('ROLIS',         'Caméra de descente et surface'),",
            "('JANUS',         'Caméra optique multispectrale'),",
            "('Magnétomètre',  'Mesure des champs magnétiques planétaires');",
            "",
            "-- 7. mission_instrument (Association M:N sur de vraies missions du CSV)",
            "INSERT INTO mission_instrument (id_mission, id_instrument, role)",
            "SELECT m.id_mission, i.id_instrument, v.role",
            "FROM (VALUES",
            "    ('Mars 2020',                           'SuperCam',     'Minéralogie laser à distance'),",
            "    ('Mars 2020',                           'Mastcam-Z',    'Stéréophotographie multispectrale'),",
            "    ('Mars 2020',                           'PIXL',         'Analyse élémentaire microscopique'),",
            "    ('Mars Science Laboratory',             'ChemCam',      'Composition chimique des roches'),",
            "    ('Rosetta',                             'ROLIS',        'Imagerie in-situ du sol cométaire'),",
            "    ('JUpiter ICy moons Explorer (JUICE)',  'JANUS',        'Cartographie optique globale de Ganymède'),",
            "    ('JUpiter ICy moons Explorer (JUICE)',  'Magnétomètre', 'Champ magnétique jovien et de Ganymède'),",
            "    ('Cassini',                             'Magnétomètre', 'Cartographie de la magnétosphère de Saturne'),",
            "    ('Voyager 1',                           'Magnétomètre', 'Champs magnétiques planétaires et interstellaires')",
            ") AS v(nom_mission, nom_instrument, role)",
            "INNER JOIN mission m ON m.nom_mission = v.nom_mission",
            "INNER JOIN instrument_scientifique i ON i.nom_instrument = v.nom_instrument;",
            "",
            "-- 8. echantillon (Relation 1:1 sur de vraies missions du CSV ; Chang'e 5 reste libre pour la démo UPSERT)",
            "INSERT INTO echantillon (code_tube, type_roche, masse_grammes, id_mission)",
            "SELECT v.code_tube, v.type_roche, v.masse_grammes, m.id_mission",
            "FROM (VALUES",
            "    ('PER-01-ROU', 'Basalte magmatique martien (cratère Jezero)',   8.24, 'Mars 2020'),",
            "    ('APO-11-MAR', 'Basalte lunaire (Mer de la Tranquillité)', 21550.00, 'Apollo 11'),",
            "    ('OSR-01-BEN', 'Régolithe carboné (astéroïde Bennu)',       121.60, 'OSIRIS-REx'),",
            "    ('HYB-02-RYU', 'Matériau primitif carboné (Ryugu)',           5.40, 'Hayabusa 2'),",
            "    ('STD-01-WLD', 'Poussières cométaires (comète Wild 2)',       0.01, 'Stardust')",
            ") AS v(code_tube, type_roche, masse_grammes, nom_mission)",
            "INNER JOIN mission m ON m.nom_mission = v.nom_mission;",
            "",
        ]
    )

    chemin_sortie.write_text("\n".join(lignes), encoding="utf-8", newline="\n")
    print(
        f"[OK] '{chemin_sortie.name}' généré : {len(corps)} corps célestes "
        f"et {len(missions)} missions depuis les 2 CSV."
    )


def main() -> None:
    """Point d'entrée CLI pour importer les 2 CSV réels ou régénérer 02_seed.sql."""
    configurer_sortie_utf8()
    parser = argparse.ArgumentParser(
        description="Importe les 2 CSV (planètes + missions) dans PostgreSQL."
    )
    parser.add_argument(
        "--planetes",
        type=Path,
        default=CSV_PLANETES_DEFAUT,
        help="Chemin vers le CSV des planètes.",
    )
    parser.add_argument(
        "--missions",
        type=Path,
        default=CSV_MISSIONS_DEFAUT,
        help="Chemin vers le CSV des missions.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Valide les 2 CSV sans modifier la base de données.",
    )
    parser.add_argument(
        "--generate-seed",
        action="store_true",
        help="Régénère sql/02_seed.sql à partir des 2 CSV sans toucher à la base.",
    )
    args = parser.parse_args()

    corps_planetes = charger_corps_depuis_planetes(args.planetes)
    cibles_supp, missions = charger_missions_et_cibles(
        args.missions, {c.nom for c in corps_planetes}
    )
    tous_les_corps = corps_planetes + cibles_supp

    if args.generate_seed:
        generer_seed_sql(tous_les_corps, missions, SEED_SQL_DEFAUT)
        return

    importer_en_base(tous_les_corps, missions, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
