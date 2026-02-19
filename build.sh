#!/bin/bash
set -e

cd "$(dirname "$0")"

APP="build/GitGrove.app"

echo "🔨 Building release..."
swift build -c release

echo "📦 Packaging .app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/release/GitGrove "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"

echo "✅ Built: $APP"
