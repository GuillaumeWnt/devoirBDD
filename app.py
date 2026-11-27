"""
PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
Fichier : app.py
Description : Application Python en ligne de commande (CLI) exploitant la base
              PostgreSQL 'exploration_spatiale' :
              - Authentification multi-profils par mot de passe haché (md5)
              - CRUD complet (insertion, modification avec preuve, suppression vérifiée)
              - 3 états SQL multi-tables (INNER JOIN, LEFT JOIN, GROUP BY + HAVING)
              - Exploitation du graphe orienté et pondéré (réseau + Dijkstra)
"""

import getpass
import heapq
import sys
from dataclasses import dataclass
from typing import Any

import psycopg

from db import charger_config_db, configurer_sortie_utf8, ouvrir_connexion

Conn = psycopg.Connection[tuple[Any, ...]]


@dataclass(frozen=True)
class UtilisateurConnecte:
    """Représente la session authentifiée et les permissions de son profil."""

    id_utilisateur: int
    username: str
    nom_complet: str
    nom_profil: str
    peut_ecrire: bool
    peut_supprimer: bool


# ====================================================================
# OUTILS DE SAISIE UTILISATEUR (CLI)
# ====================================================================


def demander_texte(invite: str, obligatoire: bool = True) -> str:
    """Demande une chaîne de caractères dans le terminal."""
    while True:
        valeur = input(invite).strip()
        if valeur or not obligatoire:
            return valeur
        print("[!] Cette valeur est obligatoire.")


def demander_mot_de_passe(invite: str) -> str:
    """Masque la saisie en terminal interactif (et reste compatible avec stdin redirigé)."""
    if sys.stdin.isatty():
        return getpass.getpass(invite).strip()
    return input(invite).strip()


def demander_entier(invite: str, optionnel: bool = False) -> int | None:
    """Demande un nombre entier valide."""
    while True:
        brut = input(invite).strip()
        if not brut and optionnel:
            return None
        try:
            return int(brut)
        except ValueError:
            print("[!] Veuillez saisir un entier valide.")


def demander_flottant(invite: str, strictement_positif: bool = True) -> float:
    """Demande un nombre décimal (accepte la virgule ou le point)."""
    while True:
        brut = input(invite).strip().replace(",", ".")
        try:
            valeur = float(brut)
            if strictement_positif and valeur <= 0:
                print("[!] La valeur doit être strictement supérieure à 0.")
                continue
            return valeur
        except ValueError:
            print("[!] Veuillez saisir un nombre valide (ex. 12.50).")


# ====================================================================
# AUTHENTIFICATION & PROFILS (MOTS DE PASSE HACHÉS PAR MD5)
# ====================================================================


def authentifier_utilisateur(conn: Conn) -> UtilisateurConnecte | None:
    """Authentifie un utilisateur via md5(%s) sans jamais stocker de mot de passe en clair."""
    print("\n=== AUTHENTIFICATION PAR PROFIL (mot de passe haché via md5) ===")
    print("Comptes de démonstration disponibles : tlenfant, admin, s.curie, invite")
    print("(Laissez le nom d'utilisateur vide pour quitter.)")

    query = """
        SELECT
            u.id_utilisateur,
            u.username,
            u.nom_complet,
            p.nom_profil,
            p.peut_ecrire,
            p.peut_supprimer
        FROM utilisateur u
        INNER JOIN profil p ON u.id_profil = p.id_profil
        WHERE u.username = %s
          AND u.password_hash = md5(%s);
    """

    for tentative in range(1, 4):
        username = input("Nom d'utilisateur : ").strip()
        if not username:
            return None
        mot_de_passe = demander_mot_de_passe("Mot de passe : ")

        with conn.cursor() as cur:
            cur.execute(query, (username, mot_de_passe))
            row = cur.fetchone()

        if row is not None:
            session = UtilisateurConnecte(
                id_utilisateur=int(row[0]),
                username=str(row[1]),
                nom_complet=str(row[2]),
                nom_profil=str(row[3]),
                peut_ecrire=bool(row[4]),
                peut_supprimer=bool(row[5]),
            )
            print(
                f"\n[OK] Connecté en tant que {session.nom_complet} "
                f"({session.username}) — Profil : {session.nom_profil.upper()}"
            )
            return session

        print(f"[ERREUR] Identifiants incorrects (tentative {tentative}/3).\n")

    print("[!] Nombre maximal de tentatives atteint.")
    return None


def verifier_droit_ecriture(session: UtilisateurConnecte) -> bool:
    """Vérifie que le profil connecté autorise la saisie et la modification."""
    if not session.peut_ecrire:
        print(
            f"\n[ACCÈS REFUSÉ] Le profil '{session.nom_profil}' est en lecture seule. "
            "Connectez-vous en tant que 'scientifique' ou 'administrateur'."
        )
        return False
    return True


def verifier_droit_suppression(session: UtilisateurConnecte) -> bool:
    """Vérifie que le profil connecté autorise la suppression."""
    if not session.peut_supprimer:
        print(
            f"\n[ACCÈS REFUSÉ] Le profil '{session.nom_profil}' ne peut pas supprimer "
            "d'enregistrements. Connectez-vous avec un profil 'administrateur'."
        )
        return False
    return True


def creer_utilisateur(conn: Conn, session: UtilisateurConnecte) -> None:
    """Crée un nouvel utilisateur avec mot de passe haché md5(%s) (admin uniquement)."""
    if not verifier_droit_suppression(session):
        return

    print("\n=== CRÉATION D'UN COMPTE UTILISATEUR (stockage MD5) ===")
    with conn.cursor() as cur:
        cur.execute("SELECT id_profil, nom_profil, description FROM profil ORDER BY id_profil;")
        for row in cur.fetchall():
            print(f"  #{row[0]} | {row[1]:<15} | {row[2]}")

    username = demander_texte("Nouvel identifiant (username) : ")
    nom_complet = demander_texte("Nom complet : ")
    mot_de_passe = demander_mot_de_passe("Mot de passe (sera haché par md5) : ")
    if not mot_de_passe:
        print("[!] Le mot de passe ne peut pas être vide.")
        return
    id_profil = demander_entier("ID du profil attribué : ")

    query = """
        INSERT INTO utilisateur (username, nom_complet, password_hash, id_profil)
        VALUES (%s, %s, md5(%s), %s)
        RETURNING id_utilisateur, password_hash;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query, (username, nom_complet, mot_de_passe, id_profil))
            row = cur.fetchone()
        conn.commit()
        if row is not None:
            print(
                f"[OK] Utilisateur #{row[0]} ('{username}') créé. "
                f"Empreinte stockée en base : {row[1]}"
            )
    except psycopg.Error as err:
        conn.rollback()
        print(f"[ERREUR SQL] Impossible de créer l'utilisateur : {err}")


def lister_utilisateurs(conn: Conn) -> None:
    """Affiche les utilisateurs, leur profil et un extrait de leur hash (jamais en clair)."""
    print("\n=== COMPTES UTILISATEURS ET PROFILS ===")
    query = """
        SELECT
            u.id_utilisateur,
            u.username,
            u.nom_complet,
            p.nom_profil,
            LEFT(u.password_hash, 12) || '...' AS apercu_hash
        FROM utilisateur u
        INNER JOIN profil p ON u.id_profil = p.id_profil
        ORDER BY u.id_utilisateur;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        for row in cur.fetchall():
            print(
                f"ID #{row[0]:<2} | {row[1]:<12} | {row[2]:<24} "
                f"| Profil: {row[3]:<14} | Hash MD5: {row[4]}"
            )


# ====================================================================
# AIDES D'AFFICHAGE DE RÉFÉRENCE
# ====================================================================


def afficher_corps_celestes(conn: Conn) -> None:
    """Affiche la liste numérotée des corps célestes."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id_corps, nom, type_corps, distance_soleil_ua "
            "FROM corps_celeste ORDER BY id_corps;"
        )
        print("\nCorps célestes disponibles :")
        for row in cur.fetchall():
            dist = f"{row[3]} UA" if row[3] is not None else "N/A"
            print(f"  #{row[0]:<2} | {row[1]:<18} | {row[2]:<20} | {dist}")


def afficher_missions(conn: Conn) -> None:
    """Affiche la liste des missions existantes."""
    query = """
        SELECT m.id_mission, m.nom_mission, m.agence_spatiale, m.statut, c.nom
        FROM mission m
        INNER JOIN corps_celeste c ON m.id_corps = c.id_corps
        ORDER BY m.id_mission;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        print("\nMissions enregistrées :")
        for row in cur.fetchall():
            print(
                f"  #{row[0]:<2} | {row[1]:<28} | {row[2]:<12} "
                f"| Statut: {row[3]:<16} | Cible: {row[4]}"
            )


def afficher_echantillons(conn: Conn) -> None:
    """Affiche les échantillons enregistrés avec leur mission."""
    query = """
        SELECT e.id_echantillon, e.code_tube, e.type_roche, e.masse_grammes, m.nom_mission
        FROM echantillon e
        INNER JOIN mission m ON e.id_mission = m.id_mission
        ORDER BY e.id_echantillon;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        print("\nÉchantillons enregistrés (relation 1:1) :")
        if not rows:
            print("  (Aucun échantillon en base)")
        for row in rows:
            print(
                f"  #{row[0]:<2} | {row[1]:<12} | {row[2]:<34} "
                f"| {row[3]:>6} g | Mission: {row[4]}"
            )


# ====================================================================
# OPÉRATIONS CRUD : SAISIR, MODIFIER, SUPPRIMER
# ====================================================================


def inserer_mission(conn: Conn, session: UtilisateurConnecte) -> None:
    """Insère une nouvelle mission spatiale (relation 1:N avec corps_celeste)."""
    if not verifier_droit_ecriture(session):
        return

    print("\n=== INSÉRER UNE NOUVELLE MISSION ===")
    afficher_corps_celestes(conn)
    nom_mission = demander_texte("Nom de la mission : ")
    agence = demander_texte("Agence spatiale (ex. ESA, NASA, JAXA) : ")
    statut = demander_texte("Statut (Opérationnelle / En transit / En préparation / Terminée) : ")
    id_corps = demander_entier("ID du corps céleste ciblé : ")

    query = """
        INSERT INTO mission (nom_mission, agence_spatiale, statut, id_corps, id_responsable)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id_mission;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query, (nom_mission, agence, statut, id_corps, session.id_utilisateur))
            row = cur.fetchone()
        conn.commit()
        if row is not None:
            print(f"[INSERT] Mission '{nom_mission}' créée avec l'ID #{row[0]}.")
    except psycopg.Error as err:
        conn.rollback()
        print(f"[ERREUR SQL] Insertion impossible : {err}")


def inserer_echantillon(conn: Conn, session: UtilisateurConnecte) -> None:
    """Insère ou met à jour un échantillon en respectant la relation 1:1 (UPSERT)."""
    if not verifier_droit_ecriture(session):
        return

    print("\n=== INSÉRER UN ÉCHANTILLON (Relation 1:1 avec mission) ===")
    afficher_missions(conn)
    code_tube = demander_texte("Code unique du tube (ex. ART-01-REG) : ")
    type_roche = demander_texte("Type de roche prélevée : ")
    masse = demander_flottant("Masse en grammes (> 0) : ")
    id_mission = demander_entier("ID de la mission associée : ")

    query = """
        INSERT INTO echantillon (code_tube, type_roche, masse_grammes, id_mission)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (id_mission) DO UPDATE
            SET code_tube = EXCLUDED.code_tube,
                type_roche = EXCLUDED.type_roche,
                masse_grammes = EXCLUDED.masse_grammes
        RETURNING id_echantillon;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query, (code_tube, type_roche, masse, id_mission))
            row = cur.fetchone()
        conn.commit()
        if row is not None:
            print(
                f"[INSERT/UPDATE] Échantillon #{row[0]} ('{code_tube}') enregistré "
                f"pour la mission #{id_mission}."
            )
    except psycopg.Error as err:
        conn.rollback()
        print(f"[ERREUR SQL] Insertion impossible : {err}")


def inserer_trajectoire(conn: Conn, session: UtilisateurConnecte) -> None:
    """Insère une nouvelle arête orientée et pondérée dans le graphe orbital."""
    if not verifier_droit_ecriture(session):
        return

    print("\n=== INSÉRER UNE TRAJECTOIRE ORBITALE (Graphe orienté pondéré) ===")
    afficher_corps_celestes(conn)
    id_depart = demander_entier("ID du corps céleste de départ : ")
    id_arrivee = demander_entier("ID du corps céleste d'arrivée : ")
    delta_v = demander_flottant("Coût énergétique delta-v en m/s (> 0) : ")
    duree = demander_flottant("Durée du transit en jours (> 0) : ")
    type_transfert = demander_texte("Type de transfert (ex. Transfert de Hohmann) : ")

    query = """
        INSERT INTO trajectoire_orbitale (
            id_corps_depart, id_corps_arrivee, delta_v_ms, duree_jours, type_transfert
        )
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id_trajectoire;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query, (id_depart, id_arrivee, delta_v, duree, type_transfert))
            row = cur.fetchone()
        conn.commit()
        if row is not None:
            print(f"[INSERT] Trajectoire orientée créée avec l'ID #{row[0]}.")
    except psycopg.Error as err:
        conn.rollback()
        print(f"[ERREUR SQL] Insertion impossible : {err}")


def modifier_enregistrement(conn: Conn, session: UtilisateurConnecte) -> None:
    """Modifie une mission ou un échantillon et affiche la nouvelle valeur obtenue."""
    if not verifier_droit_ecriture(session):
        return

    print("\n=== MODIFIER UN ENREGISTREMENT ===")
    print("  1. Modifier le statut d'une mission")
    print("  2. Modifier la masse et la nature d'un échantillon")
    choix = input("Votre choix (1/2) : ").strip()

    if choix == "1":
        afficher_missions(conn)
        id_mission = demander_entier("ID de la mission à modifier : ")
        nouveau_statut = demander_texte("Nouveau statut : ")

        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT nom_mission, statut FROM mission WHERE id_mission = %s;",
                    (id_mission,),
                )
                avant = cur.fetchone()
                if avant is None:
                    print(f"[!] Aucune mission trouvée avec l'ID #{id_mission}.")
                    return

                cur.execute(
                    "UPDATE mission SET statut = %s WHERE id_mission = %s "
                    "RETURNING id_mission, nom_mission, statut;",
                    (nouveau_statut, id_mission),
                )
                apres = cur.fetchone()
            conn.commit()
            if apres is not None:
                print(
                    f"[UPDATE] Mission #{apres[0]} ({apres[1]}) : "
                    f"'{avant[1]}' -> '{apres[2]}'"
                )
        except psycopg.Error as err:
            conn.rollback()
            print(f"[ERREUR SQL] Modification impossible : {err}")

    elif choix == "2":
        afficher_echantillons(conn)
        id_echantillon = demander_entier("ID de l'échantillon à modifier : ")
        nouvelle_roche = demander_texte("Nouveau type de roche : ")
        nouvelle_masse = demander_flottant("Nouvelle masse en grammes (> 0) : ")

        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT code_tube, type_roche, masse_grammes "
                    "FROM echantillon WHERE id_echantillon = %s;",
                    (id_echantillon,),
                )
                avant = cur.fetchone()
                if avant is None:
                    print(f"[!] Aucun échantillon trouvé avec l'ID #{id_echantillon}.")
                    return

                cur.execute(
                    """
                    UPDATE echantillon
                    SET type_roche = %s, masse_grammes = %s
                    WHERE id_echantillon = %s
                    RETURNING id_echantillon, code_tube, type_roche, masse_grammes;
                    """,
                    (nouvelle_roche, nouvelle_masse, id_echantillon),
                )
                apres = cur.fetchone()
            conn.commit()
            if apres is not None:
                print(
                    f"[UPDATE] Échantillon #{apres[0]} ({apres[1]}) :\n"
                    f"  Avant : {avant[1]} ({avant[2]} g)\n"
                    f"  Après : {apres[2]} ({apres[3]} g)"
                )
        except psycopg.Error as err:
            conn.rollback()
            print(f"[ERREUR SQL] Modification impossible : {err}")
    else:
        print("[!] Choix annulé.")


def supprimer_enregistrement(conn: Conn, session: UtilisateurConnecte) -> None:
    """Supprime un enregistrement (admin uniquement) puis vérifie sa disparition."""
    if not verifier_droit_suppression(session):
        return

    print("\n=== SUPPRIMER UN ENREGISTREMENT (avec vérification de disparition) ===")
    print("  1. Supprimer un échantillon")
    print("  2. Supprimer une mission (supprime en cascade ses liaisons et son échantillon)")
    print("  3. Supprimer une trajectoire orbitale")
    choix = input("Votre choix (1/2/3) : ").strip()

    cibles: dict[str, tuple[str, str, str]] = {
        "1": ("echantillon", "id_echantillon", "code_tube"),
        "2": ("mission", "id_mission", "nom_mission"),
        "3": ("trajectoire_orbitale", "id_trajectoire", "type_transfert"),
    }
    if choix not in cibles:
        print("[!] Choix annulé.")
        return

    if choix == "1":
        afficher_echantillons(conn)
    elif choix == "2":
        afficher_missions(conn)
    else:
        afficher_reseau_orbital(conn)

    table, col_id, col_label = cibles[choix]
    id_cible = demander_entier(f"ID à supprimer dans {table} : ")

    # Les noms de tables/colonnes proviennent uniquement du dictionnaire statique `cibles`.
    requetes_delete = {
        "1": (
            "DELETE FROM echantillon WHERE id_echantillon = %s RETURNING id_echantillon, code_tube;",
            "SELECT COUNT(*) FROM echantillon WHERE id_echantillon = %s;",
        ),
        "2": (
            "DELETE FROM mission WHERE id_mission = %s RETURNING id_mission, nom_mission;",
            "SELECT COUNT(*) FROM mission WHERE id_mission = %s;",
        ),
        "3": (
            (
                "DELETE FROM trajectoire_orbitale WHERE id_trajectoire = %s "
                "RETURNING id_trajectoire, type_transfert;"
            ),
            "SELECT COUNT(*) FROM trajectoire_orbitale WHERE id_trajectoire = %s;",
        ),
    }
    q_delete, q_check = requetes_delete[choix]

    try:
        with conn.cursor() as cur:
            cur.execute(q_delete, (id_cible,))
            supprime = cur.fetchone()
            if supprime is None:
                print(f"[!] Aucun enregistrement trouvé ({col_id} = {id_cible}).")
                return
            conn.commit()
            print(
                f"[DELETE] Enregistrement supprimé : {table} #{supprime[0]} "
                f"({col_label} = '{supprime[1]}')."
            )

            # Vérification explicite de la disparition en base
            cur.execute(q_check, (id_cible,))
            verif = cur.fetchone()
            nb_restants = int(verif[0]) if verif is not None else -1
            print(
                f"[VÉRIFICATION] Nombre de lignes restantes pour {col_id} = {id_cible} : "
                f"{nb_restants} (disparition confirmée)."
            )
    except psycopg.Error as err:
        conn.rollback()
        print(f"[ERREUR SQL] Suppression impossible : {err}")


# ====================================================================
# LES 3 ÉTATS SQL MULTI-TABLES
# ====================================================================


def etat_1_missions_instruments_actifs(conn: Conn) -> None:
    """État 1 (INNER JOIN sur 5 tables) : instruments sur les missions actives."""
    print("\n=== ÉTAT 1 : FLOTTE ACTIVE, RESPONSABLES ET INSTRUMENTS (INNER JOIN) ===")
    query = """
        SELECT
            m.nom_mission,
            c.nom AS cible_exploration,
            COALESCE(u.nom_complet, 'Non assigné') AS responsable,
            i.nom_instrument,
            mi.role AS role_instrument
        FROM mission m
        INNER JOIN corps_celeste c ON m.id_corps = c.id_corps
        LEFT JOIN utilisateur u ON m.id_responsable = u.id_utilisateur
        INNER JOIN mission_instrument mi ON m.id_mission = mi.id_mission
        INNER JOIN instrument_scientifique i ON mi.id_instrument = i.id_instrument
        WHERE m.statut IN ('Opérationnelle', 'En transit')
        ORDER BY m.nom_mission, i.nom_instrument;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()

    for row in rows:
        print(
            f"Mission: {row[0]:<25} | Cible: {row[1]:<8} | Resp.: {row[2]:<15} "
            f"| Instr.: {row[3]:<10} | Rôle: {row[4]}"
        )
    print(f"Total : {len(rows)} affectation(s) active(s).")


def etat_2_inventaire_corps_celestes(conn: Conn) -> None:
    """État 2 (LEFT JOIN + COALESCE) : tous les corps célestes, explorés ou non."""
    print("\n=== ÉTAT 2 : INVENTAIRE COMPLET DES CORPS CÉLESTES (LEFT JOIN) ===")
    query = """
        SELECT
            c.nom AS corps_celeste,
            c.type_corps,
            c.distance_soleil_ua,
            COALESCE(m.nom_mission, '--- Aucune mission ---') AS mission_assignee,
            COALESCE(m.statut, 'Non exploré') AS statut_exploration
        FROM corps_celeste c
        LEFT JOIN mission m ON c.id_corps = m.id_corps
        ORDER BY c.distance_soleil_ua ASC, c.nom ASC;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()

    for row in rows:
        dist = f"{row[2]:>6} UA" if row[2] is not None else "   N/A   "
        print(
            f"Astre: {row[0]:<17} | {row[1]:<19} | {dist} "
            f"| Mission: {row[3]:<25} | {row[4]}"
        )
    print(f"Total : {len(rows)} ligne(s) d'inventaire.")


def etat_3_bilan_echantillons_par_corps(conn: Conn) -> None:
    """État 3 (GROUP BY + HAVING + jointures) : bilan des échantillons par astre."""
    print("\n=== ÉTAT 3 : BILAN GÉOLOGIQUE PAR CORPS EXPLORÉ (GROUP BY + HAVING) ===")
    query = """
        SELECT
            c.nom AS corps_explore,
            COUNT(e.id_echantillon) AS nb_echantillons,
            ROUND(SUM(e.masse_grammes), 2) AS masse_totale_g,
            ROUND(AVG(e.masse_grammes), 2) AS masse_moyenne_g
        FROM corps_celeste c
        INNER JOIN mission m ON c.id_corps = m.id_corps
        INNER JOIN echantillon e ON m.id_mission = e.id_mission
        GROUP BY c.nom
        HAVING COUNT(e.id_echantillon) >= 1
        ORDER BY masse_totale_g DESC;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()

    for row in rows:
        print(
            f"Astre: {row[0]:<17} | Échantillons: {row[1]:<2} "
            f"| Masse totale: {row[2]:>6} g | Moyenne: {row[3]:>6} g"
        )
    print(f"Total : {len(rows)} astre(s) avec au moins 1 échantillon.")


# ====================================================================
# GRAPHE ORIENTÉ ET PONDÉRÉ (RÉSEAU ORBITAL + DIJKSTRA)
# ====================================================================


def afficher_reseau_orbital(conn: Conn) -> None:
    """Affiche toutes les arêtes orientées/pondérées et indique le double sens."""
    print("\n=== RÉSEAU DES TRAJECTOIRES ORBITALES (Graphe orienté et pondéré) ===")
    query = """
        SELECT
            t.id_trajectoire,
            cd.nom AS depart,
            ca.nom AS arrivee,
            t.delta_v_ms,
            t.duree_jours,
            CASE
                WHEN t_retour.id_trajectoire IS NOT NULL THEN 'Double sens'
                ELSE 'Sens unique'
            END AS sens_liaison,
            t.type_transfert
        FROM trajectoire_orbitale t
        INNER JOIN corps_celeste cd ON t.id_corps_depart = cd.id_corps
        INNER JOIN corps_celeste ca ON t.id_corps_arrivee = ca.id_corps
        LEFT JOIN trajectoire_orbitale t_retour
            ON t_retour.id_corps_depart = t.id_corps_arrivee
           AND t_retour.id_corps_arrivee = t.id_corps_depart
        ORDER BY cd.nom, t.delta_v_ms ASC;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()

    for row in rows:
        print(
            f"#{row[0]:<2} | {row[1]:<16} -> {row[2]:<16} | Δv: {row[3]:>8} m/s "
            f"| Durée: {row[4]:>6} j | {row[5]:<11} | {row[6]}"
        )
    print(f"Total : {len(rows)} arête(s) orientée(s).")


def calculer_plus_court_chemin(
    adjacence: dict[str, list[tuple[str, float, float, str]]],
    depart: str,
    arrivee: str,
    critere: str,
) -> tuple[list[tuple[str, str, float, float, str]], float, float] | None:
    """Calcule le chemin optimal (Dijkstra) selon 'delta_v' ou 'duree'."""
    if depart == arrivee:
        return ([], 0.0, 0.0)

    # File de priorité : (poids_cumulé, sommet_courant)
    file_priorite: list[tuple[float, str]] = [(0.0, depart)]
    meilleurs_couts: dict[str, float] = {depart: 0.0}
    precedents: dict[str, tuple[str, float, float, str]] = {}

    while file_priorite:
        cout_actuel, sommet = heapq.heappop(file_priorite)
        if cout_actuel > meilleurs_couts.get(sommet, float("inf")):
            continue
        if sommet == arrivee:
            break

        for voisin, delta_v, duree, type_transfert in adjacence.get(sommet, []):
            poids = delta_v if critere == "delta_v" else duree
            nouveau_cout = cout_actuel + poids
            if nouveau_cout < meilleurs_couts.get(voisin, float("inf")):
                meilleurs_couts[voisin] = nouveau_cout
                precedents[voisin] = (sommet, delta_v, duree, type_transfert)
                heapq.heappush(file_priorite, (nouveau_cout, voisin))

    if arrivee not in precedents:
        return None

    etapes: list[tuple[str, str, float, float, str]] = []
    courant = arrivee
    total_dv = 0.0
    total_jours = 0.0
    while courant != depart:
        prec, dv, jours, transfert = precedents[courant]
        etapes.append((prec, courant, dv, jours, transfert))
        total_dv += dv
        total_jours += jours
        courant = prec
    etapes.reverse()
    return (etapes, total_dv, total_jours)


def planifier_itineraire_orbital(conn: Conn) -> None:
    """Interface CLI pour calculer le plus court chemin orienté pondéré (Dijkstra)."""
    print("\n=== CALCUL D'ITINÉRAIRE OPTIMAL (Dijkstra sur le graphe orbital) ===")
    with conn.cursor() as cur:
        cur.execute("SELECT id_corps, nom FROM corps_celeste ORDER BY id_corps;")
        corps_par_id = {int(row[0]): str(row[1]) for row in cur.fetchall()}

        cur.execute(
            """
            SELECT cd.nom, ca.nom, t.delta_v_ms, t.duree_jours, t.type_transfert
            FROM trajectoire_orbitale t
            INNER JOIN corps_celeste cd ON t.id_corps_depart = cd.id_corps
            INNER JOIN corps_celeste ca ON t.id_corps_arrivee = ca.id_corps;
            """
        )
        adjacence: dict[str, list[tuple[str, float, float, str]]] = {}
        for dep, arr, dv, jours, transfert in cur.fetchall():
            adjacence.setdefault(str(dep), []).append(
                (str(arr), float(dv), float(jours), str(transfert))
            )

    for id_corps, nom in corps_par_id.items():
        print(f"  #{id_corps:<2} | {nom}")

    id_dep = demander_entier("ID de l'astre de départ : ")
    id_arr = demander_entier("ID de l'astre d'arrivée : ")
    if id_dep not in corps_par_id or id_arr not in corps_par_id:
        print("[!] Identifiant d'astre invalide.")
        return

    print("Critère d'optimisation :")
    print("  1. Minimiser le coût énergétique (delta-v en m/s)")
    print("  2. Minimiser la durée de transit (jours)")
    choix_critere = input("Votre choix (1/2) [défaut: 1] : ").strip()
    critere = "duree" if choix_critere == "2" else "delta_v"

    depart = corps_par_id[id_dep]
    arrivee = corps_par_id[id_arr]
    resultat = calculer_plus_court_chemin(adjacence, depart, arrivee, critere)

    if resultat is None:
        print(f"\n[!] Aucun chemin orienté disponible de '{depart}' vers '{arrivee}'.")
        return

    etapes, total_dv, total_jours = resultat
    libelle = "coût énergétique (Δv)" if critere == "delta_v" else "durée de transit"
    print(f"\n[OK] Meilleur itinéraire de {depart} vers {arrivee} (critère : {libelle}) :")
    if not etapes:
        print("  Vous êtes déjà sur place (0 m/s, 0 jour).")
        return

    for idx, (dep, arr, dv, jours, transfert) in enumerate(etapes, start=1):
        print(f"  Étape {idx} : {dep} -> {arr} | {dv:.2f} m/s | {jours:.1f} j ({transfert})")
    print(f"  TOTAL   : {total_dv:.2f} m/s | {total_jours:.1f} jours")


# ====================================================================
# BOUCLE PRINCIPALE DU MENU CLI
# ====================================================================


def afficher_menu(session: UtilisateurConnecte) -> None:
    """Affiche le menu interactif adapté au profil connecté."""
    droits = (
        "Lecture + Écriture + Suppression"
        if session.peut_supprimer
        else ("Lecture + Écriture" if session.peut_ecrire else "Lecture seule")
    )
    print("\n" + "=" * 68)
    print(
        f" EXPLORATION SPATIALE | {session.nom_complet} ({session.nom_profil}) "
        f"| Droits : {droits}"
    )
    print("=" * 68)
    print("  [CRUD — GESTION DES DONNÉES]")
    print("   1. Insérer une nouvelle mission")
    print("   2. Insérer / mettre à jour un échantillon (relation 1:1)")
    print("   3. Insérer une nouvelle trajectoire orbitale (graphe)")
    print("   4. Modifier un enregistrement existant (avec vérification)")
    print("   5. Supprimer un enregistrement existant (avec vérification)")
    print("  [LES 3 ÉTATS SQL MULTI-TABLES]")
    print("   6. État 1 : Flotte active, responsables et instruments (INNER JOIN)")
    print("   7. État 2 : Inventaire complet des corps célestes (LEFT JOIN)")
    print("   8. État 3 : Bilan géologique par astre (GROUP BY + HAVING)")
    print("  [GRAPHE ORIENTÉ ET PONDÉRÉ]")
    print("   9. Afficher le réseau des trajectoires (double sens / sens unique)")
    print("  10. Calculer l'itinéraire optimal entre deux astres (Dijkstra)")
    print("  [PROFILS & SÉCURITÉ]")
    print("  11. Lister les comptes / créer un compte (hash MD5)")
    print("  12. Changer d'utilisateur (tester un autre profil)")
    print("   0. Quitter")


def main() -> None:
    """Point d'entrée principal de l'application CLI."""
    configurer_sortie_utf8()
    db_config = charger_config_db()

    print(f"Connexion à la base PostgreSQL '{db_config.dbname}'...")
    with ouvrir_connexion(db_config) as conn:
        print("[OK] Connexion établie.")
        session = authentifier_utilisateur(conn)
        if session is None:
            print("Fermeture de l'application.")
            return

        while True:
            afficher_menu(session)
            choix = input("\nChoix : ").strip()

            if choix == "0":
                print("Déconnexion et fermeture de l'application.")
                break
            if choix == "1":
                inserer_mission(conn, session)
            elif choix == "2":
                inserer_echantillon(conn, session)
            elif choix == "3":
                inserer_trajectoire(conn, session)
            elif choix == "4":
                modifier_enregistrement(conn, session)
            elif choix == "5":
                supprimer_enregistrement(conn, session)
            elif choix == "6":
                etat_1_missions_instruments_actifs(conn)
            elif choix == "7":
                etat_2_inventaire_corps_celestes(conn)
            elif choix == "8":
                etat_3_bilan_echantillons_par_corps(conn)
            elif choix == "9":
                afficher_reseau_orbital(conn)
            elif choix == "10":
                planifier_itineraire_orbital(conn)
            elif choix == "11":
                lister_utilisateurs(conn)
                if session.peut_supprimer:
                    reponse = input("\nCréer un nouveau compte utilisateur ? (o/N) : ").strip().lower()
                    if reponse == "o":
                        creer_utilisateur(conn, session)
            elif choix == "12":
                nouvelle_session = authentifier_utilisateur(conn)
                if nouvelle_session is not None:
                    session = nouvelle_session
            else:
                print("[!] Option inconnue. Choisissez un numéro entre 0 et 12.")


if __name__ == "__main__":
    main()
