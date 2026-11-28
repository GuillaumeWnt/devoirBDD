-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
-- Fichier : 03_queries.sql
-- Description : Les 3 états officiels multi-tables adaptés aux 2 CSV
--   réels (15 corps célestes, 279 missions) + 3 requêtes bonus
--   (graphe orienté pondéré, authentification MD5, bilan par pays)
-- ====================================================================


-- ====================================================================
-- ÉTAT 1 : JOINTURE FERMÉE (INNER JOIN sur 5 tables)
-- ====================================================================
-- Question métier : Quels instruments scientifiques équipent les
-- missions réelles suivies (sans échec au lancement), vers quel corps
-- céleste, pour quel pays/agence et sous quel responsable ?
-- --------------------------------------------------------------------
SELECT
    m.nom_mission,
    m.date_lancement,
    m.pays_operateur,
    c.nom AS cible_exploration,
    COALESCE(u.nom_complet, 'Non assigné') AS responsable,
    i.nom_instrument,
    mi.role AS role_instrument
FROM mission m
INNER JOIN corps_celeste c
    ON m.id_corps = c.id_corps
LEFT JOIN utilisateur u
    ON m.id_responsable = u.id_utilisateur
INNER JOIN mission_instrument mi
    ON m.id_mission = mi.id_mission
INNER JOIN instrument_scientifique i
    ON mi.id_instrument = i.id_instrument
WHERE m.echec_lancement = FALSE
ORDER BY m.date_lancement DESC, m.nom_mission, i.nom_instrument;


-- ====================================================================
-- ÉTAT 2 : JOINTURE OUVERTE (LEFT OUTER JOIN + agrégation)
-- ====================================================================
-- Question métier : Quel est l'inventaire complet de TOUS les corps
-- célestes du catalogue (planètes + cibles), avec le nombre de missions
-- qui les ciblent et la date du dernier lancement ?
-- Le LEFT JOIN conserve les planètes sans mission cible dédiée dans
-- le CSV (Uranus et Neptune : 0 mission).
-- --------------------------------------------------------------------
SELECT
    c.nom AS corps_celeste,
    c.type_corps,
    c.distance_soleil_ua,
    COUNT(m.id_mission) AS nb_missions,
    SUM(CASE WHEN m.echec_lancement THEN 1 ELSE 0 END) AS nb_echecs_lancement,
    COALESCE(TO_CHAR(MAX(m.date_lancement), 'YYYY-MM-DD'), 'Aucune mission cible') AS dernier_lancement
FROM corps_celeste c
LEFT JOIN mission m
    ON c.id_corps = m.id_corps
GROUP BY c.id_corps, c.nom, c.type_corps, c.distance_soleil_ua
ORDER BY nb_missions DESC, c.distance_soleil_ua ASC NULLS LAST, c.nom ASC;


-- ====================================================================
-- ÉTAT 3 : AGRÉGATION ET REGROUPEMENT (GROUP BY + HAVING)
-- ====================================================================
-- Question métier : Quel est le bilan de la collecte géologique par
-- corps céleste exploré (nombre d'échantillons uniques 1:1, masse
-- totale et masse moyenne) pour les astres ayant au moins 1 échantillon ?
-- --------------------------------------------------------------------
SELECT
    c.nom AS corps_explore,
    COUNT(e.id_echantillon) AS nb_echantillons_preleves,
    ROUND(SUM(e.masse_grammes), 2) AS masse_totale_grammes,
    ROUND(AVG(e.masse_grammes), 2) AS masse_moyenne_grammes
FROM corps_celeste c
INNER JOIN mission m
    ON c.id_corps = m.id_corps
INNER JOIN echantillon e
    ON m.id_mission = e.id_mission
GROUP BY c.nom
HAVING COUNT(e.id_echantillon) >= 1
ORDER BY masse_totale_grammes DESC;


-- ====================================================================
-- REQUÊTE 4 (BONUS GRAPHE) : RÉSEAU ORIENTÉ, PONDÉRÉ ET DOUBLE SENS
-- ====================================================================
-- Question métier : Quelles trajectoires orbitales orientées relient
-- les corps célestes, avec leurs poids (delta-v et durée), et lesquelles
-- disposent d'une liaison retour (double sens) ?
-- --------------------------------------------------------------------
SELECT
    cd.nom AS depart,
    ca.nom AS arrivee,
    t.delta_v_ms,
    t.duree_jours,
    t.type_transfert,
    CASE
        WHEN t_retour.id_trajectoire IS NOT NULL THEN 'Double sens'
        ELSE 'Sens unique'
    END AS sens_liaison
FROM trajectoire_orbitale t
INNER JOIN corps_celeste cd
    ON t.id_corps_depart = cd.id_corps
INNER JOIN corps_celeste ca
    ON t.id_corps_arrivee = ca.id_corps
LEFT JOIN trajectoire_orbitale t_retour
    ON t_retour.id_corps_depart = t.id_corps_arrivee
   AND t_retour.id_corps_arrivee = t.id_corps_depart
ORDER BY cd.nom, t.delta_v_ms ASC;


-- ====================================================================
-- REQUÊTE 5 (BONUS SÉCURITÉ) : AUTHENTIFICATION PAR HASH MD5 ET PROFIL
-- ====================================================================
-- Illustration directe de la consigne du cours (jamais en clair) :
-- SELECT md5('password');
-- --------------------------------------------------------------------
SELECT
    u.id_utilisateur,
    u.username,
    u.nom_complet,
    p.nom_profil,
    p.peut_ecrire,
    p.peut_supprimer
FROM utilisateur u
INNER JOIN profil p
    ON u.id_profil = p.id_profil
WHERE u.username = 'tlenfant'
  AND u.password_hash = md5('password');


-- ====================================================================
-- REQUÊTE 6 (BONUS DATASET CSV) : BILAN DES MISSIONS PAR PAYS / AGENCE
-- ====================================================================
-- Exploite les 279 missions réelles du CSV : nombre total de lancements,
-- échecs au lancement et taux de réussite au lancement par pays/agence.
-- --------------------------------------------------------------------
SELECT
    m.pays_operateur,
    COUNT(*) AS nb_missions,
    SUM(CASE WHEN m.echec_lancement THEN 1 ELSE 0 END) AS nb_echecs_lancement,
    ROUND(
        100.0 * SUM(CASE WHEN NOT m.echec_lancement THEN 1 ELSE 0 END) / COUNT(*),
        1
    ) AS taux_succes_lancement_pct
FROM mission m
GROUP BY m.pays_operateur
ORDER BY nb_missions DESC, m.pays_operateur ASC;
