-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF — 8 TABLES)
-- Fichier : 03_queries.sql
-- Description : Les 3 états officiels (jointures multi-tables) +
--               2 requêtes de démonstration (graphe orbital et auth MD5)
-- ====================================================================


-- ====================================================================
-- ÉTAT 1 : JOINTURE FERMÉE (INNER JOIN sur 5 tables)
-- ====================================================================
-- Question métier : Quels instruments sont embarqués sur les missions
-- actives (opérationnelles ou en transit), vers quel astre et sous la
-- responsabilité de quel scientifique ?
-- --------------------------------------------------------------------
SELECT
    m.nom_mission,
    c.nom AS cible_exploration,
    COALESCE(u.nom_complet, 'Non assigné') AS responsable,
    i.nom_instrument,
    i.type_mesure,
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
WHERE m.statut IN ('Opérationnelle', 'En transit')
ORDER BY m.nom_mission, i.nom_instrument;


-- ====================================================================
-- ÉTAT 2 : JOINTURE OUVERTE (LEFT OUTER JOIN)
-- ====================================================================
-- Question métier : Quel est l'inventaire complet de TOUS les corps
-- célestes du catalogue, y compris ceux qui n'ont encore aucune mission
-- cible (comme Encelade ou la Terre en tant que base de départ) ?
-- --------------------------------------------------------------------
SELECT
    c.nom AS corps_celeste,
    c.type_corps,
    c.distance_soleil_ua,
    COALESCE(m.nom_mission, '--- Aucune mission programmée ---') AS mission_assignee,
    COALESCE(m.agence_spatiale, 'N/A') AS agence,
    COALESCE(m.statut, 'Non exploré') AS statut_exploration,
    COALESCE(u.nom_complet, 'N/A') AS responsable
FROM corps_celeste c
LEFT JOIN mission m
    ON c.id_corps = m.id_corps
LEFT JOIN utilisateur u
    ON m.id_responsable = u.id_utilisateur
ORDER BY c.distance_soleil_ua ASC, c.nom ASC;


-- ====================================================================
-- ÉTAT 3 : AGRÉGATION ET REGROUPEMENT (GROUP BY + HAVING)
-- ====================================================================
-- Question métier : Quel est le bilan de la collecte géologique par
-- corps céleste exploré (nombre d'échantillons uniques 1:1, masse
-- totale et masse moyenne) pour les astres ayant au moins 1 prélèvement ?
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
