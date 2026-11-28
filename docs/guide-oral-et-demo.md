# Guide de Présentation — Oraux du 30 novembre & 7 décembre

> Ce document prépare votre groupe pour les **deux jalons évalués** : la validation du modèle ERD (lundi **30 novembre 2026**) et la démonstration complète du programme Python (lundi **7 décembre**, ou date retenue), sur la base alimentée par les **2 CSV réels** (`15` corps célestes, `279` missions historiques 1957–2025).

---

## 🎯 Partie 1 — Présentation du modèle (lundi 30 novembre 2026)

### Checklist des éléments à présenter obligatoirement

* [ ] Le **cas pratique** et le besoin métier (*suivi de 279 missions spatiales réelles, propriétés physiques des planètes, instruments embarqués, échantillons 1:1, trajectoires orbitales orientées pondérées et profils utilisateurs*).
* [ ] Le **diagramme ERD complet** (ouvrir [`DIAGRAMME.md`](../DIAGRAMME.md) en aperçu Mermaid `Ctrl + Shift + V`) montrant les **8 tables** (>= 7 demandées), les PK, FK, UK et cardinalités.
* [ ] Une **règle métier justifiant une relation `1:N`** (`corps_celeste -> mission` et `profil -> utilisateur`).
* [ ] Une **règle métier justifiant une relation `M:N`** (`mission_instrument` et auto-association `trajectoire_orbitale`).
* [ ] La **description précise des 3 états SQL** (question métier, tables jointes, type de jointure).
* [ ] Les **trois plus-values** : intégration sans table superflue de 2 jeux CSV réels, profils avec mots de passe hachés (`md5`), et graphe orienté pondéré à double sens (`trajectoire_orbitale`).

### Proposition de répartition de la parole (exemple en binôme)

| Temps | Intervenant | Sujets à expliquer clairement |
| :---: | :--- | :--- |
| **1 min** | **Membre 1** | **Cas pratique & Datasets réels** : 8 tables 3NF intégrant directement 2 CSV réels (`9` planètes + `6` cibles et `279` missions de 1957 à 2025, aucune mission inventée). |
| **1 min 30** | **Membre 1** | **Relations `1:N` & Sécurité des profils** : `corps_celeste (0..1) -> mission (N)` (*Mars a reçu 49 missions, Moon 139, tandis que 3 missions comme Kepler n'ont pas de cible planétaire : `id_corps = NULL`*) et `profil (1) -> utilisateur (N)` (*évite la dépendance transitive 3NF, mots de passe via `md5()`*). |
| **1 min 30** | **Membre 2** | **Relations `M:N`, `1:1` & Graphe orienté pondéré** : `mission_instrument` (*Mars 2020 a 3 instruments ; Magnétomètre équipe Cassini, JUICE et Voyager 1*), `echantillon` (`UNIQUE id_mission` = 1:1 sur `Apollo 11`, `Mars 2020`, `OSIRIS-REx`, `Hayabusa 2`, `Stardust`), et `trajectoire_orbitale` (*19 arêtes orientées pondérées dont 4 paires double sens asymétriques*). |
| **1 min** | **Les deux** | **Les 3 états SQL** : chacun présente un ou deux états en indiquant **la question métier**, **les tables reliées** et **le type de jointure**. |

### Fiche mémo des 3 états SQL (à connaître sur le bout des doigts)

| État | Question concrète du cas pratique | Tables jointes | Type de jointure / clause clé |
| :--- | :--- | :--- | :--- |
| **État 1** | *Quels instruments équipent les missions réelles réussies au lancement, vers quel astre et sous quel responsable ?* | `mission` + `corps_celeste` + `utilisateur` + `mission_instrument` + `instrument_scientifique` | `INNER JOIN` (et `LEFT JOIN utilisateur`) + `WHERE echec_lancement = FALSE` |
| **État 2** | *Combien de missions ciblent chaque corps céleste du catalogue et quelles planètes n'ont encore aucune mission cible dédiée ?* | `corps_celeste` + `mission` | `LEFT JOIN` + `GROUP BY` : met en évidence **`Uranus`** et **`Neptune`** (`0` mission) |
| **État 3** | *Combien d'échantillons et quelle masse totale/moyenne ont été collectés par astre exploré ?* | `corps_celeste` + `mission` + `echantillon` | `INNER JOIN` + `GROUP BY c.nom` + `HAVING COUNT(...) >= 1` (`Moon`, `Asteroid`, `Mars`, `Comet`) |

---

## 💻 Partie 2 — Scénario de démonstration finale (`app.py`, 7 décembre)

### Avant d'entrer en salle (préparation en 2 minutes)

Réinitialisez votre base locale avec les données propres issues des 2 CSV :

```powershell
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/01_schema.sql
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/02_seed.sql
uv run python app.py
```

### Déroulé recommandé étape par étape (couvre 100 % de la grille)

1. **Démontrer la gestion des profils et des mots de passe hachés (`md5`) :**
   * Connectez-vous d'abord avec `invite` / `invite123` (profil **`observateur`**).
   * Essayez l'option **`1`** (insérer une mission) ➔ `[ACCÈS REFUSÉ]` (lecture seule).
   * Option **`12`** ➔ basculez sur `s.curie` / `science123` (`scientifique`), essayez l'option **`5`** (supprimer) ➔ `[ACCÈS REFUSÉ]`.
   * Option **`12`** ➔ basculez sur `tlenfant` / `password` (`administrateur`, vérifié par `md5('password')`).
   * Option **`11`** : affichez les comptes pour prouver que seuls les **hashs MD5** sont en base.

2. **Saisir des données (minimum attendu : 2 nouveaux enregistrements) :**
   * **Insertion 1** — Option **`1`** (nouvelle mission de test) : par exemple nom `Demo Mission 2026`, date `2026-12-07`, pays `European Space Agency`, type `Lunar Orbiter`, lanceur `Ariane 6`, masse `1200`, cible `Moon` (`#10`). Notez l'ID créé (ex. `#280`).
   * **Insertion 2** — Option **`2`** (nouvel échantillon 1:1 sur une vraie mission du CSV) : filtrez par `Chang`, sélectionnez l'ID de **`Chang'e 5`**, saisissez code `CHG-05-OCE`, roche `Régolithe basaltique (Océan des Tempêtes)`, masse `1731.00`.

3. **Modifier un enregistrement et montrer la valeur obtenue (minimum attendu : 1) :**
   * Option **`4`** ➔ Choix **`1`** : filtrez par `Demo`, sélectionnez la mission `#280`, modifiez son `type_mission` en `Lunar Orbiter and Lander` et son lanceur en `Ariane 64`.
   * Montrez la sortie `[UPDATE] Avant / Après` renvoyée par PostgreSQL (`RETURNING`).

4. **Supprimer un enregistrement et vérifier sa disparition (minimum attendu : 1) :**
   * Option **`5`** ➔ Choix **`2`** : supprimez la mission de test `Demo Mission 2026` (`#280`).
   * Montrez les deux lignes de preuve : `[DELETE]` puis `[VÉRIFICATION] Nombre de lignes restantes pour id_mission = 280 : 0 (disparition confirmée)`.

5. **Produire les 3 états multi-tables (minimum attendu : 3) :**
   * Option **`6`** (**État 1** `INNER JOIN` sur 5 tables) : 9 affectations scientifiques sur les 6 grandes missions réelles.
   * Option **`7`** (**État 2** `LEFT JOIN` sur 15 astres) : `Moon` (139), `Mars` (49), `Venus` (41)... jusqu'à **`Uranus` (0)** et **`Neptune` (0)** conservés grâce au `LEFT JOIN`.
   * Option **`8`** (**État 3** `GROUP BY + HAVING`) : bilan des masses par astre (`Moon` passe à 2 échantillons avec `Chang'e 5` + `Apollo 11` !).

6. **Démontrer le graphe orienté pondéré (double sens + Dijkstra) :**
   * Option **`9`** : montrez les 4 paires `Double sens` asymétriques (`Earth <-> Moon` : `13 200 m/s` aller vs `2 800 m/s` retour) et les arcs `Sens unique`.
   * Option **`10`** (Dijkstra) :
     * `Earth (#3)` ➔ `Jupiter (#5)` critère **`1` (Δv)** ➔ direct (`16 500 m/s`, `1 800 j`).
     * `Earth (#3)` ➔ `Jupiter (#5)` critère **`2` (durée)** ➔ `Earth -> Mars -> Jupiter` (`1 160 j`, `18 800 m/s`).
     * Bonus : `Earth (#3)` ➔ `Neptune (#8)` ➔ `Earth -> Jupiter -> Saturn -> Uranus -> Neptune` (Grand Tour planétaire).

---

## ❓ Questions probables du professeur (et réponses courtes)

| Question possible | Réponse claire et précise |
| :--- | :--- |
| **Comment avez-vous intégré les 2 CSV sans exploser le nombre de tables ?** | On a gardé exactement **8 tables 3NF** : `planets.csv` enrichit `corps_celeste`, `missions.csv` alimente `mission` (279 lignes, 0 mission inventée) et complète `corps_celeste` avec les 6 cibles non-planétaires (`Moon`, `Titan`, `Ganymede`, `Sun`, `Asteroid`, `Comet`). |
| **Pourquoi `mission.id_corps` est-il nullable ?** | Dans le CSV réel, 3 missions (`Zond 4`, `Kepler`, `Q-PACE`) ont une cible vide (`Kepler` observe des exoplanètes). Autoriser `NULL` permet d'importer les 279 missions sans inventer de cible fictive. |
| **Pourquoi écrire `ON DELETE RESTRICT` si PostgreSQL bloque déjà par défaut ?** | Par défaut PostgreSQL applique `NO ACTION` (vérification différable en fin de transaction). `RESTRICT` impose un contrôle **immédiat et non différable** et documente explicitement notre choix métier dans le DDL (contrairement à `CASCADE` ou `SET NULL`). |
| **Pourquoi `profil` est séparée de `utilisateur` et pourquoi pas `user` ?** | Séparer `profil` évite la dépendance transitive des droits (3NF). Et dans PostgreSQL, `user` est un mot-clé réservé (`R`), alors que `description` n'est pas un mot-clé PostgreSQL. |
| **Pourquoi `md5()` et quelles sont ses limites ?** | `md5()` est natif PostgreSQL et correspond à l'exemple du cours pour ne jamais stocker de mot de passe en clair. En production, on utiliserait un hash lent et salé (**Argon2** / **bcrypt**). |
| **Comment le graphe autorise-t-il le double sens asymétrique ?** | `trajectoire_orbitale` a `UNIQUE (id_corps_depart, id_corps_arrivee)` + `CHECK (id_corps_depart <> id_corps_arrivee)` : `(Earth, Moon)` et `(Moon, Earth)` sont deux arêtes distinctes avec leurs propres poids `delta_v_ms` et `duree_jours`. |
