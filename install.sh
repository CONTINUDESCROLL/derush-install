#!/bin/bash
# =============================================================================
#  DERUSH STUDIO — installation sur un Mac
#
#  Ce script est PUBLIC et ne contient aucun secret : c'est lui qui demande le
#  jeton d'accès. La commande d'installation est donc la même pour tout le monde.
#
#  Tout s'installe dans le dossier personnel : AUCUN mot de passe administrateur,
#  aucune modification du système. Pour désinstaller, il suffit de supprimer le
#  dossier de l'application et ~/.local.
#
#  L'utilisateur voit tout ce qui se passe : chaque étape est annoncée, avec le
#  temps qu'elle prend. Une installation muette qui dure vingt minutes donne
#  l'impression d'être plantée.
# =============================================================================
set -u

# Si GitHub refuse le jeton, git reclame un identifiant sur le terminal. Lance par
# « curl | bash », l'entree standard est occupee : le script se figeait POUR TOUJOURS
# sur « Password for 'https://ghp_xxx@github.com' » — en affichant le jeton en clair.
# Avec ceci, git echoue franchement et notre propre message s'affiche.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/usr/bin/true

# Le jeton passait dans l'URL de git : « ps » le montrait a n'importe quel processus de
# la machine, et il restait ensuite en clair dans .git/config. On le fournit par un
# assistant d'identifiants qui le lit dans l'environnement — jamais sur une ligne de
# commande — et on le range dans un fichier lisible par le seul proprietaire.
DERUSH_JETON=""
export DERUSH_JETON
armer_git() {                         # rend git capable de s'authentifier sans le jeton en clair
  DERUSH_JETON="$1"
  ASKPASS=$(mktemp); chmod 700 "$ASKPASS"
  printf '#!/bin/sh\ncase "$1" in *sername*) echo x-access-token ;; *) printf "%%s" "$DERUSH_JETON" ;; esac\n' > "$ASKPASS"
  export GIT_ASKPASS="$ASKPASS"
}
ranger_jeton() {                      # $1 = dossier de l'application, pour les mises a jour
  [ -d "$1/.git" ] || return 0
  git -C "$1" remote set-url origin "https://github.com/$DEPOT.git" 2>/dev/null
  printf 'https://x-access-token:%%s@github.com\n' "$DERUSH_JETON" > "$1/.git/.identifiants"
  chmod 600 "$1/.git/.identifiants"
  git -C "$1" config credential.helper "store --file=$1/.git/.identifiants"
  chmod 600 "$1/.git/config" 2>/dev/null
}

DEPOT="CONTINUDESCROLL/derush-studio"
APP="$HOME/Derush Studio"          # proposé par défaut, l'utilisateur peut choisir
BIN="$HOME/.local/bin"
VENV="$HOME/.local/opt/whisper-env"
NODE_V="v22.23.1"
ETAPES=6

# Un chemin peut contenir un guillemet ou un antislash. Injecte tel quel dans du code
# AppleScript, il casse la compilation : la fenetre ne s'ouvre PAS, et le monteur ne voit
# rien du tout. On echappe donc tout ce qui part vers osascript.
as_txt() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
rouge() { printf "\033[31m%s\033[0m\n" "$*"; }
vert()  { printf "\033[32m  ✓ %s\033[0m\n" "$*"; }
gris()  { printf "\033[90m    %s\033[0m\n" "$*"; }
etape() { printf "\n\033[1m[%s/%s] %s\033[0m\n" "$1" "$ETAPES" "$2"; }
fatal() { echo ""; rouge "  ✗ $1"; [ $# -gt 1 ] && gris "$2"
          osascript -e "display alert \"Installation interrompue\" message \"$(as_txt "$1")\"" >/dev/null 2>&1
          echo ""; exit 1; }

clear 2>/dev/null
cat <<'BAN'

  ╭──────────────────────────────────────────────╮
  │                                              │
  │            DERUSH  STUDIO                    │
  │            installation                      │
  │                                              │
  ╰──────────────────────────────────────────────╯

  Cette fenêtre va afficher chaque étape.
  Compte 15 à 25 minutes selon ta connexion.
  Tu peux continuer à travailler pendant ce temps.

  À SAVOIR :
  · aucun mot de passe administrateur ne sera demandé
  · macOS peut demander l'autorisation d'accéder à ton
    Bureau ou à tes Documents : réponds OK, c'est normal
  · tout s'installe dans ton dossier personnel

BAN

# ---------------------------------------------------------------- 1. la machine
etape 1 "Vérification de ton Mac"
[ "$(uname)" = "Darwin" ] || fatal "Cet outil fonctionne uniquement sur Mac."

# Un Mac Apple Silicon et un Mac Intel n'exécutent pas les mêmes binaires. Piège :
# un Terminal lancé sous Rosetta fait répondre x86_64 à uname sur une machine
# Apple Silicon — sysctl rétablit la vérité, sinon on installerait de l'émulé.
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
  ARCH="arm64"
fi
case "$ARCH" in
  arm64)  NODE_ARCH="darwin-arm64"; FF_ARCH="arm64"; PUCE="Apple Silicon" ;;
  x86_64) NODE_ARCH="darwin-x64";   FF_ARCH="amd64"; PUCE="Intel" ;;
  *)      fatal "Architecture inconnue : $ARCH" ;;
esac
vert "Mac $PUCE · macOS $(sw_vers -productVersion)"

if ! xcode-select -p >/dev/null 2>&1; then
  echo ""
  echo "  macOS doit d'abord installer ses outils de développement."
  echo "  Une fenêtre va s'ouvrir : clique sur « Installer », attends la fin,"
  echo "  puis relance la même commande."
  echo ""
  xcode-select --install 2>/dev/null
  exit 0
fi
vert "outils Apple présents"

# ---------------------------------------------------------------- 2. le jeton
etape 2 "Accès à l'application"
# DEUX MODES.
#  · LOCAL  : le code est dans le dossier qui contient ce script (envoyé par AirDrop,
#             clé USB, Drive…). Aucun jeton, aucune connexion à GitHub.
#  · DÉPÔT  : on va chercher le code sur GitHub, ce qui demande un jeton.
# Le mode local est essayé d'abord : s'il y a le code à côté, autant s'en servir.
# Lance par « curl | bash », le script n'existe pas sur le disque : $0 vaut « bash » et
# dirname renvoie « . », c'est-a-dire LE DOSSIER COURANT DU TERMINAL. Si le monteur
# lancait la commande depuis le dossier de l'application, on basculait en mode local et
# on recopiait l'application cassee sur elle-meme, sans jamais aller chercher la neuve.
SCRIPT="${BASH_SOURCE[0]:-$0}"
SRC=""
[ -f "$SCRIPT" ] && SRC="$(cd "$(dirname "$SCRIPT")" 2>/dev/null && pwd)"
MODE="depot"
if [ -n "$SRC" ] && [ -f "$SRC/server.mjs" ] && [ -f "$SRC/public/index.html" ]; then
  MODE="local"
  vert "code trouvé à côté du script — aucun jeton nécessaire"
  gris "source : $SRC"
fi

if [ "$MODE" = "depot" ]; then
# On REDEMANDE tant que le jeton n'est pas bon. Une faute de collage ne doit pas
# obliger à tout relancer : la fenêtre revient, en expliquant ce qui a échoué.
demander_jeton() {                    # $1 = message d'erreur du tour précédent
  local msg="Colle ici le jeton d'accès que Tom t'a envoyé."
  [ -n "${1:-}" ] && msg="⚠ $1

$msg"
  osascript <<AS 2>/dev/null
try
  set r to display dialog "$(as_txt "$msg")" with title "Derush Studio — installation" default answer "" with hidden answer buttons {"Annuler","Continuer"} default button "Continuer"
  return text returned of r
on error
  return "@@ANNULE@@"
end try
AS
}

JETON="${1:-}"
[ -n "$JETON" ] && gris "jeton fourni par la commande"
ERREUR=""
while true; do
  if [ -z "$JETON" ]; then
    echo "  Une fenêtre te demande le jeton fourni par Tom."
    JETON=$(demander_jeton "$ERREUR")
    # Annuler ARRETE. Un champ laisse vide n'est PAS une annulation : on redemande,
    # comme le script le promet, au lieu de tout abandonner sur une fausse manoeuvre.
    [ "$JETON" = "@@ANNULE@@" ] && fatal "Installation annulée." "Relance la commande quand tu auras le jeton."
    if [ -z "$JETON" ]; then ERREUR="Le champ était vide."; rouge "  ✗ $ERREUR"; continue; fi
  fi
  # Un copier-coller ramene souvent une espace ou un retour a la ligne invisible,
  # et GitHub refuse alors un jeton pourtant correct. On nettoie avant de tester.
  JETON=$(printf '%s' "$JETON" | tr -d '[:space:]')
  gris "vérification… (jeton de ${#JETON} caractères)"
  # « -H "Authorization: Bearer $JETON" » exposait le jeton a TOUS les processus de la
  # machine via ps. On le passe par un fichier de configuration lisible par soi seul ;
  # printf est une commande interne de bash, elle n'apparait pas non plus dans ps.
  CFG=$(mktemp); chmod 600 "$CFG"
  printf 'header = "Authorization: Bearer %s"\n' "$JETON" > "$CFG"
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 \
         --config "$CFG" "https://api.github.com/repos/$DEPOT")
  rm -f "$CFG"
  case "$CODE" in
    200) vert "jeton valide"; armer_git "$JETON"; break ;;
    401) ERREUR="Jeton refusé : il est incomplet, mal collé ou expiré." ;;
    403) ERREUR="Jeton valide mais sans autorisation. Il lui manque « Contents : Read-only » sur ce dépôt." ;;
    404) ERREUR="Ce jeton ne voit pas l'application. Vérifie qu'il donne accès au bon dépôt." ;;
    000) ERREUR="Pas de connexion internet. Vérifie ton réseau." ;;
    *)   ERREUR="Réponse inattendue de GitHub (code $CODE)." ;;
  esac
  rouge "  ✗ $ERREUR"
  gris "on réessaie — la fenêtre va revenir"
  JETON=""                            # on vide pour redemander
done
fi                                    # fin du mode dépôt

# ---------------------------------------------------------------- 3. emplacement
etape 3 "Où installer l'application"

# On retient l'emplacement choisi : sans ça, impossible de retrouver une installation
# que l'utilisateur aurait mise ailleurs que dans le dossier proposé par défaut.
MARQUEUR="$HOME/.derush-studio-emplacement"
ANCIEN=""
A_SUPPRIMER=""
[ -f "$MARQUEUR" ] && ANCIEN="$(cat "$MARQUEUR" 2>/dev/null)"
# Un disque externe DEBRANCHE n'est pas une installation supprimee. Confondre les deux
# faisait oublier l'adresse des montages ET reecrire le raccourci vers un dossier vide.
if [ -n "$ANCIEN" ] && [ ! -f "$ANCIEN/server.mjs" ]; then
  case "$ANCIEN" in
    /Volumes/*)
      VOL="/Volumes/$(printf '%s' "${ANCIEN#/Volumes/}" | cut -d/ -f1)"
      if [ ! -d "$VOL" ]; then
        echo ""
        rouge "  ✗ Le disque « $(basename "$VOL") » n'est pas branché."
        gris "Ton installation et tes montages sont dessus :"
        gris "$ANCIEN"
        gris "Branche le disque et relance la commande."
        osascript -e "display alert \"Disque absent\" message \"Branche le disque $(as_txt "$(basename "$VOL")") puis relance linstallation.\"" >/dev/null 2>&1
        echo ""; exit 1
      fi ;;
  esac
  ANCIEN=""
fi
[ -z "$ANCIEN" ] && [ -f "$HOME/Derush Studio/server.mjs" ] && ANCIEN="$HOME/Derush Studio"

choisir_dossier() {                   # ouvre le sélecteur, renvoie le chemin ou rien
  osascript <<'AS' 2>/dev/null
try
  set d to choose folder with prompt "Dans quel dossier installer Derush Studio ?" default location (path to home folder)
  return POSIX path of d
on error
  return ""
end try
AS
}

if [ -n "$ANCIEN" ]; then
  # Une installation existe déjà. On la MONTRE et on laisse décider — installer par
  # dessus en silence, c'était le défaut : l'utilisateur ne savait plus où ça allait.
  NMONTAGES=0
  [ -d "$ANCIEN/data" ] && NMONTAGES=$(ls -1 "$ANCIEN/data" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Une installation existe déjà :"
  gris "$ANCIEN"
  [ "$NMONTAGES" -gt 0 ] && gris "elle contient le travail de $NMONTAGES rush(s)"
  REP=$(osascript <<AS 2>/dev/null
try
  set r to display dialog "Derush Studio est déjà installé ici :

$ANCIEN

Le travail de $NMONTAGES rush(s) s'y trouve." with title "Derush Studio — installation" buttons {"Annuler","Installer ailleurs","Mettre à jour ici"} default button "Mettre à jour ici"
  return button returned of r
on error
  return ""
end try
AS
)
  case "$REP" in
    "Mettre à jour ici")
      APP="$ANCIEN"; vert "mise à jour sur place — ton travail est conservé" ;;
    "Installer ailleurs")
      CHOIX=$(choisir_dossier)
      [ -n "$CHOIX" ] || fatal "Installation annulée : aucun dossier choisi." \
        "Relance la commande et choisis un dossier."
      APP="${CHOIX%/}/Derush Studio"
      [ "$APP" = "$ANCIEN" ] && fatal "C'est le dossier de l'installation existante." \
        "Choisis un autre dossier, ou relance et prends « Mettre à jour ici »."
      # Supprimer l'ancienne emporterait les montages : on le dit, et on ne le
      # propose qu'explicitement, jamais par défaut.
      SUPPR=$(osascript <<AS 2>/dev/null
try
  set r to display dialog "Que faire de l'ancienne installation ?

$ANCIEN

Elle contient le travail de $NMONTAGES rush(s). La supprimer effacera ces montages définitivement." with title "Ancienne installation" buttons {"La garder","La supprimer"} default button "La garder"
  return button returned of r
on error
  return "La garder"
end try
AS
)
      # On NE SUPPRIME PAS MAINTENANT. Quatre etapes faillibles suivent (Node, ffmpeg,
      # 1,4 Go de modele, le code) : un echec laissait le monteur sans l'ancienne
      # installation ET sans la neuve. On note, et on supprime a la toute fin.
      if [ "$SUPPR" = "La supprimer" ]; then
        A_SUPPRIMER="$ANCIEN"
        gris "l'ancienne sera supprimée une fois la nouvelle installée"
      else
        gris "ancienne installation conservée : $ANCIEN"
      fi ;;
    *) fatal "Installation annulée." "Rien n'a été modifié." ;;
  esac
else
  echo "  Une fenêtre te demande de choisir un dossier."
  CHOIX=$(choisir_dossier)
  # « Annuler » ANNULE. Retomber en silence sur un emplacement par défaut laissait
  # l'utilisateur sans savoir où ses fichiers ont atterri — c'est le contraire de ce
  # qu'on lui promet en lui demandant de choisir.
  [ -n "$CHOIX" ] || fatal "Installation annulée : aucun dossier choisi." \
    "Relance la commande et choisis un dossier."
  APP="${CHOIX%/}/Derush Studio"
fi
# On n'ecrit le marqueur qu'APRES avoir prouve qu'on peut ecrire ici : sinon un mkdir
# rate effacait l'adresse de l'installation existante, qui devenait introuvable.
mkdir -p "$APP" 2>/dev/null || fatal "Impossible d'écrire dans « $APP »." \
  "Choisis un dossier de ton dossier personnel."
[ -w "$APP" ] || fatal "« $APP » n'est pas modifiable." "Choisis un autre dossier."
printf '%s' "$APP" > "$MARQUEUR"      # on saura le retrouver au prochain lancement
vert "$APP"

# ---------------------------------------------------------------- 4. les outils
telecharger() {                       # <url> <destination> — la source d'ffmpeg
  # « --max-time 180 » condamnait toute connexion sous ~2,8 Mbit/s, et chaque reprise
  # repartait de zero : cinq fois la meme portion, quinze minutes pour rien. On REPREND
  # ou on s'est arrete (-C -), et on n'abandonne que si le debit tombe vraiment a plat.
  for essai in 1 2 3 4 5; do
    curl -sfL -C - --connect-timeout 20 --speed-limit 2048 --speed-time 60 \
         -o "$2" "$1" && [ -s "$2" ] && return 0
    [ "$essai" -lt 5 ] && gris "connexion interrompue — reprise $essai/4 là où on s'est arrêté…"
    sleep 3
  done
  return 1
}

etape 4 "Outils vidéo et Node"
mkdir -p "$BIN"

# On teste que node DEMARRE, pas qu'un fichier du meme nom existe : un binaire tronque
# par un telechargement coupe est executable, et « [ -x ] » l'adoptait a vie. Toutes les
# relances suivantes affichaient « Node deja present () » — parentheses vides — puis
# « INSTALLATION TERMINEE », et l'application ne demarrait jamais.
noeud_ok(){ [ -s "$BIN/node" ] && "$BIN/node" --version 2>/dev/null | grep -q '^v[0-9]'; }
if noeud_ok; then
  gris "Node déjà présent ($("$BIN/node" --version))"
else
  gris "téléchargement de Node… (~30 Mo, moins d'une minute)"
  T=$(mktemp -d)
  telecharger "https://nodejs.org/dist/$NODE_V/node-$NODE_V-$NODE_ARCH.tar.gz" "$T/n.tgz" \
    || fatal "Téléchargement de Node impossible." "Vérifie ta connexion internet."
  tar -xzf "$T/n.tgz" -C "$T" 2>/dev/null \
    || fatal "L'archive de Node est illisible." "Le téléchargement a été coupé ; relance la commande."
  cp "$T"/node-*/bin/node "$BIN/node" 2>/dev/null && chmod +x "$BIN/node" 2>/dev/null
  rm -rf "$T"
  # rien n'est annonce avant d'avoir la preuve : on LANCE le binaire.
  noeud_ok || fatal "Node n'a pas pu être installé." "Relance la commande."
  vert "Node installé ($("$BIN/node" --version))"
fi

for outil in ffmpeg ffprobe; do
  if [ -s "$BIN/$outil" ] && "$BIN/$outil" -version >/dev/null 2>&1; then
    gris "$outil déjà présent"
  else
    gris "téléchargement de ${outil}… (~60 Mo)"
    T=$(mktemp -d)
    telecharger "https://ffmpeg.martin-riedl.de/redirect/latest/macos/$FF_ARCH/release/$outil.zip" "$T/o.zip" \
      || fatal "Téléchargement de $outil impossible." "La source est parfois indisponible ; réessaie dans quelques minutes."
    unzip -qo "$T/o.zip" -d "$T"
    f=$(find "$T" -name "$outil" -type f | head -1)
    [ -n "$f" ] && cp "$f" "$BIN/$outil" && chmod +x "$BIN/$outil"
    rm -rf "$T"
    { [ -s "$BIN/$outil" ] && "$BIN/$outil" -version >/dev/null 2>&1; } \
      || fatal "$outil n'a pas pu être installé." "Le téléchargement était incomplet ; relance la commande."
    vert "$outil installé"
  fi
done

# ---------------------------------------------------------------- 5. Python
etape 5 "Moteur de transcription"
# Une mise a jour de macOS peut casser un environnement Python existant. « -x » restait
# vrai, pip echouait, et le message envoyait le monteur verifier sa connexion — en
# boucle, sans issue. On teste que python DEMARRE, et on reconstruit sinon.
# Un fichier VIDE et executable est un script shell valide : il rend 0. « -c 'import sys' »
# le prenait donc pour un Python en etat de marche. On exige une SORTIE reconnaissable.
python_ok(){ [ -s "$VENV/bin/python" ] && [ "$("$VENV/bin/python" -c 'print(42)' 2>/dev/null)" = "42" ]; }
if python_ok; then
  gris "environnement Python déjà présent"
else
  [ -e "$VENV" ] && { gris "environnement Python inutilisable — reconstruction…"; rm -rf "$VENV"; }
  gris "création de l'environnement Python…"
  mkdir -p "$(dirname "$VENV")"
  /usr/bin/python3 -m venv "$VENV" || fatal "Création de l'environnement Python impossible."
  python_ok || fatal "L'environnement Python créé ne fonctionne pas." "Préviens Tom."
fi
gris "installation des bibliothèques… (2 à 5 minutes, c'est normal)"
"$VENV/bin/pip" install --quiet --upgrade pip 2>/dev/null
"$VENV/bin/pip" install --quiet \
  "faster-whisper==1.2.1" "anthropic==0.117.0" "numpy==2.0.2" \
  "opencv-python-headless==5.0.0.93" "av==15.1.0" "ctranslate2==4.8.1" \
  || fatal "Installation des bibliothèques échouée." "Vérifie ta connexion et relance la commande."
vert "bibliothèques prêtes"

# Le dossier de cache existe des la PREMIERE seconde du telechargement. S'y fier faisait
# passer un modele interrompu pour un modele complet, a chaque relance, pour toujours.
# On cherche le fichier de poids lui-meme, et on verifie qu'il fait bien son giga.
MODELE_OK=non
for f in "$HOME/.cache/huggingface/hub/models--Systran--faster-whisper-medium"/snapshots/*/model.bin; do
  [ -f "$f" ] && [ "$(wc -c < "$f" 2>/dev/null || echo 0)" -gt 1000000000 ] && MODELE_OK=oui
done
if [ "$MODELE_OK" = oui ]; then
  gris "modèle de transcription déjà téléchargé"
else
  gris "téléchargement du modèle de transcription… (1,4 Go — c'est LA longue étape,"
  gris "  compte 5 à 15 minutes ; rien ne s'affiche pendant ce temps, c'est normal)"
  if "$VENV/bin/python" - <<'PY' 2>/dev/null
from faster_whisper import WhisperModel
WhisperModel("medium", device="cpu", compute_type="int8")
PY
  then vert "modèle prêt"
  else gris "échec — il se téléchargera tout seul à la première transcription"
  fi
fi

# ---------------------------------------------------------------- 6. l'appli
etape 6 "Application"
if [ "$MODE" = "local" ]; then
  # Copie depuis le dossier fourni. On ne prend QUE le code : ni data/ (montages et
  # transcriptions de l'expéditeur), ni settings.json (ses réglages), ni sa clé API.
  gris "copie de l'application…"
  mkdir -p "$APP/public" "$APP/models"
  # « [ -f ] && cp » laissait passer six fichiers sur huit sans un mot : l'application
  # s'installait amputee de sa transcription ou de ses zooms, et l'annoncait « installee ».
  MANQUE=""
  for f in server.mjs detect.mjs timeline_xml.mjs \
           ctas.py reels_ai.py transcribe_full.py waveform.py zooms.py; do
    if [ -f "$SRC/$f" ]; then cp "$SRC/$f" "$APP/" || MANQUE="$MANQUE $f"
    else MANQUE="$MANQUE $f"; fi
  done
  [ -z "$MANQUE" ] || fatal "Le dossier source est incomplet." \
    "Fichiers manquants :$MANQUE — redemande l'archive complète à Tom."
  cp -R "$SRC/public/." "$APP/public/" 2>/dev/null
  cp -R "$SRC/models/." "$APP/models/" 2>/dev/null
  # On n'efface RIEN dans la destination : la copie ci-dessus est une liste blanche
  # de fichiers de code, elle n'apporte jamais data/ ni settings.json depuis la source.
  # Effacer ici détruirait les montages d'un monteur qui réinstalle par-dessus.
  [ -f "$APP/server.mjs" ] || fatal "La copie a échoué." "Le dossier source est-il complet ?"
  vert "application installée"
elif [ -d "$APP/.git" ]; then
  ranger_jeton "$APP"
  # Le && avalait l'echec : hors ligne ou jeton revoque, on affichait quand meme
  # « mise a jour effectuee » et le monteur repartait sur l'ancienne version.
  if git -C "$APP" fetch --quiet origin && git -C "$APP" reset --hard --quiet origin/main; then
    chmod 600 "$APP/.git/config"
    vert "mise à jour effectuée"
  else
    chmod 600 "$APP/.git/config"
    fatal "La mise à jour n'a pas pu être récupérée." \
      "Vérifie ta connexion, ou demande un nouveau jeton à Tom. L'application existante n'a pas été modifiée."
  fi
elif [ -f "$APP/server.mjs" ]; then
  # Installation venue du ZIP : pas de dépôt git, mais du CODE et surtout des MONTAGES.
  # On récupère la nouvelle version à côté, puis on remplace les fichiers de code
  # un par un — data/, settings.json et la clé API ne sont jamais touchés.
  gris "installation existante sans dépôt — mise à jour du code seul…"
  TMPG=$(mktemp -d)
  git clone --quiet --depth 1 "https://github.com/$DEPOT.git" "$TMPG/depot" \
    || fatal "Téléchargement de l'application impossible."
  # On ne detruit l'ancien .git qu'une fois le nouveau EN MAIN, et on verifie le mv :
  # sur un disque presque plein il echouait, et l'installation devenait definitivement
  # non-actualisable — en annoncant la reussite.
  [ -d "$TMPG/depot/.git" ] || fatal "Le téléchargement de l'application est incomplet." "Relance la commande."
  rm -rf "$APP/.git.ancien" 2>/dev/null
  [ -d "$APP/.git" ] && mv "$APP/.git" "$APP/.git.ancien"
  if mv "$TMPG/depot/.git" "$APP/.git"; then
    rm -rf "$APP/.git.ancien" 2>/dev/null
  else
    [ -d "$APP/.git.ancien" ] && mv "$APP/.git.ancien" "$APP/.git"
    rm -rf "$TMPG"
    fatal "Impossible d'installer la mise à jour." "Le disque est peut-être plein. Rien n'a été modifié."
  fi
  for f in server.mjs detect.mjs timeline_xml.mjs install.sh \
           ctas.py reels_ai.py transcribe_full.py waveform.py zooms.py; do
    [ -f "$TMPG/depot/$f" ] && cp "$TMPG/depot/$f" "$APP/"
  done
  mkdir -p "$APP/public" "$APP/models"
  cp -R "$TMPG/depot/public/." "$APP/public/" 2>/dev/null
  cp -R "$TMPG/depot/models/." "$APP/models/" 2>/dev/null
  rm -rf "$TMPG"
  ranger_jeton "$APP"
  git -C "$APP" fetch --quiet origin 2>/dev/null && git -C "$APP" reset --hard --quiet origin/main 2>/dev/null
  vert "mise à jour effectuée — tes montages sont intacts"
else
  # On n'efface JAMAIS un dossier qui contient déjà des choses.
  # Le Finder seme des .DS_Store et, sur les volumes externes, des fichiers « ._ ».
  # Un dossier VIDE A L'ECRAN etait donc refuse, et le monteur n'avait aucun moyen
  # de comprendre pourquoi. Ces fichiers-la ne comptent pas.
  RESTE=$(ls -A "$APP" 2>/dev/null | grep -v -e '^\.DS_Store$' -e '^\._' -e '^\.Spotlight-' -e '^\.Trashes$' -e '^\.fseventsd$' || true)
  [ -z "$RESTE" ] || fatal "« $APP » n'est pas vide." \
    "Relance l'installation et choisis un autre dossier."
  gris "téléchargement de l'application…"
  git clone --quiet --depth 1 "https://github.com/$DEPOT.git" "$APP" \
    || fatal "Téléchargement de l'application impossible."
  ranger_jeton "$APP"                 # jeton range hors de toute ligne de commande
  vert "application installée"
fi

cat > "$APP/Lancer Derush Studio.command" <<'LANCEUR'
#!/bin/bash
# Un double-clic dans le Finder ne passe AUCUN argument, or le serveur exige un rush :
# sans ça il s'arrêtait aussitôt et le navigateur affichait « impossible de se
# connecter ». On retient donc le dernier rush ouvert, et on le demande la 1re fois.
CIBLE="$0"
while [ -L "$CIBLE" ]; do CIBLE="$(readlink "$CIBLE")"; done   # raccourci du Bureau
cd "$(dirname "$CIBLE")" || exit 1
export PATH="$HOME/.local/bin:$PATH"

RUSH="${1:-}"
[ -z "$RUSH" ] && [ -f .dernier_rush ] && RUSH="$(cat .dernier_rush)"
if [ -z "$RUSH" ] || [ ! -f "$RUSH" ]; then
  RUSH=$(osascript -e 'try' \
    -e 'POSIX path of (choose file with prompt "Choisis un rush à ouvrir" of type {"mp4","mov","m4v","MP4","MOV","M4V"})' \
    -e 'on error' -e 'return ""' -e 'end try')
fi
if [ -z "$RUSH" ] || [ ! -f "$RUSH" ]; then
  echo "Aucun rush choisi — rien à ouvrir."
  exit 0
fi
printf '%s' "$RUSH" > .dernier_rush

# On ne tue QUE notre serveur. Un « pkill -f server.mjs » nu emportait aussi les
# projets Node du monteur qui portaient le meme nom de fichier — travail perdu.
[ -f .serveur.pid ] && kill "$(cat .serveur.pid)" 2>/dev/null
pkill -f "$PWD/server\.mjs" 2>/dev/null      # cas du redemarrage lance depuis l'interface
sleep 0.3
node server.mjs "$RUSH" &
printf '%s' "$!" > .serveur.pid
sleep 2
open "http://localhost:4300"
echo ""
echo "Derush Studio est lancé dans ton navigateur."
echo "Ferme cette fenêtre pour arrêter l'application."
wait
LANCEUR
# Le heredoc peut echouer (disque plein, dossier devenu non inscriptible) sans que rien
# ne le signale : on annoncait « raccourci cree » et le double-clic tombait dans le vide.
[ -s "$APP/Lancer Derush Studio.command" ] \
  || fatal "Le lanceur n'a pas pu être écrit dans « $APP »." "Le disque est-il plein ?"
chmod +x "$APP/Lancer Derush Studio.command" 2>/dev/null
# On NE SUPPOSE PAS que le chmod a pris. Sur un volume exFAT/FAT (disque externe), les
# droits Unix n'existent pas et tout est deja executable ; sur un partage reseau, ils
# peuvent au contraire etre refuses. Ce n'est bloquant ni dans un cas ni dans l'autre —
# le raccourci appelle le lanceur PAR bash — mais on veut le SAVOIR, pour donner a la
# fin une consigne qui marche vraiment au lieu d'un double-clic qui echouera.
if [ -x "$APP/Lancer Derush Studio.command" ]; then LANCEUR_EXEC=oui; else LANCEUR_EXEC=non; fi
# Un LIEN SYMBOLIQUE .command ne se lance pas au double-clic : le Finder regarde les
# droits du lien, qui n'en a pas. On écrit donc un VRAI petit fichier qui appelle le
# lanceur. Et macOS peut refuser l'accès au Bureau : on vérifie, sans faire échouer
# l'installation pour autant.
RACCOURCI=""
raccourci_vers() {                    # $1 = dossier cible
  [ -d "$1" ] || return 1
  # on appelle le lanceur PAR bash, pas en exec direct : si son bit d'exécution
  # saute (copie, mise à jour, volume externe en exFAT), le raccourci marche quand même.
  { printf '#!/bin/bash\nexec /bin/bash "%s/Lancer Derush Studio.command"\n' "$APP" > "$1/Derush Studio.command"; } 2>/dev/null || return 1
  chmod +x "$1/Derush Studio.command" 2>/dev/null || return 1
  [ -x "$1/Derush Studio.command" ]
}
if raccourci_vers "$HOME/Desktop"; then
  RACCOURCI="Bureau"; vert "raccourci créé sur le Bureau"
elif mkdir -p "$HOME/Applications" 2>/dev/null && raccourci_vers "$HOME/Applications"; then
  RACCOURCI="Applications"; vert "raccourci créé dans ton dossier Applications"
  gris "(macOS a refusé l'accès au Bureau)"
else
  gris "raccourci impossible à créer — le lanceur reste dans le dossier de l'application"
fi

# ---------------------------------------------------------------- terminé
cat <<'FIN'

  ╭──────────────────────────────────────────────╮
  │                                              │
  │            INSTALLATION TERMINÉE             │
  │                                              │
  ╰──────────────────────────────────────────────╯

FIN
if [ -n "$RACCOURCI" ]; then
  echo "  Un raccourci « Derush Studio » est dans ton $RACCOURCI."
  echo "  Double-clique dessus pour lancer l'application :"
  echo "  elle s'ouvrira toute seule dans ton navigateur."
  MSG="Un raccourci a ete place dans ton $RACCOURCI. Double-clique dessus pour lancer lapplication."
elif [ "$LANCEUR_EXEC" = oui ]; then
  echo "  Pour lancer l'application, ouvre ce dossier :"
  echo "    $APP"
  echo "  et double-clique sur « Lancer Derush Studio.command »."
  MSG="Ouvre le dossier de linstallation et double-clique sur Lancer Derush Studio.command"
else
  # Ni raccourci, ni bit d'execution : on ne renvoie pas le monteur vers un double-clic
  # qui lui repondra « Permission denied ». Cette commande-la marche partout.
  echo "  Pour lancer l'application, colle cette ligne dans le Terminal :"
  echo ""
  echo "    bash \"$APP/Lancer Derush Studio.command\""
  MSG="Colle dans le Terminal la commande affichee dans la fenetre pour lancer lapplication."
fi
cat <<'FIN2'

  Pour l'arrêter, ferme la fenêtre du Terminal
  qui s'ouvre en même temps.

FIN2
# L'ancienne installation n'est supprimee qu'ICI : tout a reussi, la neuve existe.
if [ -n "$A_SUPPRIMER" ] && [ -d "$A_SUPPRIMER" ] && [ "$A_SUPPRIMER" != "$APP" ]; then
  if [ -f "$APP/server.mjs" ]; then
    rm -rf "$A_SUPPRIMER" && vert "ancienne installation supprimée"
  else
    gris "ancienne installation CONSERVÉE : la nouvelle semble incomplète"
    gris "$A_SUPPRIMER"
  fi
fi
gris "application : $APP"
gris "mises à jour : bouton ⚙ en haut à droite de l'application"
# Filet de securite affiche DANS TOUS LES CAS : quel que soit le systeme de fichiers,
# le raccourci, ou les droits, cette commande lance l'application. Elle n'a besoin
# d'aucun bit d'execution, seulement du droit de lire le fichier.
gris "si rien ne se lance : bash \"$APP/Lancer Derush Studio.command\""
echo ""
osascript -e "display alert \"Derush Studio est installe\" message \"$MSG\" buttons {\"Parfait\"}" >/dev/null 2>&1
