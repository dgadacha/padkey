#!/bin/bash
# Fabrique l'image disque d'installation : dist/PadKey-<version>.dmg
# Usage : ./package.sh
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="PadKey"
VERSION=$(tr -d ' \n' < VERSION)
VOLUME="$APP_NAME"
APP="build/$APP_NAME.app"
DIST="dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

echo "==> Construction de l'application"
./build.sh --no-install >/dev/null
[[ -d "$APP" ]] || { echo "Application introuvable : $APP"; exit 1; }

echo "==> Preparation du contenu"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE" "$DIST/rw.dmg"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp Resources/dmg-background.tiff "$STAGE/.background/background.tiff"

mkdir -p "$DIST"
rm -f "$DMG" "$DIST/rw.dmg"

# Un volume demonte proprement evite les erreurs de ressource occupee.
hdiutil detach "/Volumes/$VOLUME" >/dev/null 2>&1 || true

echo "==> Creation de l'image"
SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 30 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOLUME" -fs HFS+ \
    -format UDRW -size "${SIZE}m" "$DIST/rw.dmg" >/dev/null

echo "==> Mise en page de la fenetre"
hdiutil attach "$DIST/rw.dmg" -mountpoint "/Volumes/$VOLUME" -nobrowse >/dev/null

# Le Finder est le seul a savoir poser un fond et des positions d'icones.
# Si l'automatisation est refusee, l'image reste utilisable, juste sans decor.
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "    (mise en page ignoree : automatisation du Finder indisponible)"
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 562}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 112
        set text size of options to 12
        set background picture of options to file ".background:background.tiff"
        set position of item "$APP_NAME.app" of container window to {165, 212}
        set position of item "Applications" of container window to {495, 212}
        close
        open
        update without registering applications
        delay 1.5
    end tell
end tell
APPLESCRIPT

# L'icone du volume se pose en dernier : le Finder efface le fichier s'il est
# depose avant que la fenetre soit mise en page.
cp Resources/AppIcon.icns "/Volumes/$VOLUME/.VolumeIcon.icns"
SetFile -a C "/Volumes/$VOLUME"

sync
hdiutil detach "/Volumes/$VOLUME" >/dev/null

echo "==> Compression"
hdiutil convert "$DIST/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$DIST/rw.dmg"

echo
echo "Image prete : $DMG ($(du -h "$DMG" | cut -f1))"
echo
echo "L'application est signee localement, sans compte developpeur Apple."
echo "Sur une autre machine, macOS la bloquera au premier lancement :"
echo "clic droit sur PadKey > Ouvrir, puis Ouvrir dans la boite de dialogue."
echo "Si le fichier a transite par internet :"
echo "  xattr -dr com.apple.quarantine /Applications/PadKey.app"
