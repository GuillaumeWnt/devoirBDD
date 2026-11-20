-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF)
-- Fichier : 02_seed.sql
-- Description : Insertion de données réalistes adaptées au schéma simplifié (1:1 mission-echantillon)
-- ====================================================================

-- 1. corps_celeste
INSERT INTO corps_celeste (nom, type_corps, distance_soleil_ua) VALUES
('Mars', 'Planète tellurique', 1.52),
('Lune', 'Lune tellurique', 1.00),
('Titan', 'Lune glacée', 9.58),
('Europe', 'Lune glacée', 5.20),
('Encelade', 'Lune glacée', 9.54),
('67P/Tchourioumov', 'Comète', 3.46);

-- 2. mission
INSERT INTO mission (nom_mission, agence_spatiale, statut, id_corps) VALUES
('Mars 2020 (Perseverance)', 'NASA', 'Opérationnelle', 1),
('Curiosity (MSL)', 'NASA', 'Opérationnelle', 1),
('Cassini-Huygens', 'NASA / ESA', 'Terminée', 3),
('Rosetta / Philae', 'ESA', 'Terminée', 6),
('Artemis III', 'NASA / ESA', 'En préparation', 2),
('JUICE', 'ESA', 'En transit', 4);

-- 3. instrument_scientifique
INSERT INTO instrument_scientifique (nom_instrument, type_mesure) VALUES
('SuperCam', 'Spectrométrie laser & Raman'),
('Mastcam-Z', 'Imagerie couleur stéréoscopique'),
('PIXL', 'Fluorescence X haute précision'),
('ChemCam', 'Spectroscopie laser LIBS'),
('ROLIS', 'Caméra de descente et surface'),
('JANUS', 'Caméra optique multispectrale');

-- 4. mission_instrument (Relation N:M)
INSERT INTO mission_instrument (id_mission, id_instrument, role) VALUES
(1, 1, 'Minéralogie laser à distance'),
(1, 2, 'Stéréophotographie multispectrale'),
(1, 3, 'Analyse élémentaire microscopique'),
(2, 4, 'Composition chimique des roches'),
(4, 5, 'Imagerie in-situ du sol cométaire'),
(6, 6, 'Cartographie optique globale');

-- 5. echantillon (Relation 1:1 : Au plus 1 échantillon par mission)
INSERT INTO echantillon (code_tube, type_roche, masse_grammes, id_mission) VALUES
('PER-01-ROU', 'Basalte magmatique à olivine', 8.24, 1),
('MSL-01-CUM', 'Smectite argileuse hydratée', 1.25, 2),
('ROS-01-COM', 'Glace d''eau et carbone organique', 0.12, 4);
