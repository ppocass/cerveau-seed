# Mon cerveau (mémoire permanente pour Claude Code)

Ce dossier est ma mémoire permanente. Claude Code la lit automatiquement au début de chaque
session et l'enrichit au fil du travail : projets, décisions, erreurs déjà payées, endroits
et machines.

**Synchronisé via un dépôt GitHub privé** : quand je change d'ordinateur, une commande me
redonne immédiatement toute ma mémoire.

👉 **Pour tout savoir (installation, premier remplissage, commandes) : lire [`MODE-EMPLOI.md`](MODE-EMPLOI.md).**

---

## Installation en une commande (PC actuel ou PC neuf)

Après avoir installé Claude Code (`claude`) et connecté GitHub CLI (`gh auth login`) :

```bash
curl -fsSL https://raw.githubusercontent.com/ppocass/cerveau-seed/main/installer.sh | bash
```

- **1re fois** : crée ton dépôt **privé** `cerveau` sur ton propre compte GitHub et branche Claude dessus.
- **PC suivants** : retrouve ton dépôt privé, le clone dans `~/cerveau` et configure la machine.

---

## Les deux seules commandes

- **`cerveau`** : enregistre les notes locales, récupère celles des autres PC et envoie sur GitHub.
  *(Tu peux aussi simplement dire « sauvegarde » à Claude.)*
- **`cerveau --etat`** : affiche l'état local sans toucher au réseau.

---

## Structure du dossier

| Fichier | Contenu |
|---|---|
| `MODE-EMPLOI.md` | guide complet (installation, import de projets / export claude.ai, dépannage) |
| `ai-config.md` | règles de fonctionnement chargées par Claude à chaque session |
| `memory-config.md` | format des notes et de l'index |
| `me.md` | mon profil, ma façon de travailler, mes projets |
| `notes/MEMORY.md` | index automatique des notes (chargé à chaque session) |
| `notes/ordinateurs.md` | catalogue de mes machines et de leurs spécificités |
| `notes/*.md` | notes par projet, décision, procédure ou recherche |
| `machines.md` | nom de la machine courante (local uniquement, ignoré par Git) |
