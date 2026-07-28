#!/bin/sh
# Aplatit une icône PNG en RGB pur (sans canal alpha) avant import dans
# l'Asset Catalog — l'App Store rejette une icône 1024×1024 avec transparence,
# même invisible. Voir Tutorial/guide-publication-app-store.md §6.

sips -s format jpeg -s formatOptions best mon-image.png --out /tmp/plat.jpg
sips -s format png -z 1024 1024 /tmp/plat.jpg --out AppIcon.png
