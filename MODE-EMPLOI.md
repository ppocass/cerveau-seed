# Cerveau — mode d'emploi

Ce dossier est la mémoire permanente de ton Claude Code : tes projets, tes choix
techniques, les erreurs déjà rencontrées pour ne pas les repayer, et les particularités de
chacune de tes machines.

Il la lit automatiquement au début de chaque session et la met à jour au fur et à mesure
qu'il travaille avec toi. **Quand tu changes de PC, une seule commande te redonne le même
assistant au courant de tout.**

---

## 1. Installation (sur ton PC actuel comme sur un PC neuf)

Assure-toi d'avoir **Claude Code** installé et connecté (`claude`), ainsi que **GitHub CLI**
connecté à ton compte (`sudo apt install gh` puis `gh auth login`).

Ensuite, colle cette unique ligne dans ton terminal :

```bash
curl -fsSL https://raw.githubusercontent.com/ppocass/cerveau-seed/main/installer.sh | bash
```

*(Si tu as déjà le dossier sous la main, tu peux aussi lancer `bash installer.sh`.)*

### Ce qui se passe automatiquement :
- **La toute première fois** : l'installateur crée un dépôt **privé** `cerveau` sur **ton
  propre compte GitHub**, y dépose l'ossature de départ et branche ton Claude Code dessus.
  Le dépôt naît chez toi : personne d'autre n'y a accès.
- **Sur chaque nouveau PC ensuite** : tu colles exactement **la même commande**. Elle voit
  que ton dépôt privé `cerveau` existe déjà sur ton GitHub, le récupère dans `~/cerveau`,
  et configure ce nouveau PC en quelques secondes.
- **Si tu avais déjà un `~/.claude/CLAUDE.md` ou un `settings.json`** : rien n'est écrasé.
  Le bloc du cerveau est ajouté proprement à la suite de tes règles existantes. Si
  `settings.json` est abîmé (commentaires, virgule finale, fichier tronqué), il est réparé
  sans perdre tes clés ; s'il est vraiment illisible, l'installateur s'arrête en te montrant
  la copie de secours au lieu de l'effacer.

### Ce qui est sauvegardé, et ce qui n'est jamais touché

**L'installateur ne supprime aucun fichier.** Il ne fait qu'**ajouter** : son bloc à la fin
de `~/.claude/CLAUDE.md`, ses clés dans `~/.claude/settings.json`, et une ligne dans
`~/.profile` / `~/.bashrc` pour que la commande `cerveau` soit trouvée dans un terminal.
Tes règles et tes réglages existants restent en place.

Et il ne te demande pas de le croire : **avant de toucher à quoi que ce soit**, il copie sur
ton Bureau un dossier daté `cerveau-sauvegarde-AAAAMMJJ-HHMMSS/` contenant :

| Fichier | Quoi |
|---|---|
| `CLAUDE.md.original` | ton `~/.claude/CLAUDE.md` tel qu'il était avant |
| `settings.json.original` | ton `~/.claude/settings.json` tel qu'il était avant |
| `profile.original` / `bashrc.original` | tes fichiers de démarrage du shell, s'ils existaient |
| `memoire-ancienne/<projet>/` | une copie de toutes les notes déjà écrites par Claude Code |
| `LISEZ-MOI.txt` | ce qui a été fait, ce qui n'a pas été touché, comment revenir en arrière |

Le nom de chaque copie est celui du fichier d'origine **sans son point initial**, plus
`.original` : `profile.original` est la copie de `~/.profile`, `bashrc.original` celle de
`~/.bashrc`. Le `LISEZ-MOI.txt` les nomme exactement comme ils sont écrits dans le dossier.

Tu peux relancer la même commande autant de fois que tu veux : si rien n'a changé depuis la
dernière sauvegarde, l'installateur **réutilise** ce dossier au lieu d'en empiler un nouveau,
et ne laisse pas non plus de nouvelle copie `.avant-cerveau-*` dans `~/.claude/`. Une
sauvegarde existante n'est jamais supprimée.

Restent **intactes** : tes conversations passées (`/resume`) et tous tes fichiers de projet.
Le dossier de sauvegarde, tu en fais ce que tu veux — le garder un moment, ou le supprimer
quand tu es tranquille. C'est toi qui décides.

---

## 2. Premier jour : remplir le cerveau avec tes projets existants

Au départ, `me.md` (qui tu es) et `notes/` sont presque vides. Tu peux travailler
normalement et laisser Claude les remplir au fil de l'eau, **ou** lui faire absorber
l'existant tout de suite :

### A. Documenter un projet qui est déjà sur ton PC
Ouvre un terminal dans le dossier d'un de tes projets (Python, simulation, VR…) et lance
`claude`, puis dis-lui :
> « Analyse ce projet et documente-le dans ma mémoire (`~/cerveau/notes/`). Ne fais pas un
> résumé superficiel : note l'architecture, où sont les fichiers clés, les choix techniques,
> les contraintes et les pièges du code. Mets aussi `me.md` et `ordinateurs.md` à jour. »

### B. Récupérer tes projets depuis un export `claude.ai` (cloud Anthropic)
Si tu as beaucoup de projets dans l'interface web `claude.ai`, demande l'export de tes
données dans les paramètres de ton compte `claude.ai` (tu reçois un `.zip` contenant
`conversations.json` et `projects.json`). Décompresse-le dans un dossier, lance `claude`
dedans et dis-lui :
> « Voici mon export claude.ai. Parcours les projets et conversations par lots. Pour chaque
> vrai projet ou sujet technique, écris une note complète dans `~/cerveau/notes/` : pas un
> résumé chronologique, mais tout ce qu'il ne faut plus jamais avoir à réapprendre (les
> erreurs et pistes abandonnées, les décisions et leur pourquoi, les formules/seuils, les
> contraintes et où sont les fichiers). Mets à jour `MEMORY.md` et `me.md` au fur et à
> mesure, puis lance `cerveau` à la fin. »

### C. Récupérer tes anciennes sessions locales Claude Code
Sur ton PC actuel, tes sessions passées vivent dans `~/.claude/projects/`. Tu peux dire à
Claude :
> « Parcours mes sessions récentes dans `~/.claude/projects/` pour repérer mes projets en
> cours, les problèmes sur lesquels j'ai buté et mes préférences de travail, et note-les
> dans `~/cerveau/notes/` et `~/cerveau/me.md`. »

### D. Ce que l'installateur fait déjà tout seul (tes anciennes notes)
Au moment de l'installation, l'installateur repère les anciennes notes que Claude Code
avait écrites avant le cerveau (dans `~/.claude/projects/*/memory/`), ainsi que ton ancien
`~/.claude/CLAUDE.md`. Il ne les copie **pas** en vrac : il les regroupe par lots de 60 Ko
dans un sas (`~/cerveau/.a-importer/`), puis lance une session Claude (Sonnet, effort bas)
par lot : elle les lit, les fusionne par projet, supprime les chemins absolus, marque
chaque note avec la bonne machine, remplit `me.md` et `notes/ordinateurs.md`, puis
synchronise sur GitHub.

- Tu n'as rien à faire : ça se déclenche à la fin de l'installation, et **tous les lots en
  attente sont traités d'affilée** — inutile de relancer la commande.
- La valeur d'un mot de passe, d'un code d'accès, d'une clé d'API, d'un jeton ou d'un code
  PIN n'est **jamais** recopiée dans le cerveau (le dépôt part sur GitHub) : le modèle
  écrit à la place une mention utile, et termine en listant ce qu'il n'a pas recopié dans
  une section « Retiré : ». `cerveau` te l'affiche à la fin de chaque lot.
- Tes fichiers d'origine ne sont **jamais supprimés** : ils restent dans `~/.claude/projects/`.

---

## 3. Au quotidien : les commandes

Il n'y a qu'une seule commande à connaître, à taper dans le terminal (ou à demander à
Claude en lui disant simplement « sauvegarde ») :

### `cerveau`
- Enregistre en local les notes que Claude a écrites ou modifiées ;
- Récupère ce qui a été écrit sur tes autres ordinateurs ;
- Envoie tout sur ton dépôt GitHub privé ;
- Affiche une ligne : `cerveau : à jour.` ou `cerveau : 2 envoyée(s), 1 récupérée(s).`

**Quand le faire ?** En fin de journée, ou avant de changer de PC.
La **récupération**, elle, se fait aussi toute seule en arrière-plan quand tu ouvres Claude
Code (au maximum une fois toutes les 4 heures). Elle laisse jusqu'à 9 secondes par commande
réseau pour ne pas échouer sur une connexion lente ; comme elle tourne en tâche de fond
(hook asynchrone), elle ne retarde jamais l'ouverture de Claude.

### `cerveau --etat`
Montre où tu en es sans toucher au réseau : quel est le nom de cette machine, combien de
notes attendent d'être envoyées, de quand date la dernière synchro et combien de notes
compte ton cerveau. Il liste aussi les fichiers `.conflit-…` encore présents (voir §5) :
tant qu'ils sont là, tu sais qu'une version locale attend d'être relue.

### `cerveau --importer`
Fait digérer par Claude **tous les lots** d'anciennes notes en attente dans
`~/cerveau/.a-importer/` (voir §2.D), l'un après l'autre, et termine par
`cerveau : N lot(s) importé(s).` Si un lot échoue, la commande s'arrête là avec le message
habituel : les lots suivants restent dans le sas, intacts, pour une prochaine fois. Tu n'en
as besoin que si l'installateur t'a dit qu'il restait des lots. Pour choisir le modèle
utilisé : `CERVEAU_MODELE_IMPORT`.

---

## 4. Ce qu'il y a dans `~/cerveau`

| Fichier | Rôle | Qui s'en occupe ? |
|---|---|---|
| `ai-config.md` | les règles de comportement de Claude | déjà configuré |
| `memory-config.md` | comment Claude structure et relie ses notes | déjà configuré |
| `me.md` | qui tu es, ton métier, tes préférences, la liste de tes projets | Claude (et toi si tu veux) |
| `notes/MEMORY.md` | l'index chargé automatiquement à chaque session | Claude |
| `notes/ordinateurs.md` | le catalogue de tes PC et ce qui est propre à chacun | Claude |
| `notes/*.md` | toutes les notes (projets, décisions, erreurs payées, procédures) | Claude |
| `machines.md` | le nom du PC actuel (**exclu de GitHub**, propre à chaque machine) | l'installateur |

---

## 5. En cas de pépin

| Situation | Ce qui se passe / quoi faire |
|---|---|
| **Pas d'internet / Wi-Fi très lent** | Rien ne bloque et rien ne se perd : `cerveau` enregistre tes notes sur le disque et les enverra dès que le réseau reviendra. En automatique, un échec réseau est signalé dans les journaux, jamais présenté comme « à jour ». |
| **Un dépôt `cerveau` existe déjà et il est public** | L'installateur refuse d'y envoyer tes notes et te propose de le rendre privé, ou de choisir un autre nom (`CERVEAU_DEPOT_NOM=cerveau-prive bash installer.sh`). |
| **`settings.json` vraiment illisible** | L'installateur s'arrête sans le remplacer : il indique le chemin de la copie de secours. Corrige ou renomme le fichier, puis relance. |
| **Installation interrompue (coupure, `kill -9`, Ctrl-C)** | Relance simplement la même commande. Un `~/cerveau` à moitié copié depuis le dépôt modèle est détecté (son `origin` ne mène pas à ton dépôt) et remis sur ton dépôt privé avant toute synchronisation ; un import interrompu laisse un marqueur `.en-cours` avec son PID, qui est ignoré et retiré si ce processus est mort. Rien n'est perdu, et « C'est prêt » n'est jamais affiché sans que ton commit local soit arrivé sur ton dépôt. |
| **Deux PC ont modifié la même note avant synchro** | Aucune perte et aucun fichier cassé : la version de l'autre PC est mise au chemin normal, et ta version locale est sauvegardée juste à côté sous `notes/<nom>.conflit-<machine>-<date>.md`. `cerveau --etat` te liste ces fichiers tant qu'ils existent, pour que tu recopies ce qui compte. |
| **« GitHub refuse la connexion — le jeton a expiré »** | Tape `gh auth login` dans ton terminal. |
| **Une note a été abîmée par erreur** | Tout est versionné dans Git : `git -C ~/cerveau log --oneline` puis `git -C ~/cerveau checkout <commit> -- notes/<fichier>.md`. |
