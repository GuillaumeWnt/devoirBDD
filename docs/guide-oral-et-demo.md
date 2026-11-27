# Guide de Présentation — Oraux du 30 novembre & 7 décembre

> Ce document prépare votre groupe pour les **deux jalons évalués** : la validation du modèle ERD (lundi **30 novembre 2026**) et la démonstration complète du programme Python (lundi **7 décembre**, ou date retenue).

---

## 🎯 Partie 1 — Présentation du modèle (lundi 30 novembre 2026)

### Checklist des éléments à présenter obligatoirement

* [ ] Le **cas pratique** et le besoin auquel répond la base (*suivi des missions d'exploration spatiale, de leurs instruments, des échantillons, des trajectoires orbitales et des profils utilisateurs*).
* [ ] Le **diagramme ERD complet** (ouvrir [`DIAGRAMME.md`](../DIAGRAMME.md) en aperçu Mermaid `Ctrl + Shift + V`) montrant les **8 tables** (>= 7 demandées), les PK, FK, UK et cardinalités.
* [ ] Une **règle métier justifiant une relation `1:N`** (et même deux !).
* [ ] Une **règle métier justifiant une relation `M:N`** (avec sa table d'association).
* [ ] La **description précise des 3 états** (quelles questions ils posent et quelles tables sont reliées).
* [ ] Les **deux plus-values** demandées : la gestion des profils par mot de passe haché (`md5`) et le graphe orienté pondéré (`trajectoire_orbitale`).

### Proposition de répartition de la parole (exemple en binôme)

| Temps | Intervenant | Sujets à expliquer clairement |
| :---: | :--- | :--- |
| **1 min** | **Membre 1** | **Cas pratique & Vue d'ensemble** : à quoi sert la base `exploration_spatiale` (8 tables en 3NF, toutes connectées). |
| **1 min 30** | **Membre 1** | **Relations `1:N` & Sécurité des profils** : expliquer `corps_celeste (1) -> mission (N)` (*plusieurs missions peuvent explorer Mars, mais une mission cible un astre principal*) et `profil (1) -> utilisateur (N)` (*évite la dépendance transitive 3NF, mots de passe stockés via `md5()`, jamais en clair*). |
| **1 min 30** | **Membre 2** | **Relations `M:N`, `1:1` & Graphe orienté pondéré** : expliquer `mission_instrument` (*Perseverance a 3 instruments ; Mastcam-Z équipe Perseverance et Artemis III*), `echantillon` (`UNIQUE id_mission` = 1:1), et `trajectoire_orbitale` (*graphe orienté pondéré à double sens asymétrique sur `corps_celeste`*). |
| **1 min** | **Les deux** | **Les 3 états SQL** : chacun présente un ou deux états en indiquant **la question métier**, **les tables jointes** et **le type de jointure**. |

### Fiche mémo des 3 états SQL (à connaître sur le bout des doigts)

| État | Question concrète du cas pratique | Tables jointes | Type de jointure / clause clé |
| :--- | :--- | :--- | :--- |
| **État 1** | *Quels instruments équipent les missions actives, vers quel astre et sous quel responsable ?* | `mission` + `corps_celeste` + `utilisateur` + `mission_instrument` + `instrument_scientifique` | `INNER JOIN` (et `LEFT JOIN utilisateur` si responsable `NULL`) + `WHERE statut IN (...)` |
| **État 2** | *Quels corps célestes du catalogue ont une mission et lesquels restent encore inexplorés ?* | `corps_celeste` + `mission` (+ `utilisateur`) | `LEFT JOIN` + `COALESCE(...)` pour conserver *Encelade* et *Terre* même sans mission cible |
| **État 3** | *Combien d'échantillons et quelle masse totale/moyenne ont été collectés par astre exploré ?* | `corps_celeste` + `mission` + `echantillon` | `INNER JOIN` + `GROUP BY c.nom` + `HAVING COUNT(...) >= 1` |

---

## 💻 Partie 2 — Scénario de démonstration finale (`app.py`, 7 décembre)

### Avant d'entrer en salle (préparation en 2 minutes)

Réinitialisez votre base locale avec les données propres du jeu d'essai :

```powershell
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/01_schema.sql
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/02_seed.sql
uv run python app.py
```

### Déroulé recommandé étape par étape (couvre 100 % de la grille)

1. **Démontrer la gestion des profils et des mots de passe hachés (`md5`) :**
   * Connectez-vous d'abord avec le compte `invite` / `invite123` (profil **`observateur`**).
   * Essayez l'option **`1`** (insérer une mission) ➔ l'application affiche `[ACCÈS REFUSÉ]` (lecture seule).
   * Utilisez l'option **`12`** pour basculer sur `tlenfant` / `password` (profil **`administrateur`**, vérifié par `WHERE username = %s AND password_hash = md5(%s)`).
   * Option **`11`** : affichez les comptes pour montrer que seuls les **hashs MD5** sont stockés, jamais les mots de passe en clair.

2. **Saisir des données (minimum attendu : 2 nouveaux enregistrements) :**
   * **Insertion 1** — Option **`1`** (nouvelle mission) : par exemple nom `Dragonfly`, agence `NASA`, statut `En préparation`, `id_corps = 4` (*Titan*). Notez son ID (ex. `#7`).
   * **Insertion 2** — Option **`2`** (nouvel échantillon 1:1) : par exemple code `ART-01-REG`, roche `Régolithe anorthositique lunaire`, masse `15.50`, `id_mission = 5` (*Artemis III*). Notez son ID (ex. `#4`).
   * *(Variante possible : utiliser aussi l'option **`3`** pour ajouter une nouvelle arête orientée au graphe orbital !)*

3. **Modifier un enregistrement et montrer la valeur obtenue (minimum attendu : 1) :**
   * Option **`4`** ➔ Choix **`1`** (modifier le statut d'une mission) : passez `Dragonfly` (`#7`) de `En préparation` à `En transit` (ou modifiez la masse de l'échantillon `#4` de `15.50 g` à `18.25 g`).
   * Montrez la ligne `[UPDATE] ... Avant -> Après` renvoyée directement par PostgreSQL (`RETURNING`).

4. **Supprimer un enregistrement et vérifier sa disparition (minimum attendu : 1) :**
   * Option **`5`** ➔ Choix **`2`** (supprimer une mission) : supprimez `Dragonfly` (`#7`).
   * Montrez les deux preuves affichées : `[DELETE] Enregistrement supprimé` et `[VÉRIFICATION] Nombre de lignes restantes : 0 (disparition confirmée)`.

5. **Produire les 3 états multi-tables (minimum attendu : 3) :**
   * Option **`6`** (**État 1** `INNER JOIN`) : expliquez quelles 5 tables sont reliées.
   * Option **`7`** (**État 2** `LEFT JOIN`) : montrez qu'*Encelade* apparaît bien grâce au `LEFT JOIN` + `COALESCE`.
   * Option **`8`** (**État 3** `GROUP BY + HAVING`) : montrez que la *Lune* apparaît désormais dans le bilan grâce à l'échantillon inséré pour *Artemis III* !

6. **Démontrer le graphe orienté pondéré (double sens + Dijkstra) :**
   * Option **`9`** : montrez les liaisons `Double sens` (`Terre <-> Lune` : `13 200 m/s` à l'aller vs `2 800 m/s` au retour) et `Sens unique` (`Lune -> Mars`).
   * Option **`10`** (Dijkstra) :
     * Calculez `Terre (#1)` ➔ `Europe (#5)` avec le critère **`1` (Δv)** ➔ trajet direct `Terre -> Europe` (`16 500 m/s`, `1 800 j`).
     * Relancez `Terre (#1)` ➔ `Europe (#5)` avec le critère **`2` (durée)** ➔ trajet indirect `Terre -> Mars -> Europe` (`1 160 j`, `18 800 m/s`) !
     * Bonus : `Terre (#1)` ➔ `Encelade (#6)` montre un chemin à 3 ou 4 étapes alors qu'aucune liaison directe n'existe.

---

## ❓ Questions probables du professeur (et réponses courtes)

| Question possible | Réponse claire et précise |
| :--- | :--- |
| **Pourquoi avoir créé une table `profil` séparée de `utilisateur` ?** | Pour respecter la **3NF** : les droits (`peut_ecrire`, `peut_supprimer`) dépendent du profil et non de chaque individu. Sinon on dupliquerait ces booléens sur chaque utilisateur (dépendance transitive). |
| **Pourquoi votre table ne s'appelle pas `user` ?** | Dans PostgreSQL, `user` est un mot-clé réservé SQL (`SELECT current_user;`). Nommer la table `utilisateur` évite les conflits de syntaxe et les guillemets obligatoires. |
| **Pourquoi utilisez-vous `md5()` et quelles sont ses limites ?** | `md5()` est natif dans PostgreSQL et illustre le principe fondamental : ne jamais stocker un mot de passe en clair. En production réelle, on utiliserait un algorithme lent avec sel (`Argon2` ou `bcrypt`) car MD5 est trop rapide face aux attaques par dictionnaire. |
| **Comment votre schéma autorise-t-il un graphe orienté à double sens ?** | `trajectoire_orbitale` porte deux clés étrangères vers `corps_celeste` (`id_corps_depart`, `id_corps_arrivee`) avec `UNIQUE (id_corps_depart, id_corps_arrivee)` et `CHECK (depart <> arrivee)`. Ainsi `(Terre, Lune)` et `(Lune, Terre)` coexistent avec des poids différents. |
| **Comment empêchez-vous les injections SQL en Python ?** | Toutes les requêtes utilisent des paramètres liés `%s` passés en tuple à `cur.execute(query, params)`, jamais de concaténation ni de f-strings dans les chaînes SQL. |
| **Pourquoi les identifiants PostgreSQL sont-ils dans `.env` ?** | Pour partager le dépôt sur GitHub entre membres du groupe sans exposer de mot de passe dans l'historique Git et sans écraser la configuration locale de chacun. |
