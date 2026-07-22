#!/bin/bash
B="$HOME/.local/bin"; V="$HOME/.local/opt/whisper-env"
A="$(cat "$HOME/.derush-studio-emplacement" 2>/dev/null)"
[ -z "$A" ] && A="$HOME/Derush Studio"
ok(){ printf "  ✓ %s\n" "$1"; }; ko(){ printf "  ✗ %s\n" "$1"; N=$((N+1)); }
N=0
echo ""; echo "  VÉRIFICATION DE L'INSTALLATION"; echo ""
[ -s "$B/node" ] && "$B/node" --version 2>/dev/null | grep -q '^v[0-9]' \
  && ok "Node $("$B/node" --version)" || ko "Node manquant ou cassé"
for o in ffmpeg ffprobe; do
  [ -s "$B/$o" ] && "$B/$o" -version >/dev/null 2>&1 && ok "$o" || ko "$o manquant ou cassé"
done
[ -s "$V/bin/python" ] && [ "$("$V/bin/python" -c 'print(42)' 2>/dev/null)" = 42 ] \
  && ok "Python" || ko "Python cassé"
"$V/bin/python" -c 'import faster_whisper,anthropic,cv2,av' 2>/dev/null \
  && ok "bibliothèques de transcription" || ko "bibliothèques incomplètes"
M=0
for f in "$HOME/.cache/huggingface/hub/models--Systran--faster-whisper-medium"/snapshots/*/model.bin; do
  [ -f "$f" ] && M=$(wc -c < "$f")
done
[ "$M" -gt 1000000000 ] && ok "modèle de transcription ($((M/1000000)) Mo)" \
  || ko "modèle incomplet ($((M/1000000)) Mo au lieu de ~1500)"
echo ""; echo "  Application : $A"
MQ=""
for f in server.mjs detect.mjs timeline_xml.mjs ctas.py reels_ai.py \
         transcribe_full.py waveform.py zooms.py public/index.html; do
  [ -f "$A/$f" ] || MQ="$MQ $f"
done
[ -z "$MQ" ] && ok "les 9 fichiers de l'application" || ko "fichiers manquants :$MQ"
[ -s "$A/Lancer Derush Studio.command" ] && ok "lanceur présent" || ko "lanceur absent"
[ -x "$A/Lancer Derush Studio.command" ] && ok "lanceur cliquable" \
  || printf "  · lanceur non cliquable — lance-le ainsi :\n    bash \"%s/Lancer Derush Studio.command\"\n" "$A"
[ -s "$HOME/Desktop/Derush Studio.command" ] && ok "raccourci sur le Bureau" \
  || printf "  · pas de raccourci sur le Bureau\n"
echo ""
[ "$N" = 0 ] && printf "  TOUT EST EN ORDRE\n\n" \
  || printf "  %s PROBLÈME(S) — envoie cet écran à Tom\n\n" "$N"
