---
trigger: model_decision
description: Consulter avant tout commit, push Git ou ajout de configuration et identifiants dans devoirBDD.
---

# Règles de Sécurité & Hygiène Git

1. **Protection des secrets avant `git add` / `git commit` :**
   - Vérifier via `git status` qu'aucun fichier sensible (`.env`, `.env.*` sauf `.env.example`, `*.key`, `*.pem`, `*.secret`) ni aucun environnement virtuel (`.venv/`, `venv/`) n'est suivi ou stagé.
   - Si un identifiant ou mot de passe doit être ajouté à la configuration, l'ajouter uniquement sous forme de valeur factice dans `.env.example` et documenter son usage dans `README.md`.
2. **Cohérence des dépendances partagées :**
   - Vérifier que `pyproject.toml`, `uv.lock` et `requirements.txt` sont cohérents avant de pousser vers `origin`.
3. **Conventional Commits :**
   - Rédiger des messages clairs au format `<type>(<scope>): <résumé>` sans aucun guillemet dans le titre ou le corps.
