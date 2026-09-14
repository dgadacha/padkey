#!/bin/bash
# Compile PadKey et assemble PadKey.app.
# Usage : ./build.sh [--no-install]
set -euo pipefail

cd "$(dirname "$0")"

BUNDLE_ID="com.tealforge.padkey"
APP_NAME="PadKey"
# Version unique du projet, partagee avec package.sh.
VERSION=$(tr -d ' \n' < VERSION)
# Numero de build : horodatage compact, toujours croissant, sans fichier d'etat.
BUILD=$(date +%Y%m%d.%H%M)
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"
INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

echo "==> Compilation de $APP_NAME $VERSION (build $BUILD)"
swift build -c release

echo "==> Assemblage du bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/dualsense-*.png "$APP/Contents/Resources/"
cp Resources/CREDITS.md Resources/GamepadAssetPack-LICENSE.txt "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# macOS 26 encadre les icones fournies uniquement en .icns. Compiler le catalogue
# d'assets et declarer CFBundleIconName fait traiter l'icone comme une icone
# moderne, affichee telle quelle.
xcrun actool Resources/Assets.xcassets \
    --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /dev/null >/dev/null 2>&1 || \
    echo "    (catalogue d'icones ignore : actool indisponible)"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>PadKey</string>
</dict>
</plist>
PLIST

echo "==> Signature locale"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1

if [[ $INSTALL -eq 1 ]]; then
    echo "==> Installation dans $INSTALL_DIR"
    # L'app en cours d'execution doit etre arretee sinon la copie echoue.
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 0.4
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$APP" "$INSTALL_DIR/$APP_NAME.app"
    TARGET="$INSTALL_DIR/$APP_NAME.app"

    # Une signature locale change d'empreinte a chaque compilation : macOS invalide
    # alors l'autorisation Accessibilite sans le dire. On la remet a zero pour que
    # l'app la redemande proprement au lancement. Inutile quand on se contente de
    # construire, par exemple pour fabriquer l'image disque.
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
else
    TARGET="$PWD/$APP"
fi

echo
echo "Pret : $TARGET"
echo "Lancement :  open \"$TARGET\""
echo "A la premiere ouverture, autorisez PadKey dans"
echo "Reglages Systeme > Confidentialite et securite > Accessibilite."
