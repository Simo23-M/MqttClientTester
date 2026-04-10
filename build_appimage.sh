#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/Desktop_Qt_6_8_3-Release"
TOOLS_DIR="/home/simo/Documents/Tools"
QT_DIR="/home/simo/Qt/6.8.3/gcc_64"
SQLDRIVERS="$QT_DIR/plugins/sqldrivers"
SQLDRIVERS_BAK="$QT_DIR/plugins/sqldrivers.bak"

cd "$BUILD_DIR"

echo "==> Cleaning AppDir..."
rm -rf AppDir

echo "==> Hiding Qt sqldrivers..."
if [ -d "$SQLDRIVERS" ]; then
    mv "$SQLDRIVERS" "$SQLDRIVERS_BAK"
elif [ ! -d "$SQLDRIVERS_BAK" ]; then
    echo "WARNING: sqldrivers not found, continuing anyway..."
fi

restore_sqldrivers() {
    if [ -d "$SQLDRIVERS_BAK" ]; then
        echo "==> Restoring Qt sqldrivers..."
        mv "$SQLDRIVERS_BAK" "$SQLDRIVERS"
    fi
}
trap restore_sqldrivers EXIT

echo "==> Running linuxdeploy..."
export PATH="$TOOLS_DIR:$PATH"
export QMAKE="$QT_DIR/bin/qmake"
export QML_SOURCES_PATHS="$SCRIPT_DIR/qml"
export EXTRA_QT_PLUGINS=wayland

"$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
    --appdir AppDir \
    --executable mqtt_tls_client_qml \
    --desktop-file "$SCRIPT_DIR/mqtt-client-tester.desktop" \
    --icon-file "$SCRIPT_DIR/AppIcon.png" \
    --plugin qt \
    --output appimage

echo "==> Done! AppImage created in $BUILD_DIR"
