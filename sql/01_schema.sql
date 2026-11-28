-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
-- Fichier : 01_schema.sql
-- Description : Schéma relationnel en 3NF conservant exactement 8 tables,
--   enrichi pour intégrer directement les 2 jeux de données réels :
--     - data/aidb-solar-system-planets.csv (planètes & propriétés physiques)
--     - data/aidb-lunar-and-planetary-missions.csv (279 missions réelles)
--   Tout en conservant :
--     - Gestion des profils et mots de passe hachés (md5)
--     - Graphe orienté et pondéré à double sens (trajectoire_orbitale)
--     - Relations 1:N, M:N (mission_instrument) et 1:1 (echantillon)
-- ====================================================================

-- 1. Nettoyage initial (ordre inverse des dépendances)
DROP TABLE IF EXISTS echantillon CASCADE;
DROP TABLE IF EXISTS mission_instrument CASCADE;
DROP TABLE IF EXISTS trajectoire_orbitale CASCADE;
DROP TABLE IF EXISTS instrument_scientifique CASCADE;
DROP TABLE IF EXISTS mission CASCADE;
DROP TABLE IF EXISTS utilisateur CASCADE;
DROP TABLE IF EXISTS profil CASCADE;
DROP TABLE IF EXISTS corps_celeste CASCADE;

-- --------------------------------------------------------------------
-- TABLE 1 : profil
-- Rôles applicatifs et permissions (évite toute dépendance transitive
-- dans utilisateur : garantie 3NF).
-- Note : 'description' n'est pas un mot-clé réservé en PostgreSQL.
-- --------------------------------------------------------------------
CREATE TABLE profil (
    id_profil SERIAL PRIMARY KEY,
    nom_profil VARCHAR(40) NOT NULL UNIQUE,
    peut_ecrire BOOLEAN NOT NULL DEFAULT FALSE,
    peut_supprimer BOOLEAN NOT NULL DEFAULT FALSE,
    description VARCHAR(150) NOT NULL
);

-- --------------------------------------------------------------------
-- TABLE 2 : utilisateur
-- Relation 1:N avec profil
-- Stockage du mot de passe uniquement sous forme d'empreinte (hash),
-- jamais en clair (exemple du cours : md5(...)).
-- Note : on évite le nom "user", mot réservé en PostgreSQL.
-- --------------------------------------------------------------------
CREATE TABLE utilisateur (
    id_utilisateur SERIAL PRIMARY KEY,
    username VARCHAR(60) NOT NULL UNIQUE,
    nom_complet VARCHAR(100) NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    id_profil INTEGER NOT NULL REFERENCES profil (id_profil) ON DELETE RESTRICT
);

-- --------------------------------------------------------------------
-- TABLE 3 : corps_celeste
-- Catalogue des astres (sommets du graphe orbital), alimenté par :
--   1) data/aidb-solar-system-planets.csv (propriétés physiques exactes)
--   2) les cibles non-planétaires présentes dans missions.csv (Moon,
--      Titan, Ganymede, Sun, Asteroid, Comet) sans inventer de mesures.
-- --------------------------------------------------------------------
CREATE TABLE corps_celeste (
    id_corps SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    code_wikidata VARCHAR(20) UNIQUE,
    type_corps VARCHAR(60) NOT NULL,
    distance_soleil_ua NUMERIC(10, 4) CHECK (distance_soleil_ua > 0),
    diametre_km NUMERIC(10, 2) CHECK (diametre_km > 0),
    masse_kg DOUBLE PRECISION CHECK (masse_kg > 0),
    gravite_m_s2 NUMERIC(6, 2) CHECK (gravite_m_s2 > 0),
    vitesse_liberation_km_s NUMERIC(6, 2) CHECK (vitesse_liberation_km_s > 0),
    periode_orbitale_jours NUMERIC(10, 2) CHECK (periode_orbitale_jours > 0),
    temperature_moyenne_c NUMERIC(6, 1),
    nb_lunes INTEGER CHECK (nb_lunes >= 0),
    a_des_anneaux BOOLEAN,
    champ_magnetique BOOLEAN,
    date_decouverte DATE
);

-- --------------------------------------------------------------------
-- TABLE 4 : trajectoire_orbitale (Graphe orienté et pondéré — M:N réflexive)
-- Auto-association sur corps_celeste :
--   - Orientée : (id_corps_depart -> id_corps_arrivee)
--   - Double sens autorisé : (A -> B) et (B -> A) sont 2 lignes distinctes
--     avec des poids asymétriques (coût aller != coût retour)
--   - Pondérée : delta_v_ms (énergie en m/s) et duree_jours (temps)
-- --------------------------------------------------------------------
CREATE TABLE trajectoire_orbitale (
    id_trajectoire SERIAL PRIMARY KEY,
    id_corps_depart INTEGER NOT NULL REFERENCES corps_celeste (id_corps) ON DELETE CASCADE,
    id_corps_arrivee INTEGER NOT NULL REFERENCES corps_celeste (id_corps) ON DELETE CASCADE,
    delta_v_ms NUMERIC(9, 2) NOT NULL CHECK (delta_v_ms > 0),
    duree_jours NUMERIC(7, 1) NOT NULL CHECK (duree_jours > 0),
    type_transfert VARCHAR(80) NOT NULL,
    CONSTRAINT uq_trajectoire_orientee UNIQUE (id_corps_depart, id_corps_arrivee),
    CONSTRAINT chk_corps_differents CHECK (id_corps_depart <> id_corps_arrivee)
);

-- --------------------------------------------------------------------
-- TABLE 5 : mission
-- Alimentée intégralement par data/aidb-lunar-and-planetary-missions.csv
-- Relations :
--   - 0..1 : N avec corps_celeste (id_corps nullable pour les 3 missions
--     du CSV sans cible planétaire définie : Zond 4, Kepler, Q-PACE)
--   - 0..1 : N avec utilisateur (id_responsable optionnel)
-- --------------------------------------------------------------------
CREATE TABLE mission (
    id_mission SERIAL PRIMARY KEY,
    nom_mission VARCHAR(100) NOT NULL UNIQUE,
    date_lancement DATE,
    pays_operateur VARCHAR(80) NOT NULL,
    type_mission VARCHAR(120) NOT NULL,
    tentative BOOLEAN NOT NULL DEFAULT FALSE,
    echec_lancement BOOLEAN NOT NULL DEFAULT FALSE,
    lanceur VARCHAR(60),
    masse_kg NUMERIC(10, 2) CHECK (masse_kg > 0),
    id_corps INTEGER REFERENCES corps_celeste (id_corps) ON DELETE RESTRICT,
    id_responsable INTEGER REFERENCES utilisateur (id_utilisateur) ON DELETE SET NULL
);

-- --------------------------------------------------------------------
-- TABLE 6 : instrument_scientifique
-- Catalogue des instruments scientifiques réels
-- --------------------------------------------------------------------
CREATE TABLE instrument_scientifique (
    id_instrument SERIAL PRIMARY KEY,
    nom_instrument VARCHAR(100) NOT NULL UNIQUE,
    type_mesure VARCHAR(100) NOT NULL
);

-- --------------------------------------------------------------------
-- TABLE 7 : mission_instrument (Association M:N)
-- Relie les missions réelles du CSV aux instruments embarqués et leur rôle
-- --------------------------------------------------------------------
CREATE TABLE mission_instrument (
    id_mission INTEGER NOT NULL REFERENCES mission (id_mission) ON DELETE CASCADE,
    id_instrument INTEGER NOT NULL REFERENCES instrument_scientifique (id_instrument) ON DELETE RESTRICT,
    role VARCHAR(100) NOT NULL,
    PRIMARY KEY (id_mission, id_instrument)
);

-- --------------------------------------------------------------------
-- TABLE 8 : echantillon (Relation 1:1 avec mission)
-- La contrainte UNIQUE sur id_mission garantit au plus 1 échantillon par mission
-- --------------------------------------------------------------------
CREATE TABLE echantillon (
    id_echantillon SERIAL PRIMARY KEY,
    code_tube VARCHAR(40) NOT NULL UNIQUE,
    type_roche VARCHAR(100) NOT NULL,
    masse_grammes NUMERIC(10, 2) NOT NULL CHECK (masse_grammes > 0),
    id_mission INTEGER NOT NULL UNIQUE REFERENCES mission (id_mission) ON DELETE CASCADE
);
