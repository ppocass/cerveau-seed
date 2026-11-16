# Mon cerveau (mémoire permanente pour Claude Code)

Ce dossier est ma mémoire permanente. Claude Code la lit automatiquement au début de chaque
session et l'enrichit au fil du travail : projets, décisions, erreurs déjà payées, endroits
et machines.

**Synchronisé via un dépôt GitHub privé** : quand je change d'ordinateur, une commande me
redonne immédiatement toute ma mémoire.

**Pour tout savoir (installation, premier remplissage, commandes) : lire [`MODE-EMPLOI.md`](MODE-EMPLOI.md).**

---

## Installation en une commande (PC actuel ou PC neuf)

Après avoir installé Claude Code (`claude`) et connecté GitHub CLI (`gh auth login`) :

```bash
curl -fsSL https://raw.githubusercontent.com/ppocass/cerveau-seed/main/installer.sh | bash
```

- **1re fois** : crée ton dépôt **privé** `cerveau` sur ton propre compte GitHub et branche Claude dessus.
- **PC suivants** : retrouve ton dépôt privé, le clone dans `~/cerveau` et configure la machine.

---

## Si tu es un agent IA (Claude Code…) à qui on a donné ce lien pour l'installer

Ton utilisateur veut que tu installes ce cerveau à sa place. Suis exactement ces étapes :

1. **Vérifie les prérequis** : `gh auth status` doit montrer un compte connecté, et `git`,
   `python3` et `claude` doivent exister. S'il manque quelque chose, dis-le-lui simplement
   et arrête-toi là.
2. **Installe sans l'import** (rapide, aucune question posée) :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ppocass/cerveau-seed/main/installer.sh | CERVEAU_SANS_IMPORT=1 bash
   ```
   Attention, ne lance pas l'installateur sans `CERVEAU_SANS_IMPORT=1` : l'import démarre une autre
   session Claude qui peut durer jusqu'à 15 minutes, et ta commande serait coupée en plein milieu.
3. **Lance l'import de ses anciennes notes en arrière-plan** (s'il en a), puis attends qu'il finisse :
   ```bash
   ~/cerveau/bin/cerveau --importer
   ```
   (utilise ton mode « arrière-plan » ; s'il n'y a rien à importer, la commande le dit et s'arrête.)
4. **Vérifie** avec `~/cerveau/bin/cerveau --etat`.
5. **Fais-lui un résumé court** : où est son dépôt privé, ce qui a été importé, où est la
   sauvegarde posée sur son Bureau, et qu'il doit **redémarrer Claude Code** pour que la
   mémoire soit chargée.

**Attention, si quoi que ce soit se passe mal, à n'importe quelle étape :** n'essaie pas de bricoler
une solution, arrête-toi et préviens ton utilisateur tout de suite avec un rapport détaillé,
qu'il pourra transmettre tel quel à la personne qui lui a donné ce cerveau :
- l'étape où ça a cassé et la commande exacte lancée ;
- le message d'erreur **complet**, recopié sans le résumer ;
- le système (`uname -a`, distribution, versions de `git`, `gh`, `python3`, `claude`) ;
- ce qui a déjà été modifié sur la machine (`~/cerveau`, `~/.claude/CLAUDE.md`,
  `~/.claude/settings.json`) et le nom du dossier de sauvegarde posé sur le Bureau.

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
