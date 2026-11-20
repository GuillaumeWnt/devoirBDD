-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF)
-- Fichier : 01_schema.sql
-- Description : Définition du schéma relationnel épuré en 3NF
-- ====================================================================

-- 1. Nettoyage initial (ordre inverse des dépendances)
DROP TABLE IF EXISTS echantillon CASCADE;
DROP TABLE IF EXISTS mission_instrument CASCADE;
DROP TABLE IF EXISTS instrument_scientifique CASCADE;
DROP TABLE IF EXISTS mission CASCADE;
DROP TABLE IF EXISTS corps_celeste CASCADE;

-- --------------------------------------------------------------------
-- TABLE 1 : corps_celeste
-- --------------------------------------------------------------------
CREATE TABLE corps_celeste (
    id_corps SERIAL PRIMARY KEY,
    nom VARCHAR(50) NOT NULL UNIQUE,
    type_corps VARCHAR(40) NOT NULL,
    distance_soleil_ua NUMERIC(5, 2) CHECK (distance_soleil_ua > 0)
);

-- --------------------------------------------------------------------
-- TABLE 2 : mission
-- Relation 1:N avec corps_celeste
-- --------------------------------------------------------------------
CREATE TABLE mission (
    id_mission SERIAL PRIMARY KEY,
    nom_mission VARCHAR(60) NOT NULL UNIQUE,
    agence_spatiale VARCHAR(40) NOT NULL,
    statut VARCHAR(30) NOT NULL,
    id_corps INTEGER NOT NULL REFERENCES corps_celeste (id_corps) ON DELETE RESTRICT
);

-- --------------------------------------------------------------------
-- TABLE 3 : instrument_scientifique
-- Catalogue des types d'instruments
-- --------------------------------------------------------------------
CREATE TABLE instrument_scientifique (
    id_instrument SERIAL PRIMARY KEY,
    nom_instrument VARCHAR(50) NOT NULL UNIQUE,
    type_mesure VARCHAR(50) NOT NULL
);

-- --------------------------------------------------------------------
-- TABLE 4 : mission_instrument (Relation N:M)
-- Association entre missions et instruments
-- --------------------------------------------------------------------
CREATE TABLE mission_instrument (
    id_mission INTEGER NOT NULL REFERENCES mission (id_mission) ON DELETE CASCADE,
    id_instrument INTEGER NOT NULL REFERENCES instrument_scientifique (id_instrument) ON DELETE RESTRICT,
    role VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_mission, id_instrument)
);

-- --------------------------------------------------------------------
-- TABLE 5 : echantillon (Relation 1:1 avec mission)
-- La contrainte UNIQUE sur id_mission garantit la relation 1:1 (au plus 1 échantillon par mission)
-- --------------------------------------------------------------------
CREATE TABLE echantillon (
    id_echantillon SERIAL PRIMARY KEY,
    code_tube VARCHAR(30) NOT NULL UNIQUE,
    type_roche VARCHAR(50) NOT NULL,
    masse_grammes NUMERIC(6, 2) NOT NULL CHECK (masse_grammes > 0),
    id_mission INTEGER NOT NULL UNIQUE REFERENCES mission (id_mission) ON DELETE CASCADE
);
