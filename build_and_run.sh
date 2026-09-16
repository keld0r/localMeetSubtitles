#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=========================================================="
echo "  LocalMeetSubtitles - Compilador y Lanzador macOS"
echo "  100% Localhost • Sin Nube • Confidencial • Apple Silicon"
echo "=========================================================="

# 1. Comprobar modelo Whisper
if [ ! -f "$DIR/models/ggml-base.bin" ]; then
    echo "[1/3] Descargando modelo base de Whisper..."
    ./download_model.sh base
else
    echo "[1/3] ✓ Modelo Whisper base verificado (141 MB)"
fi

# 2. Compilar aplicación Swift
echo "[2/3] Compilando aplicación nativa en Swift..."
mkdir -p "$DIR/build"
SWIFT_CACHE_DIR="$DIR/build/.swift_cache"
mkdir -p "$SWIFT_CACHE_DIR"

swiftc -module-cache-path "$SWIFT_CACHE_DIR" \
       -O \
       "$DIR"/Sources/*.swift \
       -o "$DIR/build/LocalMeetSubtitles"

chmod +x "$DIR/build/LocalMeetSubtitles"
echo "[3/3] ✓ Compilación exitosa: $DIR/build/LocalMeetSubtitles"

# 3. Ejecutar si no se especificó --build-only
if [ "$1" != "--build-only" ]; then
    echo ""
    echo "=========================================================="
    echo "  Iniciando LocalMeetSubtitles..."
    echo "  - Overlay flotante de subtítulos activo en tu pantalla"
    echo "  - Ícono '💬' en la barra de menú superior"
    echo "  - Atajo Cmd+Shift+K para alternar modo Click-Through"
    echo "=========================================================="
    "$DIR/build/LocalMeetSubtitles"
fi
