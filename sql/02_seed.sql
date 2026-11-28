-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
-- Fichier : 02_seed.sql
-- Description : Jeu de données généré fidèlement depuis les 2 CSV de data/
--   - corps_celeste : 9 planètes (aidb-solar-system-planets.csv) +
--     6 cibles réelles issues de aidb-lunar-and-planetary-missions.csv
--   - mission : les 279 vraies missions du CSV (aucune mission inventée)
--   - Tables absentes des CSV (consignes du cours) : profil, utilisateur
--     (md5), trajectoire_orbitale (graphe), instrument_scientifique,
--     mission_instrument (M:N) et echantillon (1:1 sur missions réelles)
-- Régénération : uv run python import_csv.py --generate-seed
-- ====================================================================

-- 1. profil
INSERT INTO profil (nom_profil, peut_ecrire, peut_supprimer, description) VALUES
('administrateur', TRUE,  TRUE,  'Accès complet : consultation, saisie, modification et suppression'),
('scientifique',   TRUE,  FALSE, 'Consultation, saisie et modification des données scientifiques'),
('observateur',    FALSE, FALSE, 'Consultation seule des états et du réseau orbital');

-- 2. utilisateur (mots de passe jamais en clair : empreinte md5())
INSERT INTO utilisateur (username, nom_complet, password_hash, id_profil) VALUES
('tlenfant', 'Thomas Lenfant',         md5('password'),   1),
('admin',    'Administrateur Mission', md5('admin123'),   1),
('s.curie',  'Sophie Curie',           md5('science123'), 2),
('invite',   'Observateur Public',     md5('invite123'),  3);

-- 3. corps_celeste (100 % issu des 2 CSV de data/ : 9 planètes + 6 cibles)
INSERT INTO corps_celeste (
    nom, code_wikidata, type_corps, distance_soleil_ua, diametre_km,
    masse_kg, gravite_m_s2, vitesse_liberation_km_s, periode_orbitale_jours,
    temperature_moyenne_c, nb_lunes, a_des_anneaux, champ_magnetique,
    date_decouverte
) VALUES
('Mercury', 'Q308', 'Planet', 0.387, 4879.0, 3.3e+23, 3.7, 4.3, 88.0, 167.0, 0, FALSE, TRUE, NULL),
('Venus', 'Q313', 'Planet', 0.7233, 12104.0, 4.87e+24, 8.9, 10.4, 224.7, 464.0, 0, FALSE, FALSE, NULL),
('Earth', 'Q2', 'Planet', 1.0, 12756.0, 5.97e+24, 9.8, 11.2, 365.2, 15.0, 1, FALSE, TRUE, NULL),
('Mars', 'Q111', 'Planet', 1.524, 6792.0, 6.42e+23, 3.7, 5.0, 687.0, -65.0, 2, FALSE, FALSE, NULL),
('Jupiter', 'Q319', 'Planet', 5.204, 142984.0, 1.898e+27, 23.1, 59.5, 4331.0, -110.0, 95, TRUE, TRUE, NULL),
('Saturn', 'Q193', 'Planet', 9.572, 120536.0, 5.68e+26, 9.0, 35.5, 10747.0, -140.0, 274, TRUE, TRUE, NULL),
('Uranus', 'Q324', 'Planet', 19.16, 51118.0, 8.68e+25, 8.7, 21.3, 30589.0, -195.0, 28, TRUE, TRUE, '1781-03-13'),
('Neptune', 'Q332', 'Planet', 30.18, 49528.0, 1.02e+26, 11.0, 23.5, 59800.0, -200.0, 16, TRUE, TRUE, '1846-09-23'),
('Pluto', 'Q339', 'Dwarf planet', 39.48, 2376.0, 1.3e+22, 0.6, 1.2, 90560.0, -225.0, 5, FALSE, NULL, '1930-02-18'),
('Moon', NULL, 'Moon', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
('Comet', NULL, 'Small body', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
('Asteroid', NULL, 'Small body', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
('Titan', NULL, 'Moon', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
('Sun', NULL, 'Star', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
('Ganymede', NULL, 'Moon', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- 4. trajectoire_orbitale (graphe orienté et pondéré, double sens autorisé)
-- Tous les sommets proviennent exclusivement des corps célestes des 2 CSV.
INSERT INTO trajectoire_orbitale (
    id_corps_depart, id_corps_arrivee, delta_v_ms, duree_jours, type_transfert
)
SELECT cd.id_corps, ca.id_corps, v.delta_v_ms, v.duree_jours, v.type_transfert
FROM (VALUES
    -- Double sens asymétrique Earth <-> Moon
    ('Earth',    'Moon',     13200.00,    3.0, 'Injection translunaire et alunissage'),
    ('Moon',     'Earth',     2800.00,    3.0, 'Retour balistique avec aérofreinage'),
    -- Double sens asymétrique Earth <-> Mars
    ('Earth',    'Mars',     13600.00,  210.0, 'Transfert de Hohmann aller'),
    ('Mars',     'Earth',     6300.00,  210.0, 'Retour martien avec aérofreinage'),
    -- Double sens asymétrique Earth <-> Venus
    ('Earth',    'Venus',    12800.00,  146.0, 'Transfert de Hohmann vers Vénus'),
    ('Venus',    'Earth',    10500.00,  146.0, 'Retour vénusien avec aérofreinage'),
    -- Double sens asymétrique Saturn <-> Titan
    ('Saturn',   'Titan',     1800.00,   16.0, 'Insertion orbitale saturnienne vers Titan'),
    ('Titan',    'Saturn',    2100.00,   16.0, 'Remontée orbitale de Titan vers Saturne'),
    -- Liaisons orientées stratégiques (optimisation multi-critères Dijkstra)
    ('Moon',     'Mars',      4800.00,  215.0, 'Transfert interplanétaire depuis orbite lunaire'),
    ('Venus',    'Mercury',   5100.00,  105.0, 'Assistance gravitationnelle vénusienne'),
    ('Earth',    'Jupiter',  16500.00, 1800.0, 'Transfert direct vers système jovien'),
    ('Mars',     'Jupiter',   5200.00,  950.0, 'Assistance gravitationnelle martienne'),
    ('Jupiter',  'Ganymede',  2600.00,    7.0, 'Capture orbitale autour de Ganymède'),
    ('Jupiter',  'Saturn',    4200.00, 1100.0, 'Assistance gravitationnelle jovienne'),
    ('Saturn',   'Uranus',    3900.00, 1800.0, 'Transfert système externe vers Uranus'),
    ('Uranus',   'Neptune',   3200.00, 1500.0, 'Transfert système externe vers Neptune'),
    ('Jupiter',  'Pluto',     5800.00, 2900.0, 'Trajectoire hyperbolique type New Horizons'),
    ('Earth',    'Asteroid', 12900.00,  450.0, 'Rendez-vous géocroiseur (Bennu / Ryugu)'),
    ('Earth',    'Comet',    14100.00, 3650.0, 'Assistance gravitationnelle cométaire')
) AS v(depart, arrivee, delta_v_ms, duree_jours, type_transfert)
INNER JOIN corps_celeste cd ON cd.nom = v.depart
INNER JOIN corps_celeste ca ON ca.nom = v.arrivee;

-- 5. mission (100 % issu de data/aidb-lunar-and-planetary-missions.csv : 279 missions)
INSERT INTO mission (
    nom_mission, date_lancement, pays_operateur, type_mission,
    tentative, echec_lancement, lanceur, masse_kg, id_corps
)
SELECT
    v.nom_mission, v.date_lancement::DATE, v.pays_operateur, v.type_mission,
    v.tentative, v.echec_lancement, v.lanceur, v.masse_kg, c.id_corps
FROM (VALUES
    ('Sputnik 1', '1957-10-04', 'Soviet Union', 'Earth Orbiter', FALSE, FALSE, NULL, NULL, 'Earth'),
    ('Sputnik 2', '1957-11-03', 'Soviet Union', 'Earth Orbiter', FALSE, FALSE, NULL, NULL, 'Earth'),
    ('Vanguard TV3', '1957-12-06', 'United States', 'Attempted Earth Orbiter', TRUE, TRUE, NULL, NULL, 'Earth'),
    ('Explorer 1', '1958-02-01', 'United States', 'Earth Orbiter', FALSE, FALSE, NULL, NULL, 'Earth'),
    ('Vanguard 1', '1958-03-17', 'United States', 'Earth Orbiter', FALSE, FALSE, NULL, NULL, 'Earth'),
    ('Pioneer 0', '1958-08-17', 'United States', 'Attempted Lunar Orbit', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1958A', '1958-09-23', 'Soviet Union', 'Attempted Lunar Impact?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Pioneer 1', '1958-10-11', 'United States', 'Attempted Lunar Orbit', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1958B', '1958-10-12', 'Soviet Union', 'Attempted Lunar Impact?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Pioneer 2', '1958-11-08', 'United States', 'Attempted Lunar Orbit', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1958C', '1958-12-04', 'Soviet Union', 'Attempted Lunar Impact?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Pioneer 3', '1958-12-06', 'United States', 'Attempted Lunar Flyby', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1', '1959-01-02', 'Soviet Union', 'Lunar Flyby (Attempted Lunar Impact?)', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Pioneer 4', '1959-03-03', 'United States', 'Lunar Flyby', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 1959A', '1959-06-16', 'Soviet Union', 'Attempted Lunar Impact?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 2', '1959-09-12', 'Soviet Union', 'Lunar Impact', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 3', '1959-10-04', 'Soviet Union', 'Lunar Flyby', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Pioneer P-3', '1959-11-26', 'United States', 'Attempted Lunar Orbiter', TRUE, TRUE, 'Atlas-Able', 168.7, 'Moon'),
    ('Luna 1960A', '1960-04-15', 'Soviet Union', 'Attempted Lunar Flyby', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1960B', '1960-04-18', 'Soviet Union', 'Attempted Lunar Flyby', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Mars 1960A', '1960-10-10', 'Soviet Union', 'Attempted Mars Flyby', TRUE, TRUE, NULL, NULL, 'Mars'),
    ('Mars 1960B', '1960-10-14', 'Soviet Union', 'Attempted Mars Flyby', TRUE, TRUE, NULL, NULL, 'Mars'),
    ('Pioneer P-31', '1960-12-15', 'United States', 'Attempted Lunar Orbiter', TRUE, TRUE, 'Atlas-Able', 175.0, 'Moon'),
    ('Sputnik 7', '1961-02-04', 'Soviet Union', 'Attempted Venus Impact', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 1', '1961-02-12', 'Soviet Union', 'Venus Flyby (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Ranger 1', '1961-08-23', 'United States', 'Attempted Lunar Test Flight', TRUE, FALSE, 'Atlas-Agena B', 306.2, 'Moon'),
    ('Ranger 2', '1961-11-18', 'United States', 'Attempted Lunar Test Flight', TRUE, FALSE, 'Atlas-Agena B', 304.0, 'Moon'),
    ('Ranger 3', '1962-01-26', 'United States', 'Attempted Lunar Impact', TRUE, FALSE, 'Atlas-Agena B', 329.8, 'Moon'),
    ('Ranger 4', '1962-04-23', 'United States', 'Lunar Impact', FALSE, FALSE, 'Atlas-Agena B', 331.1, 'Moon'),
    ('Mariner 1', '1962-07-22', 'United States', 'Attempted Venus Flyby', TRUE, TRUE, 'Atlas-Agena B', 202.8, 'Venus'),
    ('Sputnik 19', '1962-08-25', 'Soviet Union', 'Attempted Venus Flyby', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Mariner 2', '1962-08-27', 'United States', 'Venus Flyby', FALSE, FALSE, 'Atlas-Agena B', 202.8, 'Venus'),
    ('Sputnik 20', '1962-09-01', 'Soviet Union', 'Attempted Venus Flyby', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Sputnik 21', '1962-09-12', 'Soviet Union', 'Attempted Venus Flyby', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Ranger 5', '1962-10-18', 'United States', 'Attempted Lunar Impact', TRUE, FALSE, 'Atlas-Agena B', 342.5, 'Moon'),
    ('Sputnik 22', '1962-10-24', 'Soviet Union', 'Attempted Mars Flyby', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 1', '1962-11-01', 'Soviet Union', 'Mars Flyby (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Sputnik 24', '1962-11-04', 'Soviet Union', 'Attempted Mars Lander', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Sputnik 25', '1963-01-04', 'Soviet Union', 'Attempted Lunar Lander', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 1963B', '1963-02-02', 'Soviet Union', 'Attempted Lunar Lander', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 4', '1963-04-02', 'Soviet Union', 'Attempted Lunar Lander', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Cosmos 21', '1963-11-11', 'Soviet Union', 'Attempted Venera Test Flight?', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Ranger 6', '1964-01-30', 'United States', 'Lunar Impact (Cameras Failed)', FALSE, FALSE, 'Atlas-Agena B', 381.0, 'Moon'),
    ('Venera 1964A', '1964-02-19', 'Soviet Union', 'Attempted Venus Flyby', TRUE, TRUE, NULL, NULL, 'Venus'),
    ('Venera 1964B', '1964-03-01', 'Soviet Union', 'Attempted Venus Flyby', TRUE, TRUE, NULL, NULL, 'Venus'),
    ('Luna 1964A', '1964-03-21', 'Soviet Union', 'Attempted Lunar Lander', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Cosmos 27', '1964-03-27', 'Soviet Union', 'Attempted Venus Flyby', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Zond 1', '1964-04-02', 'Soviet Union', 'Venus Flyby (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Luna 1964B', '1964-04-20', 'Soviet Union', 'Attempted Lunar Lander', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Zond 1964A', '1964-06-04', 'Soviet Union', 'Attempted Lunar Lander', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Ranger 7', '1964-07-28', 'United States', 'Lunar Impact', FALSE, FALSE, 'Atlas-Agena B', 365.7, 'Moon'),
    ('Mariner 3', '1964-11-05', 'United States', 'Attempted Mars Flyby', TRUE, FALSE, 'Atlas-Agena D', 260.8, 'Mars'),
    ('Mariner 4', '1964-11-28', 'United States', 'Mars Flyby', FALSE, FALSE, 'Atlas-Agena D', 260.68, 'Mars'),
    ('Zond 2', '1964-11-30', 'Soviet Union', 'Mars Flyby (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Ranger 8', '1965-02-17', 'United States', 'Lunar Impact', FALSE, FALSE, 'Atlas-Agena B', 367.0, 'Moon'),
    ('Cosmos 60', '1965-03-12', 'Soviet Union', 'Attempted Lunar Lander', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Ranger 9', '1965-03-21', 'United States', 'Lunar Impact', FALSE, FALSE, 'Atlas-Agena B', 367.0, 'Moon'),
    ('Luna 1965A', '1965-04-10', 'Soviet Union', 'Attempted Lunar Lander?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 5', '1965-05-09', 'Soviet Union', 'Lunar Impact (Attempted Soft Landing)', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 6', '1965-06-08', 'Soviet Union', 'Attempted Lunar Lander', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Zond 3', '1965-07-18', 'Soviet Union', 'Lunar Flyby', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 7', '1965-10-04', 'Soviet Union', 'Lunar Impact (Attempted Soft Landing)', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Venera 2', '1965-11-12', 'Soviet Union', 'Venus Flyby (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 3', '1965-11-16', 'Soviet Union', 'Venus Lander (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Cosmos 96', '1965-11-23', 'Soviet Union', 'Attempted Venus Lander?', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 1965A', '1965-11-23', 'Soviet Union', 'Attempted Venus Flyby', TRUE, TRUE, NULL, NULL, 'Venus'),
    ('Luna 8', '1965-12-03', 'Soviet Union', 'Lunar Impact (Attempted Soft Landing?)', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 9', '1966-01-31', 'Soviet Union', 'Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Cosmos 111', '1966-03-01', 'Soviet Union', 'Attempted Lunar Orbiter?', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 10', '1966-03-31', 'Soviet Union', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 1966A', '1966-04-30', 'Soviet Union', 'Attempted Lunar Orbiter?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Surveyor 1', '1966-05-30', 'United States', 'Lunar Lander', FALSE, FALSE, 'Atlas-Centaur', 294.3, 'Moon'),
    ('Explorer 33', '1966-07-01', 'United States', 'Attempted Lunar Orbiter', TRUE, FALSE, 'Delta', 93.4, 'Moon'),
    ('Lunar Orbiter 1', '1966-08-10', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Atlas-Agena D', 385.6, 'Moon'),
    ('Luna 11', '1966-08-24', 'Soviet Union', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Surveyor 2', '1966-09-20', 'United States', 'Attempted Lunar Lander', TRUE, FALSE, 'Atlas-Centaur', 292.0, 'Moon'),
    ('Luna 12', '1966-10-22', 'Soviet Union', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Lunar Orbiter 2', '1966-11-06', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Atlas-Agena D', 385.6, 'Moon'),
    ('Luna 13', '1966-12-21', 'Soviet Union', 'Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Lunar Orbiter 3', '1967-02-04', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Atlas-Agena D', 385.6, 'Moon'),
    ('Surveyor 3', '1967-04-17', 'United States', 'Lunar Lander', FALSE, FALSE, 'Atlas-Centaur', 296.0, 'Moon'),
    ('Lunar Orbiter 4', '1967-05-08', 'United States', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Venera 4', '1967-06-12', 'Soviet Union', 'Venus Probe', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Mariner 5', '1967-06-14', 'United States', 'Venus Flyby', FALSE, FALSE, 'Atlas-Agena D', 244.9, 'Venus'),
    ('Cosmos 167', '1967-06-17', 'Soviet Union', 'Attempted Venus Probe', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Surveyor 4', '1967-07-14', 'United States', 'Attempted Lunar Lander', TRUE, FALSE, 'Atlas-Centaur', 283.0, 'Moon'),
    ('Explorer 35 (IMP-E)', '1967-07-19', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Thrust Augmented Delta', 93.5, 'Moon'),
    ('Lunar Orbiter 5', '1967-08-01', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Atlas-Agena D', 385.6, 'Moon'),
    ('Surveyor 5', '1967-09-08', 'United States', 'Lunar Lander', FALSE, FALSE, 'Atlas-Centaur', 303.0, 'Moon'),
    ('Zond 1967A', '1967-09-28', 'Soviet Union', 'Attempted Lunar Test Flight', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Surveyor 6', '1967-11-07', 'United States', 'Lunar Lander', FALSE, FALSE, 'Atlas-Centaur', 299.6, 'Moon'),
    ('Zond 1967B', '1967-11-22', 'Soviet Union', 'Attempted Lunar Test Flight', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Surveyor 7', '1968-01-07', 'United States', 'Lunar Lander', FALSE, FALSE, 'Atlas-Centaur', 305.7, 'Moon'),
    ('Luna 1968A', '1968-02-07', 'Soviet Union', 'Attempted Lunar Orbiter', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Zond 4', '1968-03-02', 'Soviet Union', 'Test Flight', FALSE, FALSE, NULL, NULL, NULL),
    ('Luna 14', '1968-04-07', 'Soviet Union', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Zond 1968A', '1968-04-23', 'Soviet Union', 'Attempted Lunar Test Flight?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Zond 5', '1968-09-15', 'Soviet Union', 'Lunar Flyby and Return to Earth', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Zond 6', '1968-11-10', 'Soviet Union', 'Lunar Flyby and Return to Earth', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Apollo 8', '1968-12-21', 'United States', 'Crewed Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Venera 5', '1969-01-05', 'Soviet Union', 'Venus Probe', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 6', '1969-01-10', 'Soviet Union', 'Venus Probe', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Zond 1969A', '1969-01-20', 'Soviet Union', 'Attempted Lunar Flyby and Return', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1969A', '1969-02-19', 'Soviet Union', 'Attempted Lunar Rover?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Zond L1S-1', '1969-02-21', 'Soviet Union', 'Attempted Lunar Orbiter', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Mariner 6', '1969-02-25', 'United States', 'Mars Flyby', FALSE, FALSE, 'Atlas-Centaur', 411.8, 'Mars'),
    ('Mariner 7', '1969-03-27', 'United States', 'Mars Flyby', FALSE, FALSE, 'Atlas-Centaur', 411.8, 'Mars'),
    ('Mars 1969A', '1969-03-27', 'Soviet Union', 'Attempted Mars Orbiter', TRUE, TRUE, NULL, NULL, 'Mars'),
    ('Mars 1969B', '1969-04-02', 'Soviet Union', 'Attempted Mars Orbiter', TRUE, TRUE, NULL, NULL, 'Mars'),
    ('Luna 1969B', '1969-04-15', 'Soviet Union', 'Attempted Lunar Sample Return?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Apollo 10', '1969-05-18', 'United States', 'Crewed Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 1969C', '1969-06-14', 'Soviet Union', 'Attempted Lunar Sample Return?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Zond L1S-2', '1969-07-03', 'Soviet Union', 'Attempted Lunar Orbiter', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 15', '1969-07-13', 'Soviet Union', 'Lunar Orbiter (Attempted Lunar Lander?)', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Apollo 11', '1969-07-16', 'United States', 'Crewed Lunar Landing', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Zond 7', '1969-08-07', 'Soviet Union', 'Lunar Flyby and Return to Earth', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Cosmos 300', '1969-09-23', 'Soviet Union', 'Attempted Lunar Sample Return?', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Cosmos 305', '1969-10-22', 'Soviet Union', 'Attempted Lunar Sample Return?', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Apollo 12', '1969-11-14', 'United States', 'Crewed Lunar Landing', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 1970A', '1970-02-06', 'Soviet Union', 'Attempted Lunar Sample Return?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Luna 1970B', '1970-02-19', 'Soviet Union', 'Attempted Lunar Orbiter?', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Apollo 13', '1970-04-11', 'United States', 'Crewed Lunar Mission (Landing Aborted)', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Venera 7', '1970-08-17', 'Soviet Union', 'Venus Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Cosmos 359', '1970-08-22', 'Soviet Union', 'Attempted Venus Probe', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Luna 16', '1970-09-12', 'Soviet Union', 'Lunar Sample Return', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Zond 8', '1970-10-20', 'Soviet Union', 'Lunar Flyby and Return to Earth', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 17/Lunokhod 1', '1970-11-10', 'Soviet Union', 'Lunar Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Apollo 14', '1971-01-31', 'United States', 'Crewed Lunar Landing', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Mariner 8', '1971-05-09', 'United States', 'Attempted Mars Flyby', TRUE, TRUE, 'Atlas-Centaur', 558.8, 'Mars'),
    ('Cosmos 419', '1971-05-10', 'Soviet Union', 'Attempted Mars Orbiter/Lander', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 2', '1971-05-19', 'Soviet Union', 'Mars Orbiter/ Attempted Lander', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 3', '1971-05-28', 'Soviet Union', 'Mars Orbiter/ Lander', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Mariner 9', '1971-05-30', 'United States', 'Mars Orbiter', FALSE, FALSE, 'Atlas-Centaur', 558.8, 'Mars'),
    ('Apollo 15', '1971-07-26', 'United States', 'Crewed Lunar Landing', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 18', '1971-09-02', 'Soviet Union', 'Attempted Lunar Sample Return', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 19', '1971-09-28', 'Soviet Union', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 20', '1972-02-14', 'Soviet Union', 'Lunar Sample Return', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Pioneer 10', '1972-03-03', 'United States', 'Jupiter Flyby', FALSE, FALSE, 'Atlas-Centaur', 258.0, 'Jupiter'),
    ('Venera 8', '1972-03-27', 'Soviet Union', 'Venus Probe', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Cosmos 482', '1972-03-31', 'Soviet Union', 'Attempted Venus Probe', TRUE, FALSE, NULL, NULL, 'Venus'),
    ('Apollo 16', '1972-04-16', 'United States', 'Crewed Lunar Landing', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Soyuz L3', '1972-11-23', 'Soviet Union', 'Attempted Lunar Orbiter', TRUE, TRUE, NULL, NULL, 'Moon'),
    ('Apollo 17', '1972-12-07', 'United States', 'Crewed Lunar Landing', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 21/Lunokhod 2', '1973-01-08', 'Soviet Union', 'Lunar Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Pioneer 11', '1973-04-05', 'United States', 'Jupiter/Saturn Flyby', FALSE, FALSE, 'Atlas-Centaur', 259.0, 'Jupiter'),
    ('Skylab', '1973-05-14', 'United States', 'Crewed Earth Orbiter', FALSE, FALSE, 'Saturn 5', 90607.0, 'Earth'),
    ('Explorer 49 (RAE-B)', '1973-06-10', 'United States', 'Lunar Orbiter/Radio Astronomy', FALSE, FALSE, 'Delta', 328.0, 'Moon'),
    ('Mars 4', '1973-07-21', 'Soviet Union', 'Mars Flyby (Attempted Mars Orbiter)', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 5', '1973-07-25', 'Soviet Union', 'Mars Orbiter', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 6', '1973-08-05', 'Soviet Union', 'Mars Lander (Contact Lost)', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 7', '1973-08-09', 'Soviet Union', 'Mars Flyby (Attempted Mars Lander)', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mariner 10', '1973-11-04', 'United States', 'Venus/Mercury Flybys', FALSE, FALSE, 'Atlas-Centaur', 473.9, 'Venus'),
    ('Luna 22', '1974-06-02', 'Soviet Union', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 23', '1974-10-28', 'Soviet Union', 'Attempted Lunar Sample Return', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Venera 9', '1975-06-08', 'Soviet Union', 'Venus Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 10', '1975-06-14', 'Soviet Union', 'Venus Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Viking 1', '1975-08-20', 'United States', 'Mars Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Viking 2', '1975-09-09', 'United States', 'Mars Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Luna 1975A', '1975-10-16', 'Soviet Union', 'Attempted Lunar Sample Return?', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 24', '1976-08-09', 'Soviet Union', 'Lunar Sample Return', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Voyager 2', '1977-08-20', 'United States', 'Jupiter/Saturn/Uranus/Neptune Flyby', FALSE, FALSE, 'Titan IIIE-Centaur', 721.9, 'Jupiter'),
    ('Voyager 1', '1977-09-05', 'United States', 'Jupiter/Saturn Flyby', FALSE, FALSE, 'Titan IIIE-Centaur', 721.9, 'Jupiter'),
    ('Pioneer Venus 1', '1978-05-20', 'United States', 'Venus Orbiter', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Pioneer Venus 2', '1978-08-08', 'United States', 'Venus Probes', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('ISEE-3/ICE', '1978-08-12', 'United States', 'Comet Giacobini-Zinner and Halley Flybys', FALSE, FALSE, 'Delta', 390.0, 'Comet'),
    ('Venera 11', '1978-09-09', 'Soviet Union', 'Venus Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 12', '1978-09-14', 'Soviet Union', 'Venus Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 13', '1981-10-30', 'Soviet Union', 'Venus Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 14', '1981-11-04', 'Soviet Union', 'Venus Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 15', '1983-06-02', 'Soviet Union', 'Venus Orbiter', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Venera 16', '1983-06-07', 'Soviet Union', 'Venus Orbiter', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Vega 1', '1984-12-15', 'Soviet Union', 'Venus Lander and Balloon/Comet Halley Flyby', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Vega 2', '1984-12-21', 'Soviet Union', 'Venus Lander and Balloon/Comet Halley Flyby', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Sakigake', '1985-01-07', 'Japan', 'Comet Halley Flyby', FALSE, FALSE, NULL, NULL, 'Comet'),
    ('Giotto', '1985-07-02', 'European Space Agency', 'Comet Halley Flyby', FALSE, FALSE, NULL, NULL, 'Comet'),
    ('Suisei (Planet-A)', '1985-08-18', 'Japan', 'Comet Halley Flyby', FALSE, FALSE, NULL, NULL, 'Comet'),
    ('Phobos 1', '1988-07-07', 'Soviet Union', 'Attempted Mars Orbiter/Phobos Lander', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Phobos 2', '1988-07-12', 'Soviet Union', 'Mars Orbiter/Attempted Phobos Lander', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Magellan', '1989-05-04', 'United States', 'Venus Orbiter', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Galileo', '1989-10-18', 'United States', 'Jupiter Orbiter and Probe', FALSE, FALSE, NULL, NULL, 'Jupiter'),
    ('Hiten', '1990-01-24', 'Japan', 'Lunar Flyby and Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Hubble Space Telescope', '1990-04-25', 'United States', 'Earth Orbiting Observatory', FALSE, FALSE, NULL, NULL, 'Earth'),
    ('Ulysses', '1990-10-06', 'European Space Agency', 'Jupiter Flyby and Solar Polar Orbiter', FALSE, FALSE, NULL, NULL, 'Jupiter'),
    ('Mars Observer', '1992-09-25', 'United States', 'Attempted Mars Orbiter (Contact Lost)', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Clementine', '1994-01-25', 'United States', 'Lunar Orbiter/Attempted Asteroid Flyby', TRUE, FALSE, NULL, NULL, 'Moon'),
    ('NEAR', '1996-02-17', 'United States', 'Asteroid Eros Orbiter', FALSE, FALSE, 'Delta II 7925', 487.0, 'Asteroid'),
    ('Mars Global Surveyor', '1996-11-07', 'United States', 'Mars Orbiter', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 96', '1996-11-16', 'Russia', 'Attempted Mars Orbiter/Landers', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mars Pathfinder', '1996-12-04', 'United States', 'Mars Lander and Rover', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Cassini', '1997-10-15', 'United States', 'Saturn Orbiter', FALSE, FALSE, NULL, NULL, 'Saturn'),
    ('Huygens', '1997-10-15', 'European Space Agency', 'Titan Probe', FALSE, FALSE, NULL, NULL, 'Titan'),
    ('AsiaSat 3/HGS-1', '1997-12-24', 'United States', 'Lunar Flyby', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Lunar Prospector', '1998-01-07', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Athena 2', 158.7, 'Moon'),
    ('Nozomi (Planet-B)', '1998-07-03', 'Japan', 'Mars Orbiter', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Deep Space 1 (DS1)', '1998-10-24', 'United States', 'Asteroid and Comet Flyby', FALSE, FALSE, 'Delta II 7326', 373.7, 'Asteroid'),
    ('Mars Climate Orbiter', '1998-12-11', 'United States', 'Attempted Mars Orbiter', TRUE, FALSE, 'Delta II 7425', 338.0, 'Mars'),
    ('Mars Polar Lander', '1999-01-03', 'United States', 'Attempted Mars Lander', TRUE, FALSE, 'Delta II 7425', 290.0, 'Mars'),
    ('Deep Space 2 (DS2)', '1999-01-03', 'United States', 'Attempted Mars Penetrators', TRUE, FALSE, 'Delta II 7425', 3.57, 'Mars'),
    ('Stardust', '1999-02-07', 'United States', 'Comet Coma Sample Return', FALSE, FALSE, 'Delta II 7426', 300.0, 'Comet'),
    ('2001 Mars Odyssey', '2001-04-07', 'United States', 'Mars Orbiter', FALSE, FALSE, 'Delta II 7425', 376.3, 'Mars'),
    ('Genesis', '2001-08-08', 'United States', 'Solar Wind Sample Return', FALSE, FALSE, 'Delta II 7326', 494.0, 'Sun'),
    ('CONTOUR', '2002-07-03', 'United States', 'Fly-by of three Comet Nuclei', FALSE, FALSE, 'Delta II 7425', 328.0, 'Comet'),
    ('Hayabusa (Muses-C)', '2003-05-09', 'Japan', 'Asteroid Orbiter and Sample Return', FALSE, FALSE, NULL, NULL, 'Asteroid'),
    ('Mars Express', '2003-06-02', 'European Space Agency', 'Mars Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Spirit (MER-A)', '2003-06-10', 'United States', 'Mars Rover', FALSE, FALSE, 'Delta II 7925', 185.0, 'Mars'),
    ('Opportunity (MER-B)', '2003-07-08', 'United States', 'Mars Rover', FALSE, FALSE, 'Delta II 7925', 185.0, 'Mars'),
    ('Rosetta', '2004-03-02', 'European Space Agency', 'Comet Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Comet'),
    ('MESSENGER', '2004-08-03', 'United States', 'Mercury Orbiter', FALSE, FALSE, 'Delta II 7925', 485.2, 'Mercury'),
    ('Deep Impact', '2005-01-12', 'United States', 'Comet Rendezvous and Impact', FALSE, FALSE, 'Delta II', 650.0, 'Comet'),
    ('Mars Reconnaisance Orbiter', '2005-08-12', 'United States', 'Mars Orbiter', FALSE, FALSE, 'Atlas V 401', 1031.0, 'Mars'),
    ('Venus Express', '2005-11-09', 'European Space Agency', 'ESA Venus Orbiter', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('New Horizons', '2006-01-19', 'United States', 'Pluto/Charon and Kuiper Belt Flyby', FALSE, FALSE, 'Atlas V', 385.0, 'Pluto'),
    ('Phoenix', '2007-08-04', 'United States', 'Small Mars Scout Lander', FALSE, FALSE, 'Delta II', NULL, 'Mars'),
    ('Kaguya (SELENE)', '2007-09-14', 'Japan', 'Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Dawn', '2007-09-27', 'United States', 'Asteroid Ceres and Vesta Orbiter', FALSE, FALSE, 'Delta II 7925', 725.0, 'Asteroid'),
    ('Chang''e 1', '2007-10-24', 'China', 'CAST (China) Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Chandrayaan-1', '2008-10-22', 'India', 'ISRO (India) Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Kepler', '2009-03-07', 'United States', 'Extrasolar Terrestrial Planet Detection Mission', FALSE, FALSE, NULL, NULL, NULL),
    ('Lunar Reconnaissance Orbiter', '2009-06-18', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Atlas V 401', 500.0, 'Moon'),
    ('LCROSS', '2009-06-18', 'United States', 'Lunar Impactor', FALSE, FALSE, 'Atlas V 401', 534.0, 'Moon'),
    ('Akatsuki/Planet-C', '2010-05-20', 'Japan', 'ISAS Venus Orbiter', FALSE, FALSE, NULL, NULL, 'Venus'),
    ('Chang''e 2', '2010-10-01', 'China', 'CAST (China) Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Juno', '2011-08-05', 'United States', 'Jupiter Orbiter', FALSE, FALSE, 'Atlas V', 1500.0, 'Jupiter'),
    ('GRAIL', '2011-09-10', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Delta II', 132.6, 'Moon'),
    ('Phobos-Grunt', '2011-11-08', 'Russia', 'Attempted Martian Moon Phobos Lander', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Yinghuo-1', '2011-11-08', 'China', 'Attempted Mars Orbiter', TRUE, FALSE, NULL, NULL, 'Mars'),
    ('Mars Science Laboratory', '2011-11-26', 'United States', 'Mars Rover', FALSE, FALSE, 'Atlas V', 750.0, 'Mars'),
    ('LADEE', '2013-09-06', 'United States', 'Lunar Orbiter', FALSE, FALSE, 'Minotaur 5', 248.2, 'Moon'),
    ('Mangalyaan', '2013-11-05', 'India', 'ISRO (India) Mars Orbiter', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('MAVEN', '2013-11-18', 'United States', 'Mars Scout Mission Orbiter', FALSE, FALSE, 'Atlas V 401', NULL, 'Mars'),
    ('Chang''e 3', '2013-12-01', 'China', 'Lunar Lander and Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Chang''e 5 Test Vehicle', '2014-10-23', 'China', 'Lunar Flyby and Return', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Hayabusa 2', '2014-12-03', 'Japan', 'JAXA Asteroid Sample Return', FALSE, FALSE, NULL, NULL, 'Asteroid'),
    ('PROCYON', '2014-12-03', 'Japan', 'JAXA (Japan) Asteroid Flyby Mission', FALSE, FALSE, NULL, NULL, 'Asteroid'),
    ('ExoMars 2016', '2016-03-14', 'European Space Agency', 'ESA Mars Orbiter and Lander', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('OSIRIS-REx', '2016-09-08', 'United States', 'Sample Return Mission to Asteroid Bennu', FALSE, FALSE, 'Atlas V', 1528.0, 'Asteroid'),
    ('InSight', '2018-05-05', 'United States', 'Mars Lander', FALSE, FALSE, 'Atlas V 401', 360.0, 'Mars'),
    ('Queqiao', '2018-05-20', 'China', 'CNSA (China) Lunar Relay Satellite', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Parker Solar Probe', '2018-08-12', 'United States', 'Solar Orbiter - Venus Flybys', FALSE, FALSE, 'Delta IV', 685.0, 'Sun'),
    ('BepiColombo', '2018-10-19', 'European Space Agency', 'ESA and JAXA Mercury Orbiters', FALSE, FALSE, NULL, NULL, 'Mercury'),
    ('Chang''e 4', '2018-12-07', 'China', 'CNSA (China) Lunar Farside Lander and Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Beresheet', '2019-02-22', 'Israel', 'SpaceIL and IAI (Israel) Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Chandrayaan 2', '2019-07-22', 'India', 'ISRO (India) Moon Orbiter, Lander, and Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Solar Orbiter', '2020-02-10', 'European Space Agency', 'ESA solar orbiting mission', FALSE, FALSE, NULL, NULL, 'Sun'),
    ('Hope', '2020-07-19', 'United Arab Emirates', 'United Arab Emirates Mars Orbiter', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Tianwen 1', '2020-07-23', 'China', 'CNSA (China) Mars Orbiter and Rover', FALSE, FALSE, NULL, NULL, 'Mars'),
    ('Mars 2020', '2020-07-30', 'United States', 'Mars Rover and Rotorcraft', FALSE, FALSE, 'Atlas V', 1050.0, 'Mars'),
    ('Chang''e 5', '2020-11-23', 'China', 'CNSA (China) Lunar Sample Return Mission', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Q-PACE', '2021-01-17', 'United States', 'Microgravity Particle Collision Study CubeSat', FALSE, FALSE, 'LauncherOne', 3.0, NULL),
    ('Lucy', '2021-10-16', 'United States', 'Trojan Asteroid Flybys', FALSE, FALSE, 'Atlas V 401', 821.0, 'Asteroid'),
    ('Double Asteroid Redirection Test (DART)', '2021-11-24', 'United States', 'Asteroid Dimorphos Impactor', FALSE, FALSE, 'Falcon 9', 670.0, 'Asteroid'),
    ('LICIACube', '2021-11-24', 'Italy', 'Asteroid Dimorphos Imaging Cubesat', FALSE, FALSE, NULL, NULL, 'Asteroid'),
    ('James Webb Space Telescope', '2021-12-25', 'United States', 'L2 Orbiting Infrared Observatory', FALSE, FALSE, 'Ariane 5', 6500.0, 'Earth'),
    ('CAPSTONE', '2022-06-28', 'United States', 'Lunar Navigation Test Orbiter', FALSE, FALSE, 'Electron', 25.0, 'Moon'),
    ('Korea Pathfinder Lunar Orbiter (Danuri)', '2022-08-04', 'South Korea', 'KARI (South Korea) Lunar Orbiter', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('LunaH-Map', '2022-11-16', 'United States', 'Lunar Orbiting CubeSat', FALSE, FALSE, 'SLS Block 1 Crew', 14.0, 'Moon'),
    ('Lunar Ice Cube', '2022-11-16', 'United States', 'Lunar Orbiting CubeSat', FALSE, FALSE, 'SLS Block 1 Crew', 14.0, 'Moon'),
    ('NEA Scout', '2022-11-16', 'United States', 'Asteroid Flyby CubeSat', FALSE, FALSE, 'SLS Block 1 Crew', 14.0, 'Asteroid'),
    ('Lunar InfraRed imaging (LunIR)', '2022-11-16', 'United States', 'Lunar Flyby and Technology Test CubeSat', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('OMOTENASHI', '2022-11-16', 'Japan', 'JAXA (Japan) Lunar Lander CubeSat', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('EQUULEUS', '2022-11-16', 'Japan', 'JAXA (Japan) L2 Orbit Lunar CubeSat', FALSE, FALSE, NULL, NULL, 'Earth'),
    ('Artemis 1', '2022-11-16', 'United States', 'Lunar Test Flight', FALSE, FALSE, 'SLS Block 1 Crew', NULL, 'Moon'),
    ('Lunar Flashlight', '2022-12-11', 'United States', 'Lunar Orbiter CubeSat', FALSE, FALSE, 'Falcon 9 Full Thrust', 14.0, 'Moon'),
    ('Hakuto-R M1', '2022-12-11', 'Japan', 'Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('JUpiter ICy moons Explorer (JUICE)', '2023-04-14', 'European Space Agency', 'ESA Ganymede-Callisto-Europa multiple flyby mission', FALSE, FALSE, NULL, NULL, 'Ganymede'),
    ('Chandrayaan 3', '2023-07-14', 'India', 'ISRO (India) Lunar Orbiter, Lander, and Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Luna 25', '2023-08-10', 'Russia', 'Russian Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('SLIM', '2023-09-06', 'Japan', 'JAXA (Japan) Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Psyche', '2023-10-13', 'United States', 'Main Belt Asteroid Orbiter', FALSE, FALSE, 'Falcon 9 Heavy', 1400.0, 'Asteroid'),
    ('Peregrine Mission 1 (Astrobotic)', '2024-01-08', 'United States', 'Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Intuitive Machines 1 (Odysseus)', '2024-02-15', 'United States', 'Lunar Lander', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Queqiao 2', '2024-03-20', 'China', 'CNSA (China) Lunar Relay Satellite', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Chang''e 6', '2024-05-03', 'China', 'CNSA (China) Lunar Sample Return Mission', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Hera', '2024-10-07', 'European Space Agency', 'ESA mission to asteroids Didymos and Dimorphos', FALSE, FALSE, NULL, NULL, 'Asteroid'),
    ('Europa Clipper', '2024-10-14', 'United States', 'Jupiter Orbiter - Multiple Europa Flybys', FALSE, FALSE, NULL, NULL, 'Jupiter'),
    ('M2/Resilience', '2025-01-15', 'Japan', 'JAXA (Japan) Lunar Lander and Rover', FALSE, FALSE, NULL, NULL, 'Moon'),
    ('Blue Ghost 1 (Firefly)', '2025-01-15', 'United States', 'Lunar Lander', FALSE, FALSE, 'Falcon 9', NULL, 'Moon'),
    ('Intuitive Machines 2 (PRIME-1)', '2025-02-26', 'United States', 'Lunar Lander', FALSE, FALSE, 'Falcon 9', NULL, 'Moon'),
    ('Lunar Trailblazer', '2025-02-26', 'United States', 'Lunar Orbiting Small Satellite', FALSE, FALSE, 'Falcon 9', 200.0, 'Moon')
) AS v(
    nom_mission, date_lancement, pays_operateur, type_mission,
    tentative, echec_lancement, lanceur, masse_kg, nom_corps_cible
)
LEFT JOIN corps_celeste c ON c.nom = v.nom_corps_cible;

-- Affectation de responsables applicatifs sur quelques missions réelles phares du CSV
UPDATE mission SET id_responsable = (SELECT id_utilisateur FROM utilisateur WHERE username = 's.curie')
WHERE nom_mission IN ('Mars 2020', 'Mars Science Laboratory', 'JUpiter ICy moons Explorer (JUICE)');
UPDATE mission SET id_responsable = (SELECT id_utilisateur FROM utilisateur WHERE username = 'tlenfant')
WHERE nom_mission IN ('Cassini', 'Rosetta', 'Voyager 1');
UPDATE mission SET id_responsable = (SELECT id_utilisateur FROM utilisateur WHERE username = 'admin')
WHERE nom_mission IN ('Artemis 1', 'Chang''e 5');

-- 6. instrument_scientifique (catégorie absente des CSV — équipements réels)
INSERT INTO instrument_scientifique (nom_instrument, type_mesure) VALUES
('SuperCam',      'Spectrométrie laser & Raman'),
('Mastcam-Z',     'Imagerie couleur stéréoscopique'),
('PIXL',          'Fluorescence X haute précision'),
('ChemCam',       'Spectroscopie laser LIBS'),
('ROLIS',         'Caméra de descente et surface'),
('JANUS',         'Caméra optique multispectrale'),
('Magnétomètre',  'Mesure des champs magnétiques planétaires');

-- 7. mission_instrument (Association M:N sur de vraies missions du CSV)
INSERT INTO mission_instrument (id_mission, id_instrument, role)
SELECT m.id_mission, i.id_instrument, v.role
FROM (VALUES
    ('Mars 2020',                           'SuperCam',     'Minéralogie laser à distance'),
    ('Mars 2020',                           'Mastcam-Z',    'Stéréophotographie multispectrale'),
    ('Mars 2020',                           'PIXL',         'Analyse élémentaire microscopique'),
    ('Mars Science Laboratory',             'ChemCam',      'Composition chimique des roches'),
    ('Rosetta',                             'ROLIS',        'Imagerie in-situ du sol cométaire'),
    ('JUpiter ICy moons Explorer (JUICE)',  'JANUS',        'Cartographie optique globale de Ganymède'),
    ('JUpiter ICy moons Explorer (JUICE)',  'Magnétomètre', 'Champ magnétique jovien et de Ganymède'),
    ('Cassini',                             'Magnétomètre', 'Cartographie de la magnétosphère de Saturne'),
    ('Voyager 1',                           'Magnétomètre', 'Champs magnétiques planétaires et interstellaires')
) AS v(nom_mission, nom_instrument, role)
INNER JOIN mission m ON m.nom_mission = v.nom_mission
INNER JOIN instrument_scientifique i ON i.nom_instrument = v.nom_instrument;

-- 8. echantillon (Relation 1:1 sur de vraies missions du CSV ; Chang'e 5 reste libre pour la démo UPSERT)
INSERT INTO echantillon (code_tube, type_roche, masse_grammes, id_mission)
SELECT v.code_tube, v.type_roche, v.masse_grammes, m.id_mission
FROM (VALUES
    ('PER-01-ROU', 'Basalte magmatique martien (cratère Jezero)',   8.24, 'Mars 2020'),
    ('APO-11-MAR', 'Basalte lunaire (Mer de la Tranquillité)', 21550.00, 'Apollo 11'),
    ('OSR-01-BEN', 'Régolithe carboné (astéroïde Bennu)',       121.60, 'OSIRIS-REx'),
    ('HYB-02-RYU', 'Matériau primitif carboné (Ryugu)',           5.40, 'Hayabusa 2'),
    ('STD-01-WLD', 'Poussières cométaires (comète Wild 2)',       0.01, 'Stardust')
) AS v(code_tube, type_roche, masse_grammes, nom_mission)
INNER JOIN mission m ON m.nom_mission = v.nom_mission;
