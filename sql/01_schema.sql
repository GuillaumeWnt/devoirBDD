-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
-- Fichier : 01_schema.sql
-- Description : Définition du schéma relationnel en 3NF comprenant :
--   - 8 tables (dont 2 tables d'association M:N)
--   - Relations 1:N, M:N et 1:1
--   - Gestion des profils et mots de passe hachés (jamais en clair)
--   - Graphe orienté et pondéré (possible à double sens) sur les astres
--   - Tailles de colonnes souples pour faciliter un éventuel import externe
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
-- dans la table utilisateur : garantie 3NF)
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
-- Note : on évite le nom "user", qui est un mot réservé en PostgreSQL.
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
-- Catalogue des astres (sommets du graphe orbital)
-- Colonnes dimensionnées avec marge pour d'éventuels imports externes.
-- --------------------------------------------------------------------
CREATE TABLE corps_celeste (
    id_corps SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    type_corps VARCHAR(60) NOT NULL,
    distance_soleil_ua NUMERIC(10, 3) CHECK (distance_soleil_ua > 0)
);

-- --------------------------------------------------------------------
-- TABLE 4 : trajectoire_orbitale (Graphe orienté et pondéré — M:N réflexive)
-- Auto-association sur corps_celeste :
--   - Orientée : (id_corps_depart -> id_corps_arrivee)
--   - Double sens autorisé : (A -> B) et (B -> A) sont 2 lignes distinctes
--     pouvant porter des poids différents (asymétrie énergétique aller/retour)
--   - Pondérée : delta_v_ms (coût énergétique en m/s) et duree_jours
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
-- Relations 1:N avec corps_celeste (cible) et utilisateur (responsable optionnel)
-- id_responsable est nullable afin de permettre l'import de missions externes.
-- --------------------------------------------------------------------
CREATE TABLE mission (
    id_mission SERIAL PRIMARY KEY,
    nom_mission VARCHAR(100) NOT NULL UNIQUE,
    agence_spatiale VARCHAR(80) NOT NULL,
    statut VARCHAR(40) NOT NULL,
    id_corps INTEGER NOT NULL REFERENCES corps_celeste (id_corps) ON DELETE RESTRICT,
    id_responsable INTEGER REFERENCES utilisateur (id_utilisateur) ON DELETE SET NULL
);

-- --------------------------------------------------------------------
-- TABLE 6 : instrument_scientifique
-- Catalogue des types d'instruments scientifiques
-- --------------------------------------------------------------------
CREATE TABLE instrument_scientifique (
    id_instrument SERIAL PRIMARY KEY,
    nom_instrument VARCHAR(100) NOT NULL UNIQUE,
    type_mesure VARCHAR(100) NOT NULL
);

-- --------------------------------------------------------------------
-- TABLE 7 : mission_instrument (Association M:N)
-- Relie les missions et les instruments embarqués avec leur rôle précis
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
