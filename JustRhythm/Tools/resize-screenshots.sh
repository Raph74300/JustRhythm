#!/bin/bash
# resize-screenshots.sh
# Conforme des captures d'écran iPhone aux dimensions exigées par App Store Connect.
# Usage : ./resize-screenshots.sh /chemin/vers/dossier/captures
# Sans argument, utilise le dossier courant.

set -e

INPUT_DIR="${1:-.}"
OUTPUT_DIR="$INPUT_DIR/AppStore-Ready"

if [ ! -d "$INPUT_DIR" ]; then
  echo "Dossier introuvable : $INPUT_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Dimensions acceptées par App Store Connect (catégorie iPhone 6,5")
PORTRAIT_W=1284
PORTRAIT_H=2778
LANDSCAPE_W=2778
LANDSCAPE_H=1284

count=0

while IFS= read -r -d '' file; do
  filename=$(basename "$file")

  width=$(sips -g pixelWidth "$file" | awk '/pixelWidth:/ {print $2}')
  height=$(sips -g pixelHeight "$file" | awk '/pixelHeight:/ {print $2}')

  if [ "$width" -ge "$height" ]; then
    target_w=$LANDSCAPE_W
    target_h=$LANDSCAPE_H
  else
    target_w=$PORTRAIT_W
    target_h=$PORTRAIT_H
  fi

  cp "$file" "$OUTPUT_DIR/$filename"
  sips -z "$target_h" "$target_w" "$OUTPUT_DIR/$filename" > /dev/null

  echo "OK: $filename (${width}x${height}) -> ${target_w}x${target_h}"
  count=$((count + 1))
done < <(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

echo ""
if [ "$count" -eq 0 ]; then
  echo "Aucune image trouvee dans $INPUT_DIR"
else
  echo "$count capture(s) conforme(s) generee(s) dans : $OUTPUT_DIR"
  echo "Les fichiers originaux n'ont pas ete modifies."
fi
