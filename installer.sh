#!/usr/bin/env bash
# Installateur du cerveau.
#
# À lancer sur un ordinateur (neuf ou déjà utilisé), APRÈS avoir installé Claude Code,
# s'être connecté une fois, et s'être connecté à GitHub :
#
#   curl -fsSL https://raw.githubusercontent.com/ppocass/cerveau-seed/main/installer.sh | bash
#
# ou, si le fichier est déjà téléchargé :
#
#   bash installer.sh
#
# Trois cas gérés automatiquement :
#   1. PREMIÈRE FOIS (aucun dépôt « cerveau » sur ton compte GitHub)
#      Crée TON dépôt privé sur ton compte GitHub à partir du squelette de départ.
#      Le dépôt t'appartient dès le premier commit : personne d'autre n'y a accès.
#   2. NOUVEL ORDINATEUR (ton dépôt privé existe déjà sur ton compte GitHub)
#      Retrouve ton dépôt privé et le clone dans ~/cerveau.
#   3. ORDINATEUR DÉJÀ INSTALLÉ (~/cerveau existe déjà sur ce poste)
#      Synchronise tes notes sans rien perdre, met à jour la commande et vérifie la config.
#
# Sauvegarde toujours ce qu'il modifie, et peut être relancé autant de fois qu'on veut.

set -uo pipefail

installer_cerveau() {
  local NOM_DEPOT="${CERVEAU_DEPOT_NOM:-cerveau}"
  local DESTINATION="${CERVEAU_DESTINATION:-$HOME/cerveau}"
  local DEPOT_MODELE="${CERVEAU_MODELE:-https://github.com/ppocass/cerveau-seed.git}"
  local HORO
  HORO=$(date +%Y%m%d-%H%M%S)

  echo "=== Installateur du cerveau ==="
  echo

  # ---------------------------------------------------------------------------
  # 0. S'assurer que ~/.local/bin est dans le PATH (immédiatement + futurs shells)
  # ---------------------------------------------------------------------------
  mkdir -p "$HOME/.local/bin"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) : ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac

  for rc in "$HOME/.profile" "$HOME/.bashrc"; do
    if [ -f "$rc" ]; then
      if ! grep -q '\.local/bin' "$rc" 2>/dev/null; then
        printf '\n# Ajouté par l'\''installateur du cerveau\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
      fi
    fi
  done

  # ---------------------------------------------------------------------------
  # 1. Vérifications des outils
  # ---------------------------------------------------------------------------
  local manquant=0
  for outil in git python3; do
    command -v "$outil" >/dev/null 2>&1 || { echo "  ✗ $outil n'est pas installé."; manquant=1; }
  done

  if ! command -v claude >/dev/null 2>&1; then
    echo "  ✗ claude n'est pas installé."
    echo
    echo "Installe d'abord Claude Code :"
    echo "  curl -fsSL https://claude.ai/install.sh | bash"
    echo "Puis lance « claude » une fois pour te connecter, et relance cet installateur."
    return 1
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo
    echo "  ✗ gh (GitHub CLI) n'est pas installé."
    echo "    Sur Mint / Debian / Ubuntu :  sudo apt install gh"
    echo "    Puis connecte-toi :           gh auth login"
    return 1
  fi

  if [ "$manquant" = "1" ]; then
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo
    echo "  ✗ tu n'es pas connecté à GitHub."
    echo "    Lance :  gh auth login"
    return 1
  fi
  echo "  ✓ git, python3, claude et gh sont là, et GitHub est connecté."

  local COMPTE
  COMPTE=$(gh api user --jq .login </dev/null 2>/dev/null || true)
  if [ -z "$COMPTE" ]; then
    echo "  ✗ impossible de lire ton identifiant GitHub."
    return 1
  fi
  echo "  ✓ compte GitHub : $COMPTE"

  # gh et git sont deux choses : « gh auth login » connecte gh, mais git a besoin
  # du credential helper pour cloner et pousser en HTTPS sur un dépôt privé.
  if ! git config --global --get-regexp 'credential.*helper' 2>/dev/null | grep -q 'gh'; then
    gh auth setup-git </dev/null >/dev/null 2>&1 \
      && echo "  ✓ git branché sur le compte GitHub" \
      || echo "  ⚠ git n'a pas pu être branché automatiquement sur GitHub"
  fi

  local EMAIL NOMGIT
  EMAIL=$(git config --global user.email 2>/dev/null || true)
  NOMGIT=$(git config --global user.name 2>/dev/null || true)
  [ -z "$EMAIL" ] && EMAIL="$COMPTE@users.noreply.github.com"
  [ -z "$NOMGIT" ] && NOMGIT="$COMPTE"

  # ---------------------------------------------------------------------------
  # 1 bis. SAUVEGARDE — avant de toucher à quoi que ce soit
  #
  # Règle absolue : l'installateur ne supprime JAMAIS un fichier de l'utilisateur.
  # Mais on ne parie pas là-dessus : on copie d'abord tout ce qui existe dans un
  # dossier daté sur le Bureau. C'est lui qui décide ensuite s'il le garde.
  # ---------------------------------------------------------------------------
  local BUREAU=""
  for essai_bureau in "$HOME/Desktop" "$HOME/Bureau" "$HOME/desktop"; do
    [ -d "$essai_bureau" ] && { BUREAU="$essai_bureau"; break; }
  done
  if [ -z "$BUREAU" ] && command -v xdg-user-dir >/dev/null 2>&1; then
    essai_bureau=$(xdg-user-dir DESKTOP 2>/dev/null || true)
    [ -n "$essai_bureau" ] && [ -d "$essai_bureau" ] && [ "$essai_bureau" != "$HOME" ] && BUREAU="$essai_bureau"
  fi
  [ -z "$BUREAU" ] && BUREAU="$HOME"

  local SAUVEGARDE
  SAUVEGARDE="$BUREAU/cerveau-sauvegarde-$HORO"

  local A_SAUVER=0
  [ -f "$HOME/.claude/CLAUDE.md" ] && A_SAUVER=1
  [ -f "$HOME/.claude/settings.json" ] && A_SAUVER=1
  if [ -d "$HOME/.claude/projects" ] && \
     find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -name memory -type d 2>/dev/null | head -1 | grep -q .; then
    A_SAUVER=1
  fi

  if [ "$A_SAUVER" = "1" ]; then
    if mkdir -p "$SAUVEGARDE/memoire-ancienne" 2>/dev/null; then
      # Les deux fichiers que l'installateur modifie
      [ -f "$HOME/.claude/CLAUDE.md" ] && cp -p "$HOME/.claude/CLAUDE.md" "$SAUVEGARDE/CLAUDE.md.original" 2>/dev/null
      [ -f "$HOME/.claude/settings.json" ] && cp -p "$HOME/.claude/settings.json" "$SAUVEGARDE/settings.json.original" 2>/dev/null

      # Toutes les anciennes mémoires, projet par projet
      if [ -d "$HOME/.claude/projects" ]; then
        for mem in "$HOME/.claude/projects"/*/memory; do
          [ -d "$mem" ] || continue
          projet=$(basename "$(dirname "$mem")")
          mkdir -p "$SAUVEGARDE/memoire-ancienne/$projet" 2>/dev/null
          cp -Rp "$mem/." "$SAUVEGARDE/memoire-ancienne/$projet/" 2>/dev/null || true
        done
      fi

      # Une note lisible pour lui, plus tard
      cat > "$SAUVEGARDE/LISEZ-MOI.txt" <<EOF
Sauvegarde faite par l'installateur du « cerveau » le $(date '+%d/%m/%Y à %H:%M').

POURQUOI CE DOSSIER
L'installateur ne supprime aucun fichier. Mais il modifie deux choses :
  - ~/.claude/CLAUDE.md      (il y ajoute son bloc à la fin)
  - ~/.claude/settings.json  (il y ajoute la mémoire automatique et les permissions)
Ce dossier contient une copie de ces deux fichiers TELS QU'ILS ÉTAIENT AVANT,
et une copie de toutes les notes de mémoire que Claude Code avait déjà écrites.

CE QUI N'A PAS ÉTÉ TOUCHÉ
  - Tes conversations passées (/resume) : elles sont dans ~/.claude/projects/ et
    n'ont pas été modifiées.
  - Tous tes fichiers de projet.

CE QUE TU PEUX FAIRE
  - Ne rien faire et le garder quelque temps. Il ne gêne personne.
  - Le supprimer quand tu es sûr que tout va bien : c'est toi qui décides.
  - En cas de souci, remettre CLAUDE.md.original à la place de ~/.claude/CLAUDE.md
    et settings.json.original à la place de ~/.claude/settings.json.

Dossier sauvegardé : $SAUVEGARDE
EOF
      echo "  ✓ sauvegarde complète sur le Bureau : $(basename "$SAUVEGARDE")"
    else
      echo "  ⚠ sauvegarde impossible (droits ?) — l'installation continue, rien n'est supprimé"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 2. Récupérer ou créer le dépôt du cerveau
  # ---------------------------------------------------------------------------
  local CREER=0
  local URL_PRIVE="${CERVEAU_URL_PRIVE:-https://github.com/$COMPTE/$NOM_DEPOT.git}"

  if [ -d "$DESTINATION/.git" ]; then
    echo "  → le cerveau est déjà installé ici, je synchronise sans rien perdre"
    git -C "$DESTINATION" config user.email "$EMAIL" 2>/dev/null || true
    git -C "$DESTINATION" config user.name "$NOMGIT" 2>/dev/null || true
    if [ -x "$DESTINATION/bin/cerveau" ]; then
      "$DESTINATION/bin/cerveau" </dev/null || echo "  ⚠ synchronisation distante impossible (réseau ?), copie locale conservée"
    fi

  elif gh repo view "$COMPTE/$NOM_DEPOT" </dev/null >/dev/null 2>&1; then
    echo "  → ton dépôt privé ($COMPTE/$NOM_DEPOT) existe déjà, je le récupère"
    if ! git clone --quiet "$URL_PRIVE" "$DESTINATION" </dev/null; then
      echo "  ✗ impossible de récupérer le dépôt $COMPTE/$NOM_DEPOT"
      return 1
    fi
    # Un dépôt qui existe mais n'a AUCUN commit (créé à la main puis abandonné)
    # se clone « vide » : ni ai-config.md, ni bin/cerveau. Sans ce rattrapage, le
    # reste de l'installation écrivait dans un dossier fantôme et « réussissait ».
    if [ ! -f "$DESTINATION/ai-config.md" ]; then
      echo "  → ce dépôt est vide (aucun contenu dedans) : je le rembourre avec le modèle"
      if ! git clone --quiet --depth 1 "$DEPOT_MODELE" "$DESTINATION/.modele-tmp" </dev/null; then
        echo "  ✗ dépôt vide et modèle inaccessible : je m'arrête."
        echo "    Vérifie ta connexion, puis relance l'installateur."
        return 1
      fi
      # On déplace le contenu du modèle DANS le dépôt vide (sans écraser son .git).
      (cd "$DESTINATION/.modele-tmp" && tar cf - --exclude=.git .) \
        | (cd "$DESTINATION" && tar xf -) 2>/dev/null
      rm -rf "$DESTINATION/.modele-tmp" "$DESTINATION/tests" "$DESTINATION/machines.md"
      if [ ! -f "$DESTINATION/ai-config.md" ] || [ ! -f "$DESTINATION/bin/cerveau" ]; then
        echo "  ✗ impossible de rembourrer le dépôt vide : je m'arrête."
        return 1
      fi
      git -C "$DESTINATION" add -A 2>/dev/null
      git -C "$DESTINATION" -c user.email="$EMAIL" -c user.name="$NOMGIT" \
          commit --quiet -m "cerveau : contenu de départ" 2>/dev/null
      git -C "$DESTINATION" push --quiet 2>/dev/null \
        || echo "  ⚠ contenu en place, mais l'envoi sur GitHub a échoué (réseau ?)"
      echo "  ✓ dépôt vide rempli avec le contenu de départ"
    fi

  else
    CREER=1
    echo "  → première installation : je crée ton dépôt privé ($COMPTE/$NOM_DEPOT)"

    if ! git clone --quiet --depth 1 "$DEPOT_MODELE" "$DESTINATION" </dev/null; then
      echo "  ✗ impossible de récupérer le modèle de départ ($DEPOT_MODELE)"
      echo "    Vérifie ta connexion internet."
      return 1
    fi
    # On ne nettoie QUE si c'est bien le modèle qu'on vient de cloner (ce dossier
    # n'existait pas il y a une seconde) : sans ce garde-fou, on ne supprime rien.
    if [ -f "$DESTINATION/ai-config.md" ] && [ -f "$DESTINATION/installer.sh" ]; then
      rm -rf "$DESTINATION/.git" "$DESTINATION/tests" "$DESTINATION/machines.md"
    else
      echo "  ✗ le contenu récupéré n'est pas celui attendu — je m'arrête sans rien supprimer."
      return 1
    fi

    git -C "$DESTINATION" init --quiet -b main
    git -C "$DESTINATION" config user.email "$EMAIL"
    git -C "$DESTINATION" config user.name "$NOMGIT"
    git -C "$DESTINATION" add -A
    git -C "$DESTINATION" commit --quiet -m "cerveau : première installation"

    if ! gh repo create "$COMPTE/$NOM_DEPOT" --private \
          --source="$DESTINATION" --remote=origin --push </dev/null >/dev/null 2>&1; then
      echo "  ✗ impossible de créer le dépôt GitHub."
      echo "    Essaie à la main :  gh repo create $NOM_DEPOT --private --source=$DESTINATION --push"
      return 1
    fi
  fi

  # Toujours garantir qu'une identité git locale est présente dans le dépôt du cerveau
  # (ainsi, même sur un PC tout neuf où git global n'est pas configuré, tout commit marche).
  git -C "$DESTINATION" config user.email "$EMAIL" 2>/dev/null || true
  git -C "$DESTINATION" config user.name "$NOMGIT" 2>/dev/null || true
  echo "  ✓ cerveau prêt dans $DESTINATION"

  # ---------------------------------------------------------------------------
  # 2 bis. Rassembler les anciennes notes de Claude Code dans un sas (.a-importer)
  #        Elles ne sont PAS copiées en vrac dans notes/ : Claude les réécrit
  #        proprement aux règles du cerveau (une note par projet, sans chemins
  #        absolus), par lots de 60 Ko, pour ne jamais exploser le quota.
  # ---------------------------------------------------------------------------
  local NOM_MACHINE
  NOM_MACHINE="$(hostname 2>/dev/null | cut -d. -f1 | tr -d ' \r\n')"
  [ -z "$NOM_MACHINE" ] && NOM_MACHINE="machine-inconnue"

  local NB_FRAGMENTS
  NB_FRAGMENTS=$(python3 - "$HOME/.claude" "$DESTINATION/.a-importer" "$NOM_MACHINE" <<'PY'
import glob, hashlib, os, re, sys

claude_dir, sas_dir, machine = sys.argv[1], sys.argv[2], sys.argv[3]
projets_dir = os.path.join(claude_dir, "projects")
LIMITE = 60000  # caractères par lot (~15 000 tokens) : un lot tient en un Read

# Mémoire des fragments déjà importés lors d'une exécution précédente :
# relancer l'installateur ne doit pas recréer les mêmes lots.
os.makedirs(sas_dir, exist_ok=True)
vus_path = os.path.join(sas_dir, ".vus")
deja_vus = set()
if os.path.isfile(vus_path):
    try:
        deja_vus = {l.strip() for l in open(vus_path, encoding="utf-8") if l.strip()}
    except Exception:
        deja_vus = set()

def empreinte(contenu):
    return hashlib.sha1(contenu.encode("utf-8", "replace")).hexdigest()

def nouveau(contenu):
    h = empreinte(contenu)
    if h in deja_vus:
        return False
    deja_vus.add(h)
    return True

fragments = []  # (projet lisible, machine, titre, contenu)

def projet_lisible(dossier):
    """Nom du projet : le cwd réel si on le trouve, sinon le nom de dossier décodé."""
    jsons = sorted(glob.glob(os.path.join(dossier, "*.jsonl")))
    for j in jsons[:1]:
        try:
            with open(j, encoding="utf-8", errors="replace") as f:
                for i, ligne in enumerate(f):
                    if i > 5: break
                    m = re.search(r'"cwd"\s*:\s*"([^"]+)"', ligne)
                    if m:
                        return m.group(1).replace("\\/", "/")
        except Exception:
            pass
    nom = os.path.basename(dossier).strip("-")
    return nom.replace("-", "/") if nom else "inconnu"

# 1. Les anciennes mémoires par projet
if os.path.isdir(projets_dir):
    for mem_dir in sorted(glob.glob(os.path.join(projets_dir, "*", "memory"))):
        if not os.path.isdir(mem_dir):
            continue
        projet = projet_lisible(os.path.dirname(mem_dir))
        for src in sorted(glob.glob(os.path.join(mem_dir, "*.md"))):
            base = os.path.basename(src)
            try:
                contenu = open(src, encoding="utf-8", errors="replace").read().strip()
            except Exception:
                continue
            if not contenu or (base == "MEMORY.md" and len(contenu) < 40):
                continue
            if nouveau(contenu):
                fragments.append((projet, machine, base, contenu))

# 2. L'ancien CLAUDE.md global (ses règles personnelles d'avant le cerveau)
ancien = os.path.join(claude_dir, "CLAUDE.md")
if os.path.isfile(ancien):
    try:
        contenu = open(ancien, encoding="utf-8", errors="replace").read().strip()
        if contenu and ">>> cerveau >>>" not in contenu and nouveau("claude-md:" + contenu):
            fragments.append(("Réglages globaux de Claude Code", machine, "CLAUDE.md", contenu))
    except Exception:
        pass

# 3. La liste des dossiers de projets où il a travaillé sur ce PC
if os.path.isdir(projets_dir):
    dossiers = sorted({projet_lisible(d) for d in glob.glob(os.path.join(projets_dir, "*")) if os.path.isdir(d)})
    if dossiers:
        liste = "\n".join(f"- {d}" for d in dossiers)
        fragments.append(("Liste des projets travaillés sur cette machine", machine, "projets",
                          f"Dossiers de projets connus sur la machine `{machine}` :\n\n{liste}"))

# 4. Découpage en lots de LIMITE caractères (on ne coupe jamais un fragment en deux
#    s'il tient seul ; sinon on le tronque proprement)
lots, courant, taille = [], [], 0
for projet, mach, titre, contenu in fragments:
    bloc = f"\n\n## Source : {projet} (machine : {mach}) — {titre}\n\n{contenu}\n"
    if len(bloc) > LIMITE:
        bloc = bloc[:LIMITE] + "\n\n[…tronqué]"
    if taille + len(bloc) > LIMITE and courant:
        lots.append("".join(courant)); courant, taille = [], 0
    courant.append(bloc); taille += len(bloc)
if courant:
    lots.append("".join(courant))

if lots:
    for i, contenu in enumerate(lots, 1):
        entete = (f"# Anciennes notes de Claude Code à assimiler — lot {i}/{len(lots)}\n"
                  f"# Machine d'origine : {machine}\n")
        with open(os.path.join(sas_dir, f"lot-{i}.md"), "w", encoding="utf-8") as f:
            f.write(entete + contenu)

# On note ce qui a été vu, pour ne pas recréer ces lots à la prochaine relance.
try:
    with open(vus_path, "w", encoding="utf-8") as f:
        f.write("\n".join(sorted(deja_vus)) + "\n")
except Exception:
    pass

print(len(fragments))
PY
  )

  if [ "${NB_FRAGMENTS:-0}" -gt 0 ] 2>/dev/null; then
    NBLOTS=$(find "$DESTINATION/.a-importer" -maxdepth 1 -name 'lot-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ $NB_FRAGMENTS ancien(s) élément(s) trouvé(s) — répartis en $NBLOTS lot(s)"
    if [ "${CERVEAU_SANS_IMPORT:-0}" = "1" ]; then
      echo "  → import reporté (CERVEAU_SANS_IMPORT=1) : lance « cerveau --importer » quand tu veux"
    else
      echo "  → Claude les lit et les réécrit aux règles du cerveau (une session, effort bas)…"
      "$DESTINATION/bin/cerveau" --importer </dev/null || echo "  ⚠ import interrompu — relance « cerveau --importer » plus tard"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 3. Le nom de cette machine (NOM_MACHINE est déjà calculé à l'étape 2 bis)
  # ---------------------------------------------------------------------------
  cat > "$DESTINATION/machines.md" <<EOF
# Où je suis

> ⚠️ Ce fichier n'est **pas** sur GitHub : il change d'un ordinateur à l'autre.
> C'est l'installateur qui l'a créé, avec le bon nom dedans.

je suis sur : $NOM_MACHINE

*(le catalogue de toutes les machines est dans \`notes/ordinateurs.md\` — celui-là est partagé.)*
EOF
  echo "  ✓ machine enregistrée : $NOM_MACHINE"

  # ---------------------------------------------------------------------------
  # 4. Le mot d'accueil de Claude (~/.claude/CLAUDE.md)
  #    On utilise @chemin pour que Claude Code charge directement les règles et
  #    l'identité en contexte dès la seconde 0, sans dépenser d'appel Read.
  # ---------------------------------------------------------------------------
  mkdir -p "$HOME/.claude"
  local ACCUEIL="$HOME/.claude/CLAUDE.md"
  local DEBUT="# >>> cerveau >>>"
  local FIN="# <<< cerveau <<<"
  local BLOC="$DEBUT
# Ma mémoire permanente (cerveau)

Dossier du cerveau : \`$DESTINATION\`
Les règles, mon identité et le nom de cette machine sont chargés ci-dessous :

@$DESTINATION/ai-config.md
@$DESTINATION/memory-config.md
@$DESTINATION/me.md
@$DESTINATION/machines.md

- Tes notes vivent dans \`$DESTINATION/notes/\` (index \`MEMORY.md\` chargé automatiquement).
- Quand on te demande de sauvegarder ou d'envoyer sur GitHub : lance \`cerveau\` (ou \`$DESTINATION/bin/cerveau\`).
$FIN"

  if [ -L "$ACCUEIL" ]; then
    mv "$ACCUEIL" "$ACCUEIL.avant-cerveau-$HORO"
    printf '%s\n' "$BLOC" > "$ACCUEIL"
    echo "  → ancien lien CLAUDE.md mis de côté, mot d'accueil écrit"

  elif [ -f "$ACCUEIL" ]; then
    cp "$ACCUEIL" "$ACCUEIL.avant-cerveau-$HORO"
    if grep -qF "$DEBUT" "$ACCUEIL"; then
      python3 - "$ACCUEIL" "$DEBUT" "$FIN" "$BLOC" <<'PY'
import sys
chemin, debut, fin, bloc = sys.argv[1:5]
with open(chemin, encoding="utf-8") as f:
    lignes = f.read().split("\n")
sortie, dedans = [], False
for l in lignes:
    if l.strip() == debut:
        dedans = True
        sortie.append(bloc)
        continue
    if l.strip() == fin:
        dedans = False
        continue
    if not dedans:
        sortie.append(l)
with open(chemin, "w", encoding="utf-8") as f:
    f.write("\n".join(sortie))
PY
      echo "  → bloc du cerveau mis à jour dans ton CLAUDE.md (le reste est intact)"
    else
      printf '\n\n%s\n' "$BLOC" >> "$ACCUEIL"
      echo "  → bloc ajouté à la fin de ton CLAUDE.md (tes instructions restent intactes)"
    fi

  else
    printf '%s\n' "$BLOC" > "$ACCUEIL"
    echo "  ✓ mot d'accueil écrit dans $ACCUEIL"
  fi

  # ---------------------------------------------------------------------------
  # 5. La commande cerveau dans ~/.local/bin/cerveau
  # ---------------------------------------------------------------------------
  if [ ! -f "$DESTINATION/bin/cerveau" ]; then
    echo "  ✗ $DESTINATION/bin/cerveau est absent : l'installation ne peut pas continuer."
    echo "    Le dossier du cerveau est incomplet. Relance l'installateur ;"
    echo "    si ça se reproduit, supprime $DESTINATION et relance."
    return 1
  fi
  cp -f "$DESTINATION/bin/cerveau" "$HOME/.local/bin/cerveau"
  chmod 755 "$HOME/.local/bin/cerveau" "$DESTINATION/bin/cerveau"
  echo "  ✓ commande installée dans ~/.local/bin/cerveau"

  # ---------------------------------------------------------------------------
  # 6. Brancher autoMemoryDirectory, permissions et hook SessionStart (--auto)
  # ---------------------------------------------------------------------------
  local REGLAGES="$HOME/.claude/settings.json"
  [ -f "$REGLAGES" ] && cp "$REGLAGES" "$REGLAGES.avant-cerveau-$HORO"

  python3 - "$REGLAGES" "$DESTINATION" <<'PY'
import json, os, sys

chemin, cerveau = sys.argv[1], sys.argv[2]

donnees = {}
if os.path.exists(chemin):
    try:
        with open(chemin, encoding="utf-8") as f:
            donnees = json.load(f)
    except Exception:
        donnees = {}

# 1. Mémoire automatique native dirigée vers ~/cerveau/notes
donnees["autoMemoryDirectory"] = os.path.join(cerveau, "notes")

# 2. Permissions : accès au dossier du cerveau + commandes cerveau et git
perm = donnees.setdefault("permissions", {})
dirs = perm.setdefault("additionalDirectories", [])
if cerveau not in dirs:
    dirs.append(cerveau)

allow = perm.setdefault("allow", [])
cmd_cerveau = os.path.join(cerveau, "bin", "cerveau")
for regle in (
    f"Edit({cerveau}/**)",
    f"Read({cerveau}/**)",
    "Bash(cerveau)",
    "Bash(cerveau *)",
    f"Bash({cmd_cerveau})",
    f"Bash({cmd_cerveau} *)",
    "Bash(git add *)",
    "Bash(git commit *)",
    "Bash(git push *)",
    "Bash(git pull *)",
    "Bash(git status *)",
    "Bash(git log *)",
    "Bash(git diff *)",
    f"Bash(git -C {cerveau} *)",
):
    if regle not in allow:
        allow.append(regle)

# 3. Hook SessionStart : lance cerveau --auto en tâche de fond au démarrage
#    (ne fait rien si < 4 h, ne bloque jamais plus de 5 s).
hooks = donnees.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])
commande_auto = f"{cmd_cerveau} --auto"
deja_present = False
for bloc_hook in session_start:
    for h in bloc_hook.get("hooks", []):
        if "cerveau" in h.get("command", "") and "--auto" in h.get("command", ""):
            h["command"] = commande_auto
            h["timeout"] = 10
            h["async"] = True
            deja_present = True
if not deja_present:
    session_start.append({
        "hooks": [
            {
                "type": "command",
                "command": commande_auto,
                "timeout": 10,
                "async": True,
            }
        ]
    })

os.makedirs(os.path.dirname(chemin), exist_ok=True)
with open(chemin, "w", encoding="utf-8") as f:
    json.dump(donnees, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

  if python3 -m json.tool "$REGLAGES" >/dev/null 2>&1; then
    echo "  ✓ mémoire automatique et synchro de démarrage branchées"
  else
    echo "  ⚠ réglages non modifiés — vérifie $REGLAGES"
  fi

  # ---------------------------------------------------------------------------
  # Bilan
  # ---------------------------------------------------------------------------
  echo
  echo "=== C'est prêt ==="
  echo
  if [ "$CREER" = "1" ]; then
    echo "  Ton dépôt privé :  https://github.com/$COMPTE/$NOM_DEPOT"
    echo "  (personne d'autre n'y a accès ; tu peux le vérifier sur GitHub)"
    echo
  fi
  echo "  Lance Claude où tu veux :   claude"
  echo "  Pour synchroniser :         cerveau"
  echo "  Pour voir où tu en es :     cerveau --etat"
  echo
  echo "Mode d'emploi complet :       $DESTINATION/MODE-EMPLOI.md"
  if [ -d "$SAUVEGARDE" ]; then
    echo
    echo "⚠ Une sauvegarde de tes fichiers d'avant a été posée sur le Bureau :"
    echo "    $(basename "$SAUVEGARDE")"
    echo "  Garde-la quelque temps. Rien n'a été supprimé ; c'est toi qui décides"
    echo "  quand la retirer (ouvre son LISEZ-MOI.txt pour le détail)."
  fi
}

installer_cerveau "$@"
CODE=$?
if [ "$CODE" -ne 0 ]; then
  echo
  echo "=== L'installation s'est arrêtée avant la fin (code $CODE) ==="
  echo "Rien n'a été supprimé. Corrige le point signalé ci-dessus, puis relance"
  echo "la même commande : elle reprendra où elle s'est arrêtée."
  exit "$CODE"
fi
