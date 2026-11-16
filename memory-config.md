# Comment écrire une note

Ce fichier règle **une seule chose** : la forme des notes dans `notes/`. Quand écrire et
quoi retenir, c'est dans `ai-config.md`.

La mémoire automatique native de Claude Code (`autoMemoryDirectory`) est pointée sur
`notes/` par l'installateur. On utilise un en-tête YAML compatible à la fois avec le
moteur natif de Claude Code et avec nos propres filtres.

---

## Le format d'une note

Chaque note dans `notes/` commence par cet en-tête entre deux lignes `---` :

```markdown
---
name: decision-integration-rk4
description: "Schéma d'intégration RK4 retenu à la place d'Euler pour la simulation"
metadata:
  node_type: memory
  type: "décision"
  statut: "actif"
  machine: "commun"
  mots-cles: "Runge-Kutta 4, Euler, intégration, simulation"
---

# Moteur physique : Runge-Kutta 4, pas Euler

Le contenu de la note.
```

- `name` : le nom court de la note (le nom du fichier sans `.md`, en minuscules avec tirets).
- `description` : **entre guillemets**, une phrase courte qui résume la note (utilisée par
  Claude Code pour décider quand la rappeler).
- `node_type: memory` : **obligatoire** sous `metadata:`.
- Si Claude Code ajoute `originSessionId` ou `modified`, **ne les retire pas**.

### Les quatre champs de classement (sous `metadata:`)

| Champ | Valeurs possibles | À quoi ça sert |
|---|---|---|
| `type` | `"projet"` · `"décision"` · `"procédure"` · `"recherche"` · `"référence"` · `"note"` | nature de la note |
| `statut` | `"actif"` · `"en-attente"` · `"fini"` · `"abandonné"` | est-ce toujours d'actualité |
| `machine` | `"commun"` · le nom d'un ordinateur (voir `notes/ordinateurs.md`) | où ça existe |
| `mots-cles` | `"3 à 6 mots, séparés par des virgules"` | retrouver par thème |

### Attention, le piège YAML : toujours mettre les chaînes entre guillemets

Une valeur contenant `:` ou des caractères spéciaux sans guillemets casse l'en-tête YAML
en silence et rend la note illisible. Mets **toujours** `description` et `mots-cles` (et de
préférence tous les champs texte) entre guillemets doubles `"..."`.

---

## Où va la note et comment la nommer

**Un fichier par sujet**, dans `notes/`, à plat :

| Le sujet | Le nom du fichier |
|---|---|
| un projet | `notes/<sujet>.md` — ex. `notes/aeris.md` |
| une décision | `notes/decision-<sujet>.md` |
| une procédure | `notes/procedure-<sujet>.md` |
| une recherche / comparaison | `notes/recherche-<sujet>.md` |

Deux à quatre mots, minuscules, traits d'union, sans accents dans le nom de fichier.
**Un sujet déjà traité → on enrichit la note existante**, on n'en crée pas une deuxième.

Si un projet dépasse **cinq notes**, ouvre un sous-dossier `notes/<projet>/` avec une note
d'entrée `vue-ensemble-<projet>.md`. Pas avant.

---

## Ce que doit contenir une note

Ni un compte-rendu chronologique, ni un simple point d'avancement.
**« Où on en est » tout seul ne sert à rien** : c'est un tableau de bord, pas une mémoire.

Le critère unique : **qu'est-ce que la prochaine session ne doit pas avoir à réapprendre ?**

1. **Les erreurs déjà faites, et ce qu'elles ont coûté** — ce qui a cassé, les fausses
   bonnes idées déjà tentées et abandonnées (« on a essayé X, ça diverge au-delà de Y »).
   C'est la partie la plus précieuse, et celle qu'on oublie toujours si on n'y veille pas.
2. **Les endroits** — où vivent les dépôts, les données, les scripts, sur quelle machine
   (`notes/ordinateurs.md`), quel service ou quel port.
3. **Les décisions et leur pourquoi** — sans le pourquoi, on rouvre le même débat six mois
   plus tard et on refait la même erreur.
4. **Les contraintes découvertes** — limites matérielles, bugs d'une bibliothèque, seuils
   de convergence, temps de calcul mesurés.
5. **Les chiffres et paramètres de référence** — valeurs physiques, versions, constantes
   validées qu'on ne veut pas recalculer.

Et **relie les notes entre elles** avec `[[nom-de-la-note]]` (sans chemin, sans `.md`).

---

## Tenir l'index `notes/MEMORY.md` à jour

`notes/MEMORY.md` est **chargé automatiquement** au début de chaque session (plafond :
200 lignes ou 25 Ko). C'est ton sommaire : **une seule ligne par note**, jamais de blocs
de texte dedans.

```markdown
- [nom-de-la-note](nom-de-la-note.md) — résumé court en une demi-phrase
```

- Dès que tu crées une note dans `notes/`, **ajoute sa ligne dans `notes/MEMORY.md`**.
- Si tu fusionnes ou retires une note, mets `notes/MEMORY.md` à jour immédiatement.

---

## Quand une note ne vaut que sur un ordinateur précis

Elle porte `machine: "<nom-de-la-machine>"` dans son en-tête **et** un bandeau juste sous
le titre :

```markdown
> Attention, ceci n'existe que sur **portable-mint** ; sur un autre poste, demande avant d'agir.
```

---

## Ce qui n'entre pas dans ce dossier

- **Les images et binaires** (`.png`, `.jpg`, `.pdf`…) : exclus par `.gitignore` pour que
  le dépôt reste léger et se clone en une seconde même sur une connexion à 3 Mbps.
- **Le code source des projets** : il vit dans ses propres dépôts Git. Ici, on note où il
  est, comment il marche et quels pièges il contient.
- **La transcription brute d'une session** : on garde les conclusions, les pièges et les
  décisions, pas le bavardage.
