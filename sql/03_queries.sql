-- ====================================================================
-- PROJET : EXPLORATION SPATIALE & PLANÉTOLOGIE (3NF)
-- Fichier : 03_queries.sql
-- Description : 3 requêtes types (Jointure fermée, Jointure ouverte, Group By)
-- ====================================================================


-- ====================================================================
-- REQUÊTE 1 : JOINTURE FERMÉE (INNER JOIN)
-- ====================================================================
-- Cas métier : Liste des instruments embarqués sur les missions en cours
-- (opérationnelles ou en transit), avec le corps ciblé et le rôle de l'instrument.
-- Seules les correspondances strictes entre les 4 tables sont conservées.
-- --------------------------------------------------------------------
SELECT 
    m.nom_mission,
    c.nom AS cible_exploration,
    i.nom_instrument,
    i.type_mesure,
    mi.role AS role_instrument
FROM mission m
INNER JOIN corps_celeste c 
    ON m.id_corps = c.id_corps
INNER JOIN mission_instrument mi 
    ON m.id_mission = mi.id_mission
INNER JOIN instrument_scientifique i 
    ON mi.id_instrument = i.id_instrument
WHERE m.statut IN ('Opérationnelle', 'En transit')
ORDER BY m.nom_mission, i.nom_instrument;


-- ====================================================================
-- REQUÊTE 2 : JOINTURE OUVERTE (LEFT OUTER JOIN)
-- ====================================================================
-- Cas métier : Inventaire complet de TOUS les corps célestes du catalogue,
-- qu'ils fassent l'objet d'une mission ou non.
-- Les astres non explorés (comme Encelade) restent présents avec des valeurs NULL / 'Non exploré'.
-- --------------------------------------------------------------------
SELECT 
    c.nom AS corps_celeste,
    c.type_corps,
    c.distance_soleil_ua,
    COALESCE(m.nom_mission, '--- Aucune mission programmée ---') AS mission_assignee,
    COALESCE(m.agence_spatiale, 'N/A') AS agence,
    COALESCE(m.statut, 'Non exploré') AS statut_exploration
FROM corps_celeste c
LEFT JOIN mission m 
    ON c.id_corps = m.id_corps
ORDER BY c.distance_soleil_ua ASC;


-- ====================================================================
-- REQUÊTE 3 : AGRÉGATION ET REGROUPEMENT (GROUP BY + HAVING)
-- ====================================================================
-- Cas métier : Bilan de la collecte géologique par corps céleste exploré.
-- Calcule le nombre d'échantillons uniques récoltés (relation 1:1 mission-échantillon)
-- et la masse totale, en ne conservant que les corps ayant au moins 1 échantillon collecté.
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
