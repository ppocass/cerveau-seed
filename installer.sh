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

# Aucune commande git ou gh ne doit pouvoir demander une saisie. Sous
# « curl | bash », git demande les identifiants sur /dev/tty (pas sur stdin,
# donc les « </dev/null » ne suffisent pas) : sans ça, l'installation reste
# bloquée sans message devant une invite que personne ne voit venir.
# Un échec d'authentification devient une erreur nette, avec la marche à suivre.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS="/bin/true"
export SSH_ASKPASS="${SSH_ASKPASS:-/bin/true}"
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"

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

  # La ligne exacte qu'on ajoute aux fichiers de démarrage du shell. On la teste
  # telle quelle : chercher « .local/bin » trouvait aussi les commentaires.
  local LIGNE_PATH='export PATH="$HOME/.local/bin:$PATH"'
  # Fichiers rc déjà présents qu'il faudra compléter (donc sauvegarder avant),
  # et fichiers rc à créer : sans eux, « cerveau » reste introuvable après une
  # reconnexion. La liste dépend du shell : bash lit .bash_profile (macOS) ou
  # .profile, zsh lit .zprofile puis .zshrc. Poser la ligne dans un fichier que
  # le shell ne lit jamais ne sert à rien (BUG-3 ne corrigeait que Linux).
  local SHELL_UTILISATEUR
  SHELL_UTILISATEUR=$(basename "${SHELL:-}" 2>/dev/null || true)
  [ -n "$SHELL_UTILISATEUR" ] || SHELL_UTILISATEUR="bash"

  local RC_CANDIDATS=()
  if [ "$SHELL_UTILISATEUR" = "zsh" ]; then
    # zsh : .zshrc pour les shells interactifs ; .zprofile (lu à la connexion)
    # seulement s'il existe déjà, pour ne pas créer un fichier de plus.
    RC_CANDIDATS+=("$HOME/.zshrc")
    [ -f "$HOME/.zprofile" ] && RC_CANDIDATS+=("$HOME/.zprofile")
  else
    # bash : .bash_profile est lu à la connexion quand il existe (macOS) et
    # .profile ne l'est plus dans ce cas ; .bashrc reste lu par les shells
    # interactifs non connectés.
    RC_CANDIDATS+=("$HOME/.profile" "$HOME/.bashrc")
    [ -f "$HOME/.bash_profile" ] && RC_CANDIDATS+=("$HOME/.bash_profile")
  fi

  local RC_EXISTANTS=() RC_A_CREER=()
  for rc in "${RC_CANDIDATS[@]}"; do
    if [ -f "$rc" ]; then
      grep -qxF "$LIGNE_PATH" "$rc" 2>/dev/null || RC_EXISTANTS+=("$rc")
    elif [ "$rc" = "$HOME/.profile" ] || [ "$rc" = "$HOME/.zshrc" ]; then
      RC_A_CREER+=("$rc")
    fi
  done

  # ---------------------------------------------------------------------------
  # 1. Vérifications des outils
  # ---------------------------------------------------------------------------
  local manquant=0
  for outil in git python3; do
    command -v "$outil" >/dev/null 2>&1 || { echo "  ERREUR : $outil n'est pas installé."; manquant=1; }
  done

  if ! command -v claude >/dev/null 2>&1; then
    echo "  ERREUR : claude n'est pas installé."
    echo
    echo "Installe d'abord Claude Code :"
    echo "  curl -fsSL https://claude.ai/install.sh | bash"
    echo "Puis lance « claude » une fois pour te connecter, et relance cet installateur."
    return 1
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo
    echo "  ERREUR : gh (GitHub CLI) n'est pas installé."
    echo "    Sur Mint / Debian / Ubuntu :  sudo apt install gh"
    echo "    Puis connecte-toi :           gh auth login"
    return 1
  fi

  if [ "$manquant" = "1" ]; then
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo
    echo "  ERREUR : tu n'es pas connecté à GitHub."
    echo "    Lance :  gh auth login"
    return 1
  fi
  echo "  ok : git, python3, claude et gh sont là, et GitHub est connecté."

  local COMPTE
  COMPTE=$(gh api user --jq .login </dev/null 2>/dev/null || true)
  if [ -z "$COMPTE" ]; then
    echo "  ERREUR : impossible de lire ton identifiant GitHub."
    return 1
  fi
  echo "  ok : compte GitHub : $COMPTE"

  # gh et git sont deux choses : « gh auth login » connecte gh, mais git a besoin
  # du credential helper pour cloner et pousser en HTTPS sur un dépôt privé.
  if ! git config --global --get-regexp 'credential.*helper' 2>/dev/null | grep -q 'gh'; then
    gh auth setup-git </dev/null >/dev/null 2>&1 \
      && echo "  ok : git branché sur le compte GitHub" \
      || echo "  Attention : git n'a pas pu être branché automatiquement sur GitHub"
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

  # Outil d'empreinte : sha256sum (GNU), shasum -a 256 (macOS/BSD), sinon
  # python3, déjà requis par l'installateur. Aucun des trois : on ne sait pas
  # calculer d'empreinte, et on ne fera donc jamais « rien n'a changé ».
  local OUTIL_HACHAGE=""
  if command -v sha256sum >/dev/null 2>&1; then
    OUTIL_HACHAGE="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    OUTIL_HACHAGE="shasum"
  elif command -v python3 >/dev/null 2>&1; then
    OUTIL_HACHAGE="python3"
  fi

  # empreinte_fichier : empreinte sha256 du fichier $1, ou échec si on ne peut
  # pas la calculer (outil absent, fichier illisible). Jamais de valeur vide
  # silencieuse : c'est elle qui faisait croire que deux états étaient égaux.
  empreinte_fichier() {
    local h
    case "$OUTIL_HACHAGE" in
      sha256sum) h=$(sha256sum < "$1" 2>/dev/null | cut -d' ' -f1) || return 1 ;;
      shasum)    h=$(shasum -a 256 < "$1" 2>/dev/null | cut -d' ' -f1) || return 1 ;;
      python3)   h=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1" 2>/dev/null) || return 1 ;;
      *)         return 1 ;;
    esac
    [ -n "$h" ] || return 1
    printf '%s\n' "$h"
  }

  # hacher_flux : empreinte sha256 du texte reçu sur l'entrée standard.
  hacher_flux() {
    local h
    case "$OUTIL_HACHAGE" in
      sha256sum) h=$(sha256sum 2>/dev/null | cut -d' ' -f1) || return 1 ;;
      shasum)    h=$(shasum -a 256 2>/dev/null | cut -d' ' -f1) || return 1 ;;
      python3)   h=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())' 2>/dev/null) || return 1 ;;
      *)         return 1 ;;
    esac
    [ -n "$h" ] || return 1
    printf '%s\n' "$h"
  }

  # empreinte_etat : empreinte du contenu que la sauvegarde couvre — les fichiers
  # que l'installateur modifie, plus les anciennes mémoires. Elle est écrite dans
  # la sauvegarde à la fin de l'installation (.etat-apres) puis relue au passage
  # suivant : si rien n'a bougé depuis, on ne duplique pas le dossier.
  # Ne rend un résultat que si TOUT a pu être lu : une empreinte partielle (ou
  # vide) ne doit jamais servir à conclure « rien n'a changé », sinon la
  # sauvegarde nécessaire serait sautée (c'était le cas sans sha256sum).
  empreinte_etat() {
    local f h liste="" ok=0 fichiers_rc
    fichiers_rc=("$HOME/.profile" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.zprofile")
    for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/settings.json" "${fichiers_rc[@]}"; do
      if [ -f "$f" ]; then
        if ! h=$(empreinte_fichier "$f"); then
          ok=1
          continue
        fi
        liste="$liste
present $f $h"
      else
        liste="$liste
absent $f"
      fi
    done
    if [ -d "$HOME/.claude/projects" ]; then
      local liste_memoires
      liste_memoires=$(find "$HOME/.claude/projects" -type f -path '*/memory/*' -print 2>/dev/null | sort) || return 1
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        if ! h=$(empreinte_fichier "$f"); then
          ok=1
          continue
        fi
        liste="$liste
memoire $h $f"
      done <<FIN
$liste_memoires
FIN
    fi
    [ "$ok" = "0" ] || return 1
    printf '%s\n' "$liste" | hacher_flux
  }

  local A_SAUVER=0
  SAUVEGARDE_REUTILISEE=0
  [ -f "$HOME/.claude/CLAUDE.md" ] && A_SAUVER=1
  [ -f "$HOME/.claude/settings.json" ] && A_SAUVER=1
  # Les fichiers rc qu'on va compléter sont sauvegardés eux aussi.
  [ "${#RC_EXISTANTS[@]}" -gt 0 ] && A_SAUVER=1
  # Pas de « | head -1 » dans ce test : sous pipefail, grep -q ferme le tube,
  # find meurt en SIGPIPE (141) et la sauvegarde était sautée sans un mot.
  if [ -d "$HOME/.claude/projects" ]; then
    if find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -name memory -type d -print -quit 2>/dev/null | grep -q .; then
      A_SAUVER=1
    fi
  fi

  if [ "$A_SAUVER" = "1" ]; then
    local ETAT_AVANT DERNIERE
    # Empreinte calculable UNIQUEMENT si tout a pu être lu : une empreinte vide
    # ou partielle ne doit jamais faire conclure « rien n'a changé » (sans
    # sha256sum, c'était le cas : la sauvegarde nécessaire était sautée).
    if ! ETAT_AVANT=$(empreinte_etat); then
      ETAT_AVANT=""
    fi
    # Outil d'empreinte absent : on ne compare pas, donc on crée toujours une
    # sauvegarde neuve. Mieux vaut un dossier de plus qu'une copie manquante.
    [ -n "$OUTIL_HACHAGE" ] || ETAT_AVANT=""

    # Relance identique : si la dernière sauvegarde a été prise sur exactement le
    # même contenu et qu'elle est complète, on ne crée pas un deuxième dossier.
    # On ne supprime jamais une sauvegarde existante : on réutilise la sienne.
    DERNIERE=""
    if [ -n "$ETAT_AVANT" ]; then
      for essai_sauve in "$BUREAU"/cerveau-sauvegarde-*; do
        [ -d "$essai_sauve" ] || continue
        [ -f "$essai_sauve/.etat-apres" ] || continue
        [ -f "$essai_sauve/LISEZ-MOI.txt" ] || continue
        if [ "$(cat "$essai_sauve/.etat-apres" 2>/dev/null)" = "$ETAT_AVANT" ]; then
          DERNIERE="$essai_sauve"
        fi
      done
    fi

    if [ -n "$DERNIERE" ]; then
      SAUVEGARDE="$DERNIERE"
      # Rien n'a bougé depuis la fin de la dernière installation : les fichiers
      # sont exactement dans l'état où elle les a laissés. Leur contenu d'origine
      # est déjà dans ce dossier, une copie .avant-cerveau de plus n'apprendrait
      # rien (elle ne contiendrait que les ajouts de l'installateur).
      SAUVEGARDE_REUTILISEE=1
      echo "  ok : rien n'a changé depuis la sauvegarde $(basename "$SAUVEGARDE") — je la garde telle quelle"
    elif mkdir -p "$SAUVEGARDE/memoire-ancienne" 2>/dev/null; then
      [ -n "$ETAT_AVANT" ] && printf '%s\n' "$ETAT_AVANT" > "$SAUVEGARDE/.etat-avant" 2>/dev/null
      # Les deux fichiers que l'installateur modifie
      [ -f "$HOME/.claude/CLAUDE.md" ] && cp -p "$HOME/.claude/CLAUDE.md" "$SAUVEGARDE/CLAUDE.md.original" 2>/dev/null
      [ -f "$HOME/.claude/settings.json" ] && cp -p "$HOME/.claude/settings.json" "$SAUVEGARDE/settings.json.original" 2>/dev/null

      # Les fichiers de démarrage du shell, avant de leur ajouter la ligne PATH.
      # Le point initial est retiré du nom de la copie (profile.original et non
      # .profile.original) : sur le Bureau, un fichier caché se voit à peine et
      # le LISEZ-MOI doit pouvoir le citer tel qu'il est écrit. C'est le nom que
      # la procédure de retour arrière du LISEZ-MOI demande de remettre en place.
      for rc in "${RC_EXISTANTS[@]}"; do
        cp -p "$rc" "$SAUVEGARDE/$(basename "$rc" | sed 's/^\.//').original" 2>/dev/null || true
      done

      # Toutes les anciennes mémoires, projet par projet
      if [ -d "$HOME/.claude/projects" ]; then
        for mem in "$HOME/.claude/projects"/*/memory; do
          [ -d "$mem" ] || continue
          projet=$(basename "$(dirname "$mem")")
          mkdir -p "$SAUVEGARDE/memoire-ancienne/$projet" 2>/dev/null
          cp -Rp "$mem/." "$SAUVEGARDE/memoire-ancienne/$projet/" 2>/dev/null || true
        done
      fi

      # Une note lisible pour lui, plus tard. Les noms cités ici sont ceux que
      # l'installateur pose vraiment : les copies des fichiers rc perdent leur
      # point initial (~/.profile donne profile.original). Un LISEZ-MOI qui
      # nomme « .profile.original » enverrait copier un fichier inexistant.
      # La liste des fichiers rc est celle qui a réellement été complétée, pas
      # une liste fixe : zsh, .bash_profile et .zshrc y ont leur place.
      local LISTE_RC=""
      for rc in "${RC_EXISTANTS[@]}"; do
        LISTE_RC="$LISTE_RC      $(basename "$rc" | sed 's/^\.//').original       ->  ~/$(basename "$rc")
"
      done
      cat > "$SAUVEGARDE/LISEZ-MOI.txt" <<EOF
Sauvegarde faite par l'installateur du « cerveau » le $(date '+%d/%m/%Y à %H:%M').

POURQUOI CE DOSSIER
L'installateur ne supprime aucun fichier. Mais il modifie ces fichiers :
  - ~/.claude/CLAUDE.md      (il y ajoute son bloc à la fin)
  - ~/.claude/settings.json  (il y ajoute la mémoire automatique et les permissions)
  - les fichiers de démarrage de ton shell (il y ajoute ~/.local/bin au PATH,
    pour que la commande « cerveau » soit trouvée dans un terminal)
Ce dossier contient une copie de ces fichiers TELS QU'ILS ÉTAIENT AVANT,
et une copie de toutes les notes de mémoire que Claude Code avait déjà écrites.

CE QUI N'A PAS ÉTÉ TOUCHÉ
  - Tes conversations passées (/resume) : elles sont dans ~/.claude/projects/ et
    n'ont pas été modifiées.
  - Tous tes fichiers de projet.

CE QUE TU PEUX FAIRE
  - Ne rien faire et le garder quelque temps. Il ne gêne personne.
  - Le supprimer quand tu es sûr que tout va bien : c'est toi qui décides.
  - En cas de souci, remettre les fichiers de ce dossier à leur place :
      CLAUDE.md.original     ->  ~/.claude/CLAUDE.md
      settings.json.original ->  ~/.claude/settings.json
$(printf '%s' "$LISTE_RC")    (le nom de la copie est celui du fichier d'origine sans son point initial,
    plus « .original » : profile.original est bien la copie de ~/.profile)

Dossier sauvegardé : $SAUVEGARDE
EOF
      echo "  ok : sauvegarde complète sur le Bureau : $(basename "$SAUVEGARDE")"
    else
      echo "  Attention : sauvegarde impossible (droits ?) — l'installation continue, rien n'est supprimé"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 1 ter. Ajouter ~/.local/bin au PATH des prochains shells
  #
  # Après la sauvegarde. On crée ~/.profile s'il n'existe pas : sans lui, aucun
  # shell de connexion ne connaît ~/.local/bin et « cerveau » reste introuvable.
  # ---------------------------------------------------------------------------
  local rc
  for rc in "${RC_A_CREER[@]}"; do
    : > "$rc" 2>/dev/null || { echo "  Attention : impossible de créer $rc"; continue; }
  done
  for rc in "${RC_EXISTANTS[@]}" "${RC_A_CREER[@]}"; do
    [ -f "$rc" ] || continue
    grep -qxF "$LIGNE_PATH" "$rc" 2>/dev/null && continue
    {
      printf '\n# Ajouté par l'\''installateur du cerveau (pour la commande « cerveau »)\n'
      printf '%s\n' "$LIGNE_PATH"
    } >> "$rc" 2>/dev/null && echo "  ok : $(basename "$rc") complété pour trouver « cerveau »"
  done

  # ---------------------------------------------------------------------------
  # 2. Récupérer ou créer le dépôt du cerveau
  #
  # Règle : on ne dit « c'est prêt » que si les notes sont réellement arrivées
  # sur GitHub. Un dépôt local sans « origin », ou un envoi qui a échoué, n'est
  # pas une installation finie : la relance doit réparer, pas se contenter de
  # synchroniser un dépôt qui ne mène nulle part.
  # ---------------------------------------------------------------------------
  local CREER=0
  local URL_PRIVE="${CERVEAU_URL_PRIVE:-https://github.com/$COMPTE/$NOM_DEPOT.git}"
  local BRANCHE_LOCALE="main"

  # ecrire_origin : pose (ou corrige) l'adresse du dépôt distant.
  ecrire_origin() {
    if git -C "$DESTINATION" remote get-url origin >/dev/null 2>&1; then
      git -C "$DESTINATION" remote set-url origin "$URL_PRIVE" 2>/dev/null || return 1
    else
      git -C "$DESTINATION" remote add origin "$URL_PRIVE" 2>/dev/null || return 1
    fi
    return 0
  }

  # envoyer_vers_origin : envoie la branche courante et pose l'upstream.
  envoyer_vers_origin() {
    BRANCHE_LOCALE=$(git -C "$DESTINATION" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    [ -n "$BRANCHE_LOCALE" ] || BRANCHE_LOCALE="main"
    git -C "$DESTINATION" push -u origin "$BRANCHE_LOCALE" --quiet </dev/null 2>/dev/null
  }

  # origin_est_le_bon : vrai si « origin » désigne le dépôt privé de
  # l'utilisateur. On compare le couple compte/nom plutôt que l'URL exacte :
  # une adresse SSH (git@github.com:compte/cerveau.git) est aussi valable que
  # l'HTTPS, et git peut avoir réécrit l'URL (insteadOf). Ce qui compte, c'est
  # que ce ne soit ni le dépôt du modèle, ni un autre dépôt.
  origin_est_le_bon() {
    local url
    url=$(git -C "$DESTINATION" remote get-url origin 2>/dev/null || true)
    [ -n "$url" ] || return 1
    url="${url%/}"
    url="${url%.git}"
    # On compare la FIN du chemin (compte/nom), pas le début : git peut avoir
    # réécrit l'adresse (insteadOf, SSH, miroir local) sans changer le dépôt
    # visé, et c'est le couple compte/nom qui l'identifie. La comparaison porte
    # sur le chemin complet : « compte/cerveau-seed » ne passe pas pour
    # « compte/cerveau ».
    case "$url" in
      *"/$COMPTE/$NOM_DEPOT"|*":$COMPTE/$NOM_DEPOT") return 0 ;;
    esac
    return 1
  }

  # distant_a_recu : vrai si GitHub a bien la branche ET si elle pointe sur notre
  # dernier commit. Une branche qui existe mais reste en arrière ne prouve pas
  # que les notes sont arrivées. On exige aussi un arbre propre : un commit
  # refusé laisse HEAD inchangé (donc déjà sur GitHub) et des fichiers non
  # commités ; comparer HEAD seul dirait alors « reçu » à tort.
  distant_a_recu() {
    local b tete distante
    [ -z "$(git -C "$DESTINATION" status --porcelain 2>/dev/null)" ] || return 1
    b=$(git -C "$DESTINATION" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    [ -n "$b" ] || b="main"
    tete=$(git -C "$DESTINATION" rev-parse HEAD 2>/dev/null || true)
    [ -n "$tete" ] || return 1
    if command -v timeout >/dev/null 2>&1; then
      distante=$(timeout 30 git -C "$DESTINATION" ls-remote origin "refs/heads/$b" 2>/dev/null | awk 'NR==1 {print $1}')
    else
      distante=$(git -C "$DESTINATION" ls-remote origin "refs/heads/$b" 2>/dev/null | awk 'NR==1 {print $1}')
    fi
    [ -n "$distante" ] && [ "$distante" = "$tete" ]
  }

  # Un dépôt distant existant n'est accepté que s'il est PRIVÉ : y pousser des
  # notes personnelles dans un dépôt public les publierait pour toujours.
  # Si la visibilité est illisible (hors ligne), on ne bloque pas ici : le
  # contrôle final de l'envoi refusera de dire « prêt » si rien n'est parti.
  depot_est_prive() {
    local vis
    vis=$(gh repo view "$COMPTE/$NOM_DEPOT" --json visibility --jq .visibility </dev/null 2>/dev/null || true)
    if [ -n "$vis" ] && [ "$vis" != "PRIVATE" ]; then
      echo "  ERREUR : le dépôt $COMPTE/$NOM_DEPOT existe déjà et il n'est pas privé"
      echo "    (visibilité : $vis). Je n'y envoie rien : tes notes personnelles"
      echo "    seraient visibles par tout le monde."
      echo "    Deux solutions :"
      echo "      - le rendre privé sur GitHub (Settings, puis Danger Zone, Change visibility) ;"
      echo "      - ou choisir un autre nom, par exemple :"
      echo "          CERVEAU_DEPOT_NOM=cerveau-prive bash installer.sh"
      echo "    Rien n'a été envoyé. Tes notes restent sur cet ordinateur."
      return 1
    fi
    return 0
  }

  if [ -d "$DESTINATION/.git" ]; then
    echo "  → le cerveau est déjà installé ici, je vérifie le dépôt distant"
    git -C "$DESTINATION" config user.email "$EMAIL" 2>/dev/null || true
    git -C "$DESTINATION" config user.name "$NOMGIT" 2>/dev/null || true
    BRANCHE_LOCALE=$(git -C "$DESTINATION" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    [ -n "$BRANCHE_LOCALE" ] || BRANCHE_LOCALE="main"

    # Demi-clone d'une installation tuée pendant « git clone » du modèle : le
    # dossier existe avec le .git du modèle (origin = dépôt public du modèle) et
    # rien de l'utilisateur dedans. La relance doit le réparer, jamais le valider.
    # Un clone --depth 1 est « superficiel » : GitHub refuse d'y recevoir une
    # branche (shallow update not allowed). On repart donc d'un commit unique
    # qui contient tous les fichiers présents (dont les notes déjà écrites),
    # exactement comme une première installation, puis on relie le bon dépôt.
    local ORIGIN_ETRANGER=""
    origin_est_le_bon || {
      ORIGIN_ETRANGER=$(git -C "$DESTINATION" remote get-url origin 2>/dev/null || true)
      if [ -n "$ORIGIN_ETRANGER" ]; then
        echo "  → cette copie ne mène pas à ton dépôt ($ORIGIN_ETRANGER) : je la remets sur $COMPTE/$NOM_DEPOT"
        case "$ORIGIN_ETRANGER" in
          *cerveau-seed*)
            echo "    (c'est le dépôt MODÈLE : l'installation avait été interrompue pendant la migration)"
            ;;
        esac
      fi
      if [ "$(git -C "$DESTINATION" rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true" ] \
         || [ "$(git -C "$DESTINATION" rev-list --count HEAD 2>/dev/null || echo 0)" -le 1 ]; then
        git -C "$DESTINATION" checkout --quiet --orphan cerveau-installation 2>/dev/null || true
        git -C "$DESTINATION" add -A 2>/dev/null
        git -C "$DESTINATION" commit --quiet -m "cerveau : première installation" 2>/dev/null || true
        git -C "$DESTINATION" branch -M main 2>/dev/null || true
        BRANCHE_LOCALE="main"
      fi
      git -C "$DESTINATION" remote remove origin 2>/dev/null || true
    }

    # Copie locale sans aucun commit (arrêt entre « git init » et le commit) :
    # on en refait un, sinon il n'y a rien à envoyer et la relance tourne en rond.
    if ! git -C "$DESTINATION" rev-parse --verify HEAD >/dev/null 2>&1; then
      git -C "$DESTINATION" add -A 2>/dev/null
      git -C "$DESTINATION" commit --quiet -m "cerveau : première installation" 2>/dev/null || true
    fi

    # Un origin absent OU étranger (dépôt du modèle, autre compte, vieille URL)
    # n'est pas une installation finie. On le répare avant toute synchro : le
    # contrôle final refuserait de dire « prêt » de toute façon, mais autant
    # réparer tout de suite que s'arrêter sur un échec qu'on sait corriger.
    if ! origin_est_le_bon; then
      local ORIGIN_VU
      ORIGIN_VU=$(git -C "$DESTINATION" remote get-url origin 2>/dev/null || true)
      if [ -n "$ORIGIN_VU" ]; then
        echo "  → cette copie ne pointe pas sur ton dépôt ($ORIGIN_VU) : je la relie à $COMPTE/$NOM_DEPOT"
      else
        # Demi-installation : le dépôt local existe, mais rien ne le relie à GitHub
        # (coupure pendant « gh repo create », Ctrl-C, jeton sans le scope repo).
        # Sans ce rattrapage, la relance ne créait jamais le dépôt distant.
        echo "  → aucun dépôt distant n'est relié à cette copie : je le crée maintenant"
      fi
      if gh repo view "$COMPTE/$NOM_DEPOT" </dev/null >/dev/null 2>&1; then
        depot_est_prive || return 1
        ecrire_origin || { echo "  ERREUR : impossible de relier le dépôt distant."; return 1; }
      else
        # Le dépôt distant n'existe pas encore : on l'crée et on y pousse. Si
        # l'origin pointait ailleurs, gh repo create le remplace par le bon.
        if [ -n "$ORIGIN_VU" ]; then
          git -C "$DESTINATION" remote remove origin >/dev/null 2>&1 || true
        fi
        if ! gh repo create "$COMPTE/$NOM_DEPOT" --private \
              --source="$DESTINATION" --remote=origin --push </dev/null >/dev/null 2>&1; then
          echo "  ERREUR : impossible de créer le dépôt GitHub."
          echo "    Tes notes restent sur cet ordinateur, rien n'est perdu."
          echo "    Vérifie ta connexion, puis relance la même commande."
          return 1
        fi
      fi
    fi

    # Le code de retour de « cerveau » n'est pas avalé : un commit refusé, un
    # index.lock ou un envoi impossible doivent arrêter l'installation avec le
    # vrai diagnostic, pas un « réseau ? » suivi d'un « C'est prêt » mensonger.
    if [ -x "$DESTINATION/bin/cerveau" ]; then
      if ! "$DESTINATION/bin/cerveau" </dev/null; then
        echo "  ERREUR : la synchronisation du cerveau n'a pas abouti."
        echo "    Le message ci-dessus dit pourquoi (souvent un hook pre-commit,"
        echo "    un fichier .git/index.lock oublié, ou l'accès à GitHub)."
        echo "    Tes notes sont enregistrées sur cet ordinateur, rien n'est perdu."
        echo "    Corrige le point signalé, puis relance la même commande."
        return 1
      fi
    fi

    # Le dépôt distant doit avoir reçu la branche. Sinon on répare une fois
    # (gh auth setup-git rétablit l'accès git à GitHub), puis on s'arrête net :
    # mieux vaut un échec clair qu'un « C'est prêt » mensonger.
    if ! distant_a_recu; then
      echo "  → le dépôt distant n'a pas reçu tes notes : je rétablis l'accès et je réessaie"
      gh auth setup-git </dev/null >/dev/null 2>&1 || true
      if ! envoyer_vers_origin || ! distant_a_recu; then
        echo "  ERREUR : le dépôt distant n'a pas reçu tes notes."
        echo "    Elles sont enregistrées sur cet ordinateur, rien n'est perdu."
        echo "    Vérifie ta connexion avec  gh auth status  puis relance la même commande."
        return 1
      fi
    fi

  elif gh repo view "$COMPTE/$NOM_DEPOT" </dev/null >/dev/null 2>&1; then
    depot_est_prive || return 1

    echo "  → ton dépôt privé ($COMPTE/$NOM_DEPOT) existe déjà, je le récupère"
    if ! git clone --quiet "$URL_PRIVE" "$DESTINATION" </dev/null; then
      echo "  ERREUR : impossible de récupérer le dépôt $COMPTE/$NOM_DEPOT"
      return 1
    fi
    # Un dépôt qui existe mais n'a AUCUN commit (créé à la main puis abandonné)
    # se clone « vide » : ni ai-config.md, ni bin/cerveau. Sans ce rattrapage, le
    # reste de l'installation écrivait dans un dossier fantôme et « réussissait ».
    if [ ! -f "$DESTINATION/ai-config.md" ]; then
      echo "  → ce dépôt est vide (aucun contenu dedans) : je le rembourre avec le modèle"
      if ! git clone --quiet --depth 1 "$DEPOT_MODELE" "$DESTINATION/.modele-tmp" </dev/null; then
        echo "  ERREUR : dépôt vide et modèle inaccessible : je m'arrête."
        echo "    Vérifie ta connexion, puis relance l'installateur."
        return 1
      fi
      # On déplace le contenu du modèle DANS le dépôt vide (sans écraser son .git).
      (cd "$DESTINATION/.modele-tmp" && tar cf - --exclude=.git .) \
        | (cd "$DESTINATION" && tar xf -) 2>/dev/null
      rm -rf "$DESTINATION/.modele-tmp" "$DESTINATION/tests" "$DESTINATION/machines.md"
      if [ ! -f "$DESTINATION/ai-config.md" ] || [ ! -f "$DESTINATION/bin/cerveau" ]; then
        echo "  ERREUR : impossible de rembourrer le dépôt vide : je m'arrête."
        return 1
      fi
      git -C "$DESTINATION" add -A 2>/dev/null
      git -C "$DESTINATION" -c user.email="$EMAIL" -c user.name="$NOMGIT" \
          commit --quiet -m "cerveau : contenu de départ" 2>/dev/null
      if ! envoyer_vers_origin || ! distant_a_recu; then
        echo "  ERREUR : le dépôt vide est rempli sur cet ordinateur, mais l'envoi"
        echo "    sur GitHub a échoué. Rien n'est perdu : relance la même commande."
        return 1
      fi
      echo "  ok : dépôt vide rempli avec le contenu de départ"
    fi

  else
    CREER=1
    echo "  → première installation : je crée ton dépôt privé ($COMPTE/$NOM_DEPOT)"

    if ! git clone --quiet --depth 1 "$DEPOT_MODELE" "$DESTINATION" </dev/null; then
      echo "  ERREUR : impossible de récupérer le modèle de départ ($DEPOT_MODELE)"
      echo "    Vérifie ta connexion internet."
      return 1
    fi
    # On ne nettoie QUE si c'est bien le modèle qu'on vient de cloner (ce dossier
    # n'existait pas il y a une seconde) : sans ce garde-fou, on ne supprime rien.
    if [ -f "$DESTINATION/ai-config.md" ] && [ -f "$DESTINATION/installer.sh" ]; then
      rm -rf "$DESTINATION/.git" "$DESTINATION/tests" "$DESTINATION/machines.md"
    else
      echo "  ERREUR : le contenu récupéré n'est pas celui attendu — je m'arrête sans rien supprimer."
      return 1
    fi

    git -C "$DESTINATION" init --quiet -b main
    git -C "$DESTINATION" config user.email "$EMAIL"
    git -C "$DESTINATION" config user.name "$NOMGIT"
    git -C "$DESTINATION" add -A
    git -C "$DESTINATION" commit --quiet -m "cerveau : première installation"

    if ! gh repo create "$COMPTE/$NOM_DEPOT" --private \
          --source="$DESTINATION" --remote=origin --push </dev/null >/dev/null 2>&1; then
      echo "  ERREUR : impossible de créer le dépôt GitHub."
      echo "    Tes notes restent sur cet ordinateur, rien n'est perdu."
      echo "    Vérifie ta connexion, puis relance la même commande."
      return 1
    fi
  fi

  # Le dépôt distant doit vraiment contenir la branche. C'est la seule preuve
  # que « C'est prêt » dit la vérité.
  if ! distant_a_recu; then
    gh auth setup-git </dev/null >/dev/null 2>&1 || true
    if ! envoyer_vers_origin || ! distant_a_recu; then
      echo "  ERREUR : le dépôt distant n'a pas reçu tes notes."
      echo "    Elles sont enregistrées sur cet ordinateur, rien n'est perdu."
      echo "    Vérifie ta connexion avec  gh auth status  puis relance la même commande."
      return 1
    fi
  fi

  # Toujours garantir qu'une identité git locale est présente dans le dépôt du cerveau
  # (ainsi, même sur un PC tout neuf où git global n'est pas configuré, tout commit marche).
  git -C "$DESTINATION" config user.email "$EMAIL" 2>/dev/null || true
  git -C "$DESTINATION" config user.name "$NOMGIT" 2>/dev/null || true
  echo "  ok : cerveau prêt dans $DESTINATION"

  # ---------------------------------------------------------------------------
  # 2 bis. Rassembler les anciennes notes de Claude Code dans un sas (.a-importer)
  #        Elles ne sont PAS copiées en vrac dans notes/ : Claude les réécrit
  #        proprement aux règles du cerveau (une note par projet, sans chemins
  #        absolus), par lots de 60 Ko, pour ne jamais exploser le quota.
  # ---------------------------------------------------------------------------
  local NOM_MACHINE
  NOM_MACHINE="$(hostname 2>/dev/null | cut -d. -f1 | tr -d ' \r\n')"
  [ -z "$NOM_MACHINE" ] && NOM_MACHINE="machine-inconnue"

  # La collecte peut échouer (python3 cassé, disque plein, droits) : on regarde
  # son code de retour. Avant, l'échec était avalé et l'installateur annonçait
  # « C'est prêt » avec zéro note reprise.
  local COLLECTE CODE_COLLECTE
  COLLECTE=$(python3 - "$HOME/.claude" "$DESTINATION/.a-importer" "$NOM_MACHINE" <<'PY'
import glob, hashlib, os, re, sys

claude_dir, sas_dir, machine = sys.argv[1], sys.argv[2], sys.argv[3]
projets_dir = os.path.join(claude_dir, "projects")
LIMITE = 60000  # caractères par lot (~15 000 tokens) : un lot tient en un Read

# Mémoire des fragments déjà importés lors d'une exécution précédente :
# relancer l'installateur ne doit pas recréer les mêmes lots. Un fragment dont
# le lot échoue n'est pas perdu : le lot reste dans le sas (voir cerveau).
os.makedirs(sas_dir, exist_ok=True)
vus_path = os.path.join(sas_dir, ".vus")
deja_vus = set()
if os.path.isfile(vus_path):
    try:
        deja_vus = {l.strip() for l in open(vus_path, encoding="utf-8") if l.strip()}
    except OSError as e:
        print("impossible de lire %s : %s" % (vus_path, e), file=sys.stderr)
        sys.exit(1)

def empreinte(contenu):
    return hashlib.sha1(contenu.encode("utf-8", "replace")).hexdigest()

# Les lots déjà écrits mais pas encore importés portent leurs empreintes dans
# leur en-tête : on les compte comme « déjà pris » sans les marquer comme vus.
# C'est cerveau --importer qui les ajoutera à .vus, une fois le travail vérifié.
for chemin_lot in glob.glob(os.path.join(sas_dir, "lot-*.md")):
    try:
        with open(chemin_lot, encoding="utf-8", errors="replace") as f:
            for ligne in f:
                if ligne.startswith("# empreintes :"):
                    deja_vus |= set(ligne.split(":", 1)[1].split())
                    break
    except OSError as e:
        print("impossible de lire %s : %s" % (chemin_lot, e), file=sys.stderr)
        sys.exit(1)

def nouveau(contenu):
    h = empreinte(contenu)
    if h in deja_vus:
        return None
    deja_vus.add(h)
    return h

fragments = []  # (projet lisible, machine, titre, contenu, empreintes)

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
            h = nouveau(contenu)
            if h:
                fragments.append((projet, machine, base, contenu, h))

# 2. L'ancien CLAUDE.md global (ses règles personnelles d'avant le cerveau)
ancien = os.path.join(claude_dir, "CLAUDE.md")
if os.path.isfile(ancien):
    try:
        contenu = open(ancien, encoding="utf-8", errors="replace").read().strip()
        if contenu and ">>> cerveau >>>" not in contenu:
            h = nouveau("claude-md:" + contenu)
            if h:
                fragments.append(("Réglages globaux de Claude Code", machine, "CLAUDE.md", contenu, h))
    except Exception:
        pass

# 3. La liste des dossiers de projets où il a travaillé sur ce PC.
#    Ce fragment passe par nouveau() comme les autres : sinon son empreinte
#    n'entrait jamais dans .vus et chaque relance relançait tout l'import.
if os.path.isdir(projets_dir):
    dossiers = sorted({projet_lisible(d) for d in glob.glob(os.path.join(projets_dir, "*")) if os.path.isdir(d)})
    if dossiers:
        liste = "\n".join(f"- {d}" for d in dossiers)
        contenu_liste = (f"Dossiers de projets connus sur la machine `{machine}` :\n\n{liste}")
        h = nouveau("projets:" + contenu_liste)
        if h:
            fragments.append(("Liste des projets travaillés sur cette machine", machine, "projets",
                              contenu_liste, h))

# 4. Découpage en lots de LIMITE caractères (on ne coupe jamais un fragment en deux
#    s'il tient seul ; sinon on le tronque proprement)
lots, courant, taille, empreintes_lot = [], [], 0, []
for projet, mach, titre, contenu, h in fragments:
    bloc = f"\n\n## Source : {projet} (machine : {mach}) — {titre}\n\n{contenu}\n"
    if len(bloc) > LIMITE:
        bloc = bloc[:LIMITE] + "\n\n[…tronqué]"
    if taille + len(bloc) > LIMITE and courant:
        lots.append(("".join(courant), empreintes_lot)); courant, taille, empreintes_lot = [], 0, []
    courant.append(bloc); taille += len(bloc); empreintes_lot.append(h)
if courant:
    lots.append(("".join(courant), empreintes_lot))

# 5. Numérotation : on repart APRÈS le plus grand lot-*.md déjà présent. Écrire
#    à partir de 1 écrasait des lots encore en attente d'import (notes perdues).
deja = []
for chemin in glob.glob(os.path.join(sas_dir, "lot-*.md")):
    m = re.search(r"lot-(\d+)\.md$", os.path.basename(chemin))
    if m:
        deja.append(int(m.group(1)))
prochain = (max(deja) + 1) if deja else 1
nb_lots = 0
for i, (contenu, empreintes) in enumerate(lots, prochain):
    entete = (f"# Anciennes notes de Claude Code à assimiler — lot {i}/{prochain + len(lots) - 1}\n"
              f"# Machine d'origine : {machine}\n"
              f"# empreintes : {' '.join(empreintes)}\n")
    with open(os.path.join(sas_dir, f"lot-{i}.md"), "w", encoding="utf-8") as f:
        f.write(entete + contenu)
    nb_lots += 1

print(len(fragments), nb_lots)
PY
  )
  CODE_COLLECTE=$?

  if [ "$CODE_COLLECTE" -ne 0 ]; then
    echo "  ERREUR : la collecte des anciennes notes a échoué."
    echo "    Rien n'a été supprimé : tes anciennes notes sont toujours dans"
    echo "      $HOME/.claude/projects/"
    echo "    et une copie a été posée sur le Bureau si elle a pu être faite."
    echo "    À faire : vérifie que python3 fonctionne (python3 --version) et que"
    echo "    le disque n'est pas plein, puis relance la même commande."
    return 1
  fi

  local NB_FRAGMENTS NBLOTS
  NB_FRAGMENTS=$(printf '%s' "$COLLECTE" | awk '{print $1}')
  NBLOTS=$(printf '%s' "$COLLECTE" | awk '{print $2}')
  NB_FRAGMENTS=${NB_FRAGMENTS:-0}
  NBLOTS=${NBLOTS:-0}

  if [ "$NBLOTS" -gt 0 ] 2>/dev/null; then
    echo "  ok : $NB_FRAGMENTS ancien(s) élément(s) trouvé(s) — répartis en $NBLOTS lot(s)"
    if [ "${CERVEAU_SANS_IMPORT:-0}" = "1" ]; then
      echo "  → import reporté (CERVEAU_SANS_IMPORT=1) : lance « cerveau --importer » quand tu veux"
    else
      echo "  → Claude les lit et les réécrit aux règles du cerveau (une session, effort bas)…"
      "$DESTINATION/bin/cerveau" --importer </dev/null || echo "  Attention : import interrompu — relance « cerveau --importer » plus tard"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 3. Le nom de cette machine (NOM_MACHINE est déjà calculé à l'étape 2 bis)
  # ---------------------------------------------------------------------------
  cat > "$DESTINATION/machines.md" <<EOF
# Où je suis

> Attention, ce fichier n'est **pas** sur GitHub : il change d'un ordinateur à l'autre.
> C'est l'installateur qui l'a créé, avec le bon nom dedans.

je suis sur : $NOM_MACHINE

*(le catalogue de toutes les machines est dans \`notes/ordinateurs.md\` — celui-là est partagé.)*
EOF
  echo "  ok : machine enregistrée : $NOM_MACHINE"

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
    # Constat 13 : remplacer le lien ferait disparaître les règles personnelles
    # de la session. On écrit dans la CIBLE du lien, le lien reste en place.
    #
    # Résolution portable : « readlink -f » n'existe pas sur BSD/macOS. On
    # essaie readlink, puis python3 (déjà requis) ; on ne s'arrête que si le
    # résultat est vide ou ne mène à rien.
    local CIBLE=""
    if command -v readlink >/dev/null 2>&1; then
      CIBLE=$(readlink -f "$ACCUEIL" 2>/dev/null || true)
    fi
    if [ -z "$CIBLE" ] || [ ! -e "$CIBLE" ]; then
      CIBLE=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$ACCUEIL" 2>/dev/null || true)
    fi
    if [ -z "$CIBLE" ] || [ ! -e "$CIBLE" ]; then
      echo "  ERREUR : $ACCUEIL est un lien symbolique et sa cible est introuvable."
      echo "    Corrige ce lien (ou renomme-le), puis relance l'installateur."
      echo "    Rien n'a été supprimé : tes règles personnelles sont intactes."
      return 1
    fi

    # La cible ne doit jamais être écrite si elle vit dans un dépôt git : le
    # bloc (avec le chemin absolu de CETTE machine) serait commité puis poussé,
    # et réapparaîtrait sur l'autre ordinateur avec des chemins inexistants.
    # On s'arrête avec un message clair plutôt que de modifier un fichier
    # partagé et versionné.
    local DEPOT_CIBLE=""
    DEPOT_CIBLE=$(git -C "$(dirname "$CIBLE")" rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$DEPOT_CIBLE" ]; then
      case "$CIBLE" in
        "$DEPOT_CIBLE"/*)
          echo "  ERREUR : $ACCUEIL pointe vers un fichier d'un dépôt git :"
          echo "    $CIBLE"
          echo "    (dépôt : $DEPOT_CIBLE)"
          echo "    Je n'y écris pas : le bloc contient le chemin absolu de cette"
          echo "    machine et partirait sur les autres ordinateurs, où il ne"
          echo "    mènerait à rien."
          echo "    Deux solutions :"
          echo "      - remplace le lien par un vrai fichier :  rm $ACCUEIL"
          echo "        (l'installateur le recréera, en gardant ton fichier partagé) ;"
          echo "      - ou garde ton lien vers un fichier HORS dépôt git."
          echo "    Rien n'a été supprimé ni modifié."
          return 1
          ;;
      esac
    fi
    mkdir -p "$(dirname "$CIBLE")" 2>/dev/null || true
    [ -f "$CIBLE" ] || : > "$CIBLE"
    # Pas de copie .avant-cerveau si la cible est identique à la précédente :
    # trois relances ne doivent pas laisser trois copies du même fichier.
    if [ "$SAUVEGARDE_REUTILISEE" = "0" ] && ! grep -qF "$DEBUT" "$CIBLE" 2>/dev/null; then
      DERNIERE_COPIE=$(ls -1t "$CIBLE".avant-cerveau-* 2>/dev/null | head -1)
      if [ -z "$DERNIERE_COPIE" ] || ! cmp -s "$CIBLE" "$DERNIERE_COPIE"; then
        cp "$CIBLE" "$CIBLE.avant-cerveau-$HORO" 2>/dev/null || true
      fi
    fi
    if grep -qF "$DEBUT" "$CIBLE" 2>/dev/null; then
      python3 - "$CIBLE" "$DEBUT" "$FIN" "$BLOC" <<'PY'
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
tmp = chemin + ".tmp-cerveau"
with open(tmp, "w", encoding="utf-8") as f:
    f.write("\n".join(sortie))
import os
os.replace(tmp, chemin)
PY
    else
      printf '\n\n%s\n' "$BLOC" >> "$CIBLE"
    fi
    echo "  → ton CLAUDE.md est un lien : le bloc a été écrit dans sa cible ($CIBLE), le lien est conservé"

  elif [ -f "$ACCUEIL" ]; then
    # Même règle : on ne recopie que l'état d'AVANT l'ajout du bloc. Une relance
    # ne doit pas empiler une copie par passage.
    if [ "$SAUVEGARDE_REUTILISEE" = "0" ] && ! grep -qF "$DEBUT" "$ACCUEIL"; then
      DERNIERE_COPIE=$(ls -1t "$ACCUEIL".avant-cerveau-* 2>/dev/null | head -1)
      if [ -z "$DERNIERE_COPIE" ] || ! cmp -s "$ACCUEIL" "$DERNIERE_COPIE"; then
        cp "$ACCUEIL" "$ACCUEIL.avant-cerveau-$HORO"
      fi
    fi
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
tmp = chemin + ".tmp-cerveau"
with open(tmp, "w", encoding="utf-8") as f:
    f.write("\n".join(sortie))
import os
os.replace(tmp, chemin)
PY
      echo "  → bloc du cerveau mis à jour dans ton CLAUDE.md (le reste est intact)"
    else
      printf '\n\n%s\n' "$BLOC" >> "$ACCUEIL"
      echo "  → bloc ajouté à la fin de ton CLAUDE.md (tes instructions restent intactes)"
    fi

  else
    printf '%s\n' "$BLOC" > "$ACCUEIL"
    echo "  ok : mot d'accueil écrit dans $ACCUEIL"
  fi

  # ---------------------------------------------------------------------------
  # 5. La commande cerveau dans ~/.local/bin/cerveau
  # ---------------------------------------------------------------------------
  if [ ! -f "$DESTINATION/bin/cerveau" ]; then
    echo "  ERREUR : $DESTINATION/bin/cerveau est absent : l'installation ne peut pas continuer."
    echo "    Le dossier du cerveau est incomplet. Relance l'installateur ;"
    echo "    si ça se reproduit, supprime $DESTINATION et relance."
    return 1
  fi
  cp -f "$DESTINATION/bin/cerveau" "$HOME/.local/bin/cerveau"
  chmod 755 "$HOME/.local/bin/cerveau" "$DESTINATION/bin/cerveau"
  echo "  ok : commande installée dans ~/.local/bin/cerveau"

  # ---------------------------------------------------------------------------
  # 6. Brancher autoMemoryDirectory, permissions et hook SessionStart (--auto)
  #
  # Règle : on ne remplace JAMAIS un settings.json qu'on n'a pas su lire. Les
  # formes tolérées (commentaires //, virgule finale, BOM, JSON tronqué) sont
  # réparées sans perte ; au-delà, on s'arrête en montrant la copie de secours,
  # au lieu de repartir de « {} » et d'effacer les réglages de l'utilisateur.
  # ---------------------------------------------------------------------------
  local REGLAGES="$HOME/.claude/settings.json"
  if [ -f "$REGLAGES" ] && [ "$SAUVEGARDE_REUTILISEE" = "0" ]; then
    DERNIERE_COPIE=$(ls -1t "$REGLAGES".avant-cerveau-* 2>/dev/null | head -1)
    if [ -z "$DERNIERE_COPIE" ] || ! cmp -s "$REGLAGES" "$DERNIERE_COPIE"; then
      cp "$REGLAGES" "$REGLAGES.avant-cerveau-$HORO"
    fi
  fi

  python3 - "$REGLAGES" "$DESTINATION" <<'PY'
import json, os, sys

chemin, cerveau = sys.argv[1], sys.argv[2]

def sans_commentaires(texte):
    """Retire les commentaires // et /* */, sans toucher aux chaînes."""
    sortie, i, dedans_chaine, echappe = [], 0, False, False
    while i < len(texte):
        c = texte[i]
        if dedans_chaine:
            sortie.append(c)
            if echappe:
                echappe = False
            elif c == "\\":
                echappe = True
            elif c == '"':
                dedans_chaine = False
            i += 1
            continue
        if c == '"':
            dedans_chaine = True
            sortie.append(c); i += 1; continue
        if c == "/" and i + 1 < len(texte) and texte[i + 1] == "/":
            while i < len(texte) and texte[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < len(texte) and texte[i + 1] == "*":
            fin = texte.find("*/", i + 2)
            i = len(texte) if fin < 0 else fin + 2
            continue
        sortie.append(c); i += 1
    return "".join(sortie)

def sans_virgules_finales(texte):
    """Retire les virgules qui précèdent une } ou une ] (hors chaînes)."""
    sortie, i, dedans_chaine, echappe = [], 0, False, False
    while i < len(texte):
        c = texte[i]
        if dedans_chaine:
            sortie.append(c)
            if echappe:
                echappe = False
            elif c == "\\":
                echappe = True
            elif c == '"':
                dedans_chaine = False
            i += 1
            continue
        if c == '"':
            dedans_chaine = True
            sortie.append(c); i += 1; continue
        if c == ",":
            j = i + 1
            while j < len(texte) and texte[j] in " \t\r\n":
                j += 1
            if j < len(texte) and texte[j] in "}]":
                i += 1
                continue
        sortie.append(c); i += 1
    return "".join(sortie)

def fermer_crochets(texte):
    """Referme les { et [ restés ouverts (fichier tronqué en pleine écriture)."""
    pile, dedans_chaine, echappe = [], False, False
    for c in texte:
        if dedans_chaine:
            if echappe:
                echappe = False
            elif c == "\\":
                echappe = True
            elif c == '"':
                dedans_chaine = False
            continue
        if c == '"':
            dedans_chaine = True
        elif c in "{[":
            pile.append("}" if c == "{" else "]")
        elif c in "}]" and pile:
            pile.pop()
    if dedans_chaine:
        return None
    return texte + "".join(reversed(pile))

def reparer(texte):
    """Essaie de lire un JSON abîmé sans rien perdre. None si impossible."""
    essais = [texte,
              sans_virgules_finales(sans_commentaires(texte))]
    for essai in essais:
        for variante in (essai, fermer_crochets(essai.rstrip().rstrip(","))):
            if variante is None:
                continue
            try:
                return json.loads(variante)
            except Exception:
                pass
    return None

donnees = {}
fichier_absent = not os.path.exists(chemin)
if not fichier_absent:
    try:
        with open(chemin, encoding="utf-8-sig") as f:
            texte = f.read()
    except OSError as e:
        print("ERREUR : impossible de lire %s : %s" % (chemin, e), file=sys.stderr)
        sys.exit(3)

    if not texte.strip():
        # Fichier vide : ce n'est pas une perte, il n'y avait rien dedans.
        donnees = {}
    else:
        try:
            donnees = json.loads(texte)
        except Exception as e:
            donnees = reparer(texte)
            if donnees is None:
                print("ERREUR : %s n'est pas un JSON lisible (%s)." % (chemin, e), file=sys.stderr)
                sys.exit(3)
            print("  → ton settings.json avait une forme abîmée : je l'ai réparé sans rien perdre",
                  file=sys.stderr)

    if not isinstance(donnees, dict):
        print("ERREUR : %s ne contient pas un objet JSON." % chemin, file=sys.stderr)
        sys.exit(3)

# 1. Mémoire automatique native dirigée vers ~/cerveau/notes
donnees["autoMemoryDirectory"] = os.path.join(cerveau, "notes")

# 2. Permissions : accès au dossier du cerveau + commandes cerveau et git
perm = donnees.setdefault("permissions", {})
if not isinstance(perm, dict):
    print("ERREUR : la clé « permissions » de %s n'est pas un objet JSON." % chemin, file=sys.stderr)
    sys.exit(3)
dirs = perm.setdefault("additionalDirectories", [])
if not isinstance(dirs, list):
    print("ERREUR : permissions.additionalDirectories de %s n'est pas une liste." % chemin, file=sys.stderr)
    sys.exit(3)
if cerveau not in dirs:
    dirs.append(cerveau)

allow = perm.setdefault("allow", [])
if not isinstance(allow, list):
    print("ERREUR : permissions.allow de %s n'est pas une liste." % chemin, file=sys.stderr)
    sys.exit(3)
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

# 3. Hook SessionStart : lance cerveau --auto en tâche de fond au démarrage.
#    (async, donc il ne retarde jamais l'ouverture de Claude.)
hooks = donnees.setdefault("hooks", {})
if not isinstance(hooks, dict):
    print("ERREUR : la clé « hooks » de %s n'est pas un objet JSON." % chemin, file=sys.stderr)
    sys.exit(3)
session_start = hooks.setdefault("SessionStart", [])
if isinstance(session_start, dict):
    # Ancienne forme (un seul bloc au lieu d'une liste) : on la garde, mise en liste.
    session_start = [session_start]
    hooks["SessionStart"] = session_start
if not isinstance(session_start, list):
    print("ERREUR : hooks.SessionStart de %s n'est ni une liste ni un objet." % chemin, file=sys.stderr)
    sys.exit(3)
commande_auto = f"{cmd_cerveau} --auto"
deja_present = False
for bloc_hook in session_start:
    if not isinstance(bloc_hook, dict):
        continue
    for h in bloc_hook.get("hooks", []) or []:
        if not isinstance(h, dict):
            continue
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

# Écriture atomique : un Ctrl-C ou un disque plein ne laisse pas un fichier vide.
os.makedirs(os.path.dirname(chemin), exist_ok=True)
tmp = chemin + ".tmp-cerveau"
try:
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(donnees, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, chemin)
except OSError as e:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    print("ERREUR : impossible d'écrire %s : %s" % (chemin, e), file=sys.stderr)
    sys.exit(3)

print("ok")
PY
  CODE_REGLAGES=$?

  if [ "$CODE_REGLAGES" -ne 0 ]; then
    echo "  ERREUR : les réglages de Claude Code n'ont pas pu être mis à jour"
    echo "    (fichier : $REGLAGES)."
    echo "    Ton fichier d'origine n'a PAS été remplacé. La copie d'avant est ici :"
    echo "      $REGLAGES.avant-cerveau-$HORO"
    echo "    Corrige ou renomme ce fichier (s'il est abîmé), puis relance la même"
    echo "    commande. Rien n'a été supprimé."
    return 1
  fi

  # On ne reparse pas le résultat : on vérifie que la clé qu'on vient d'écrire est là.
  if python3 - "$REGLAGES" "$DESTINATION" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d.get("autoMemoryDirectory") == os.path.join(sys.argv[2], "notes")
assert d.get("permissions", {}).get("additionalDirectories")
PY
  then
    echo "  ok : mémoire automatique et synchro de démarrage branchées"
  else
    echo "  ERREUR : les réglages écrits dans $REGLAGES ne contiennent pas la mémoire"
    echo "    automatique. La copie d'avant est ici : $REGLAGES.avant-cerveau-$HORO"
    echo "    Rien n'a été supprimé : relance la même commande après avoir vérifié ce fichier."
    return 1
  fi

  # ---------------------------------------------------------------------------
  # Bilan
  # ---------------------------------------------------------------------------
  # L'état d'arrivée est noté dans la sauvegarde : c'est lui qu'on comparera au
  # passage suivant pour ne pas empiler un dossier identique. Si l'empreinte
  # n'est pas calculable (outil absent, fichier illisible), on n'écrit rien :
  # le passage suivant ne reconnaîtra pas la sauvegarde et en refera une, ce
  # qui est le comportement sûr.
  if [ -d "$SAUVEGARDE" ] && [ -f "$SAUVEGARDE/.etat-avant" ]; then
    local ETAT_APRES=""
    ETAT_APRES=$(empreinte_etat) || ETAT_APRES=""
    [ -n "$ETAT_APRES" ] && printf '%s\n' "$ETAT_APRES" > "$SAUVEGARDE/.etat-apres" 2>/dev/null
  fi

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
    echo "Attention, une sauvegarde de tes fichiers d'avant a été posée sur le Bureau :"
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
