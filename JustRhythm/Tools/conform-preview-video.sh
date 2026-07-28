#!/bin/bash
# conform-preview-video.sh
# Conforme une vidéo (App Preview) aux exigences App Store Connect.
# Usage : ./conform-preview-video.sh input.mov [portrait|landscape]
# Sans second argument, l'orientation est détectée automatiquement.

set -e

INPUT="$1"
ORIENTATION="$2"

if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo "Usage : $0 fichier_video.mov [portrait|landscape]"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg est requis. Installe-le avec : brew install ffmpeg"
  exit 1
fi

BASENAME=$(basename "$INPUT")
NAME_NO_EXT="${BASENAME%.*}"
OUTPUT_DIR=$(dirname "$INPUT")/AppStore-Preview-Ready
mkdir -p "$OUTPUT_DIR"
OUTPUT="$OUTPUT_DIR/${NAME_NO_EXT}-conforme.mp4"

# Dimensions officielles App Preview iPhone (2026)
PORTRAIT_W=886
PORTRAIT_H=1920
LANDSCAPE_W=1920
LANDSCAPE_H=886

# Détection d'orientation si non précisée
if [ -z "$ORIENTATION" ]; then
  width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$INPUT")
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$INPUT")
  if [ "$width" -ge "$height" ]; then
    ORIENTATION="landscape"
  else
    ORIENTATION="portrait"
  fi
fi

if [ "$ORIENTATION" = "landscape" ]; then
  TARGET_W=$LANDSCAPE_W
  TARGET_H=$LANDSCAPE_H
else
  TARGET_W=$PORTRAIT_W
  TARGET_H=$PORTRAIT_H
fi

# Vérifier la présence d'une piste audio
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "$INPUT")

# Durée (pour avertissement, pas de découpe automatique)
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")

echo "Source : ${width:-?}x${height:-?}, orientation détectée/choisie : $ORIENTATION"
echo "Cible  : ${TARGET_W}x${TARGET_H}"
echo "Audio présent : $([ -n "$HAS_AUDIO" ] && echo oui || echo non — piste silencieuse ajoutée)"

if [ -n "$HAS_AUDIO" ]; then
  # Vidéo avec audio existant : on le ré-encode en AAC stéréo
  ffmpeg -y -i "$INPUT" \
    -vf "scale=${TARGET_W}:${TARGET_H}:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2,fps=30" \
    -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
    -c:a aac -b:a 256k -ar 44100 -ac 2 \
    "$OUTPUT" -loglevel error
else
  # Pas d'audio : on ajoute une piste silencieuse obligatoire
  ffmpeg -y -i "$INPUT" \
    -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
    -vf "scale=${TARGET_W}:${TARGET_H}:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2,fps=30" \
    -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
    -c:a aac -b:a 256k -ar 44100 -ac 2 \
    -shortest \
    "$OUTPUT" -loglevel error
fi

FINAL_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT")
FINAL_DURATION_INT=${FINAL_DURATION%.*}

echo ""
echo "Fichier conforme généré : $OUTPUT"
echo "Durée : ${FINAL_DURATION_INT}s"

if [ "$FINAL_DURATION_INT" -lt 15 ]; then
  echo "ATTENTION : durée < 15s, Apple rejettera. Il faut une vidéo source plus longue."
elif [ "$FINAL_DURATION_INT" -gt 30 ]; then
  echo "ATTENTION : durée > 30s, Apple rejettera. Il faut couper la source avant conversion."
else
  echo "Durée conforme (entre 15 et 30s)."
fi
