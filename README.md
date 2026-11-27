# Projet BDD & Python : Exploration Spatiale & Planétologie (3NF — 8 tables)

Modélisation relationnelle complète en **3e Forme Normale (3NF)** d'un système d'information pour l'exploration planétaire : gestion des profils utilisateurs (mots de passe hachés), catalogue des corps célestes, **graphe orienté et pondéré de trajectoires orbitales (double sens autorisé)**, missions spatiales, instruments scientifiques et échantillons géologiques.

---

## ✅ Conformité aux consignes du projet

| Exigence | Implémentation dans le projet |
| :--- | :--- |
| **Au moins 7 tables (associations incluses)** | **8 tables** en 3NF : `profil`, `utilisateur`, `corps_celeste`, `trajectoire_orbitale`, `mission`, `instrument_scientifique`, `mission_instrument`, `echantillon`. |
| **Au moins une relation `1:N`** | **3 relations `1:N`** (`corps_celeste -> mission`, `profil -> utilisateur`, `utilisateur -> mission`). |
| **Au moins une relation `M:N`** | **2 relations `M:N`** (`mission_instrument` et auto-association orientée `trajectoire_orbitale`), plus **1 relation `1:1`** (`mission <-> echantillon`). |
| **Gestion de profils & mots de passe hachés** | Tables `profil` + `utilisateur` ; empreintes stockées via `md5(...)` (jamais en clair) et contrôle des permissions (`peut_ecrire`, `peut_supprimer`). |
| **Graphe orienté pondéré (double sens)** | Table `trajectoire_orbitale` (poids `delta_v_ms` + `duree_jours`), asymétrie aller/retour et calcul du plus court chemin (**Dijkstra**) dans [`app.py`](app.py). |
| **Programme Python CLI (CRUD + 3 états)** | [`app.py`](app.py) : authentification, insertions (missions, échantillons, trajectoires), modification avec preuve avant/après, suppression avec vérification de disparition et 3 états SQL multi-tables. |
| **Terrain prêt pour un dataset externe** | Tailles de colonnes souples, `id_responsable` optionnel, contraintes `UNIQUE` idempotentes et utilitaire optionnel [`import_csv.py`](import_csv.py). |

---

## 📚 Sommaire de la documentation du projet

Chaque aspect du projet est documenté dans un fichier dédié :

| Document | Contenu |
| :--- | :--- |
| [`DIAGRAMME.md`](DIAGRAMME.md) | Diagramme **ERD complet (8 tables)**, **graphe orbital Mermaid**, tableau des cardinalités et dictionnaire détaillé des données. |
| [`docs/architecture-et-modele.md`](docs/architecture-et-modele.md) | Explication structurée globale : besoin métier, justifications 3NF, fonctionnement du graphe orienté pondéré, sécurité MD5 et préparation import CSV. |
| [`docs/guide-oral-et-demo.md`](docs/guide-oral-et-demo.md) | Feuille de route prête pour les deux soutenances (**30 novembre** pour le modèle ERD et **7 décembre** pour la démo CLI en direct). |
| [`docs/role-script-python.md`](docs/role-script-python.md) | Explication pédagogique très simple du rôle de Python face au SQL et décryptage ligne par ligne des syntaxes Python/PostgreSQL. |
| [`docs/environnement-python.md`](docs/environnement-python.md) | Fonctionnement hybride `uv` + `venv`/`pip` pour le travail collaboratif. |
| [`docs/historique.md`](docs/historique.md) | Synthèse de l'évolution du projet entre les versions. |

---

## 🗺️ Vue synthétique du schéma relationnel (8 tables)

```mermaid
erDiagram
    PROFIL ||--o{ UTILISATEUR : "id_profil"
    UTILISATEUR |o--o{ MISSION : "id_responsable"
    CORPS_CELESTE ||--o{ MISSION : "id_corps"
    CORPS_CELESTE ||--o{ TRAJECTOIRE_ORBITALE : "depart / arrivee"
    MISSION ||--o{ MISSION_INSTRUMENT : "id_mission"
    INSTRUMENT_SCIENTIFIQUE ||--o{ MISSION_INSTRUMENT : "id_instrument"
    MISSION ||--o| ECHANTILLON : "id_mission (1:1)"
```

> 👉 Voir le schéma complet avec tous les attributs, clés et le graphe orbital dans [`DIAGRAMME.md`](DIAGRAMME.md).

---

## 📁 Organisation des fichiers

```text
devoirBDD/
├── README.md                          # Porte d'entrée, sommaire et guide de démarrage
├── DIAGRAMME.md                       # ERD 8 tables, graphe orbital et dictionnaire des données
├── db.py                              # Connexion PostgreSQL typée (.env) et encodage UTF-8 Windows
├── app.py                             # Programme CLI complet (auth MD5, CRUD, 3 états, Dijkstra)
├── insertion_echantillon.py           # Script autonome de démonstration UPSERT (relation 1:1)
├── import_csv.py                      # Utilitaire léger et optionnel d'import CSV externe
├── data/
│   └── exemple_corps_celestes.csv     # Gabarit CSV prêt pour accueillir une base externe
├── sql/
│   ├── 01_schema.sql                  # Création des 8 tables 3NF et contraintes
│   ├── 02_seed.sql                    # Jeu d'essai cohérent (profils, comptes MD5, graphe, missions)
│   └── 03_queries.sql                 # Les 3 états SQL + requêtes graphe et auth MD5
├── docs/
│   ├── architecture-et-modele.md      # Explication complète de l'architecture et des choix 3NF
│   ├── guide-oral-et-demo.md          # Scénario d'oral (30 nov.) et de démo live (7 déc.)
│   ├── role-script-python.md          # Guide pédagogique Python / SQL et syntaxes
│   ├── environnement-python.md        # Guide collaboratif uv + venv/pip
│   ├── historique.md                  # Historique compact du projet
│   └── plan.md                        # Suivi des tâches de la session courante
├── pyproject.toml / uv.lock           # Gestion des dépendances avec uv
├── requirements.txt                   # Dépendances exportées pour venv / pip
├── .python-version                    # Version Python cible (3.12)
└── .env.example                       # Modèle des variables d'environnement PostgreSQL
```

---

## 📊 Les 3 états SQL (plus 2 requêtes de démonstration)

Dans [`sql/03_queries.sql`](sql/03_queries.sql) et dans [`app.py`](app.py) :

1. **État 1 (`INNER JOIN` sur 5 tables) :** Flotte active (`Opérationnelle` / `En transit`), cible planétaire, responsable scientifique et instruments embarqués.
2. **État 2 (`LEFT JOIN` + `COALESCE`) :** Inventaire exhaustif de **tous** les corps célestes, y compris ceux sans mission cible (*Encelade*, *Terre*).
3. **État 3 (`GROUP BY` + `HAVING`) :** Bilan géologique par corps céleste exploré (nombre d'échantillons `1:1`, masse totale et masse moyenne).
4. **Bonus Graphe (auto-jointure sur `trajectoire_orbitale`) :** Liste des trajectoires orientées pondérées avec détection automatique `Double sens` vs `Sens unique` (+ calcul d'itinéraire **Dijkstra** en Python).
5. **Bonus Sécurité (`md5`) :** Vérification d'authentification par empreinte MD5 et récupération du profil (`WHERE username = 'tlenfant' AND password_hash = md5('password')`).

---

## 🚀 Mise en route (PostgreSQL + Python)

### 1. Prérequis

* **PostgreSQL** (version 14+ recommandée) installé et démarré localement.
* **Python 3.11+** (3.12 recommandé).

### 2. Configuration des identifiants (`.env`) — Pourquoi ne pas les mettre en dur dans Python ?

> [!IMPORTANT]
> **Note pour le travail en binôme sur GitHub :**
> Dans l'exemple initial du cours, les identifiants PostgreSQL étaient écrits en clair directement dans le script Python pour faire simple. Dès qu'on partage un projet via **Git / GitHub**, cette méthode pose deux problèmes :
>
> 1. **Sécurité sur GitHub :** Tout ce qui est écrit dans les fichiers `.py` est envoyé sur GitHub et conservé dans l'historique Git. On ne doit jamais publier un mot de passe (même local) dans le code source.
> 2. **Travail sur deux PC différents :** Le mot de passe PostgreSQL (voire le port ou l'utilisateur) n'est pas forcément le même sur ton PC et sur le mien. Si les identifiants étaient écrits en dur dans le script, chacun modifierait le fichier de l'autre à chaque `git pull` / `git push`.

**Comment fonctionne la séparation `.env.example` / `.env` ?**

| Fichier | Présent sur GitHub ? | Rôle |
| :--- | :---: | :--- |
| `.env.example` | ✅ Oui (partagé) | Sert de **modèle** sans mot de passe réel pour montrer les variables attendues. |
| `.env` | ❌ Non (ignoré par `.gitignore`) | Contient **tes** vrais identifiants locaux. Il reste uniquement sur ta machine. |

**Étapes à suivre une seule fois après avoir cloné le dépôt :**

1. Créez votre fichier local `.env` à partir du modèle :

```powershell
# PowerShell (Windows)
Copy-Item .env.example .env
```

```bash
# Linux / macOS
cp .env.example .env
```

2. Ouvrez `.env` et renseignez **votre** mot de passe PostgreSQL local dans `PGPASSWORD` (ainsi que le port/utilisateur s'ils diffèrent de `postgres@localhost:5432`).
3. Le module [`db.py`](db.py) lit automatiquement `.env` au démarrage grâce à `python-dotenv`, sans rien modifier dans le code partagé sur GitHub.

### 3. Déploiement de la base PostgreSQL

Créez la base `exploration_spatiale`, puis exécutez les 3 scripts SQL dans l'ordre (via `psql`, pgAdmin ou l'extension PostgreSQL de VS Code) :

```powershell
psql -h localhost -U postgres -c "CREATE DATABASE exploration_spatiale;"
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/01_schema.sql
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/02_seed.sql
psql -h localhost -U postgres -d exploration_spatiale -v ON_ERROR_STOP=1 -f ./sql/03_queries.sql
```

### 4. Environnement Python & lancement des programmes

#### Option A — Avec `uv` (recommandée)

```powershell
# Installe l'environnement (.venv) à partir de uv.lock
uv sync

# Lance l'application CLI complète (authentification, CRUD, 3 états, Dijkstra)
uv run python app.py

# Script autonome de démonstration UPSERT 1:1 (optionnel)
uv run python insertion_echantillon.py

# Test d'import CSV externe à blanc (optionnel, sans modifier la base)
uv run python import_csv.py data/exemple_corps_celestes.csv --dry-run
```

#### Option B — Avec `venv` + `pip` standard (sans `uv`)

* **Windows (PowerShell) :**
  ```powershell
  python -m venv .venv
  .\.venv\Scripts\Activate.ps1
  pip install -r requirements.txt
  python app.py
  ```
* **Linux / macOS :**
  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
  python app.py
  ```

### 5. Comptes applicatifs de démonstration (`02_seed.sql`)

Ces comptes fictifs sont stockés **uniquement sous forme d'empreintes `md5()`** dans la table `utilisateur` pour démontrer les 3 profils d'accès :

| Identifiant (`username`) | Mot de passe (démo) | Profil | Permissions |
| :--- | :--- | :--- | :--- |
| `tlenfant` | `password` | `administrateur` | Lecture + Écriture + Suppression + Gestion comptes |
| `admin` | `admin123` | `administrateur` | Lecture + Écriture + Suppression + Gestion comptes |
| `s.curie` | `science123` | `scientifique` | Lecture + Écriture (suppression refusée) |
| `invite` | `invite123` | `observateur` | Lecture seule (états + graphe) |
