-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
-- Fichier : 02_seed.sql
-- Description : Jeu d'essai cohérent couvrant les 8 tables :
--   - 3 profils et 4 utilisateurs (mots de passe hachés par md5())
--   - 7 corps célestes et 11 trajectoires orbitales orientées/pondérées
--   - 6 missions, 6 instruments, 7 liaisons M:N et 3 échantillons (1:1)
-- ====================================================================

-- 1. profil
INSERT INTO profil (nom_profil, peut_ecrire, peut_supprimer, description) VALUES
('administrateur', TRUE,  TRUE,  'Accès complet : consultation, saisie, modification et suppression'),
('scientifique',   TRUE,  FALSE, 'Consultation, saisie et modification des données scientifiques'),
('observateur',    FALSE, FALSE, 'Consultation seule des états et du réseau orbital');

-- 2. utilisateur (mots de passe jamais stockés en clair : utilisation de md5())
-- Note pédagogique : md5() est utilisé ici conformément à l'exemple du cours PostgreSQL.
-- En production réelle, on privilégierait un algorithme lent et salé (Argon2 / bcrypt).
INSERT INTO utilisateur (username, nom_complet, password_hash, id_profil) VALUES
('tlenfant', 'Thomas Lenfant',         md5('password'),   1),
('admin',    'Administrateur Mission', md5('admin123'),   1),
('s.curie',  'Sophie Curie',           md5('science123'), 2),
('invite',   'Observateur Public',     md5('invite123'),  3);

-- 3. corps_celeste (sommets du graphe orbital)
INSERT INTO corps_celeste (nom, type_corps, distance_soleil_ua) VALUES
('Terre',            'Planète tellurique', 1.000),
('Mars',             'Planète tellurique', 1.524),
('Lune',             'Lune tellurique',    1.000),
('Titan',            'Lune glacée',        9.582),
('Europe',           'Lune glacée',        5.204),
('Encelade',         'Lune glacée',        9.537),
('67P/Tchourioumov', 'Comète',             3.463);

-- 4. trajectoire_orbitale (graphe orienté, pondéré, avec liaisons à double sens)
-- IDs corps_celeste : 1=Terre, 2=Mars, 3=Lune, 4=Titan, 5=Europe, 6=Encelade, 7=67P
INSERT INTO trajectoire_orbitale (
    id_corps_depart, id_corps_arrivee, delta_v_ms, duree_jours, type_transfert
) VALUES
-- Double sens asymétrique Terre <-> Lune (retour moins coûteux grâce à l'aérofreinage)
(1, 3, 13200.00,    3.0, 'Injection translunaire et alunissage'),
(3, 1,  2800.00,    3.0, 'Retour balistique avec aérofreinage'),
-- Double sens asymétrique Terre <-> Mars
(1, 2, 13600.00,  210.0, 'Transfert de Hohmann aller'),
(2, 1,  6300.00,  210.0, 'Retour martien avec aérofreinage'),
-- Relais lunaire vers Mars (sens unique)
(3, 2,  4800.00,  215.0, 'Transfert interplanétaire depuis orbite lunaire'),
-- Choix multi-critères vers Europe : direct moins cher en delta-v, via Mars plus rapide en jours
(1, 5, 16500.00, 1800.0, 'Transfert direct vers système jovien'),
(2, 5,  5200.00,  950.0, 'Assistance gravitationnelle martienne'),
-- Poursuite vers le système saturnien (Titan <-> Encelade à double sens)
(5, 4,  4200.00, 1100.0, 'Transfert Jupiter vers Saturne'),
(4, 6,  1900.00,   18.0, 'Transfert intra-saturnien aller'),
(6, 4,  1850.00,   18.0, 'Transfert intra-saturnien retour'),
-- Mission cométaire (sens unique)
(1, 7, 14100.00, 3650.0, 'Assistance gravitationnelle multiple');

-- 5. mission (id_corps : 2=Mars, 3=Lune, 4=Titan, 5=Europe, 7=67P ; Terre et Encelade sans mission cible)
INSERT INTO mission (nom_mission, agence_spatiale, statut, id_corps, id_responsable) VALUES
('Mars 2020 (Perseverance)', 'NASA',       'Opérationnelle', 2, 3),
('Curiosity (MSL)',          'NASA',       'Opérationnelle', 2, 3),
('Cassini-Huygens',          'NASA / ESA', 'Terminée',       4, 1),
('Rosetta / Philae',         'ESA',        'Terminée',       7, 1),
('Artemis III',              'NASA / ESA', 'En préparation', 3, 2),
('JUICE',                    'ESA',        'En transit',     5, 3);

-- 6. instrument_scientifique
INSERT INTO instrument_scientifique (nom_instrument, type_mesure) VALUES
('SuperCam',  'Spectrométrie laser & Raman'),
('Mastcam-Z', 'Imagerie couleur stéréoscopique'),
('PIXL',      'Fluorescence X haute précision'),
('ChemCam',   'Spectroscopie laser LIBS'),
('ROLIS',     'Caméra de descente et surface'),
('JANUS',     'Caméra optique multispectrale');

-- 7. mission_instrument (Relation M:N : plusieurs instruments par mission et Mastcam-Z partagé)
INSERT INTO mission_instrument (id_mission, id_instrument, role) VALUES
(1, 1, 'Minéralogie laser à distance'),
(1, 2, 'Stéréophotographie multispectrale'),
(1, 3, 'Analyse élémentaire microscopique'),
(2, 4, 'Composition chimique des roches'),
(4, 5, 'Imagerie in-situ du sol cométaire'),
(5, 2, 'Imagerie stéréoscopique du pôle Sud lunaire'),
(6, 6, 'Cartographie optique globale');

-- 8. echantillon (Relation 1:1 : au plus 1 échantillon par mission ; Artemis III #5 reste disponible)
INSERT INTO echantillon (code_tube, type_roche, masse_grammes, id_mission) VALUES
('PER-01-ROU', 'Basalte magmatique à olivine',     8.24, 1),
('MSL-01-CUM', 'Smectite argileuse hydratée',      1.25, 2),
('ROS-01-COM', 'Glace d''eau et carbone organique', 0.12, 4);
