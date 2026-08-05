#!/bin/bash
# resize-screenshots.sh
# Conforme des captures d'écran iPhone aux dimensions exigées par App Store Connect.
#
# Usage : ./resize-screenshots.sh /chemin/vers/dossier/captures [dossier-sortie]
# Sans argument, utilise le dossier courant.
#
# Deux tailles sont produites, dans deux sous-dossiers :
#   6.9-inch — 2868 x 1320 (paysage) / 1320 x 2868 (portrait)
#   6.5-inch — 2778 x 1284 (paysage) / 1284 x 2778 (portrait)
# La première est celle qu'App Store Connect réclame pour une soumission
# récente ; la seconde reste acceptée et sert de repli. En cas de doute c'est
# App Store Connect qui tranche : il refuse à l'envoi toute taille non conforme,
# et c'est une vérification qui ne coûte rien.
#
# Le redimensionnement est **proportionnel**, suivi d'un recadrage centré de
# l'excédent — quelques pixels au plus. La version précédente forçait les deux
# dimensions d'un coup (`sips -z`), ce qui étirait légèrement l'image :
# imperceptible, mais c'est une déformation qu'on s'infligeait sans raison.

set -e

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-$INPUT_DIR/conformes}"

if [ ! -d "$INPUT_DIR" ]; then
  echo "Dossier introuvable : $INPUT_DIR"
  exit 1
fi

# conform <fichier> <dossier> <largeur> <hauteur>
conform() {
  local src="$1" dir="$2" tw="$3" th="$4"
  local out="$dir/$(basename "${src%.*}").png"
  mkdir -p "$dir"

  local w h
  w=$(sips -g pixelWidth  "$src" | awk '/pixelWidth:/  {print $2}')
  h=$(sips -g pixelHeight "$src" | awk '/pixelHeight:/ {print $2}')

  # Cible en portrait pour une source en portrait, et inversement.
  if { [ "$w" -ge "$h" ] && [ "$tw" -lt "$th" ]; } ||
     { [ "$w" -lt "$h" ] && [ "$tw" -ge "$th" ]; }; then
    local t=$tw; tw=$th; th=$t
  fi

  cp "$src" "$out"

  # Mise à l'échelle par le côté le plus contraignant : l'image couvre la cible,
  # jamais l'inverse — recadrer vaut mieux que laisser une bande vide.
  if [ "$((w * th))" -gt "$((h * tw))" ]; then
    sips --resampleHeight "$th" "$out" > /dev/null
  else
    sips --resampleWidth "$tw" "$out" > /dev/null
  fi
  sips --cropToHeightWidth "$th" "$tw" "$out" > /dev/null

  # App Store Connect refuse un canal alpha.
  sips -s format png --deleteColorManagementProperties "$out" > /dev/null

  printf "  %-26s %sx%s -> %sx%s\n" "$(basename "$out")" "$w" "$h" "$tw" "$th"
}

count=0
while IFS= read -r -d '' file; do
  echo "$(basename "$file") :"
  conform "$file" "$OUTPUT_DIR/6.9-inch" 2868 1320
  conform "$file" "$OUTPUT_DIR/6.5-inch" 2778 1284
  count=$((count + 1))
done < <(find "$INPUT_DIR" -maxdepth 1 -type f \
              \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0 | sort -z)

echo ""
if [ "$count" -eq 0 ]; then
  echo "Aucune image trouvée dans $INPUT_DIR"
else
  echo "$count capture(s) conformée(s) en deux tailles dans : $OUTPUT_DIR"
  echo "Les fichiers d'origine n'ont pas été modifiés."
fi
