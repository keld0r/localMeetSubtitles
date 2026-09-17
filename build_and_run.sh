#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=========================================================="
echo "  LocalMeetSubtitles - Compilador y Lanzador macOS"
echo "  100% Localhost • Sin Nube • Confidencial • Apple Silicon"
echo "=========================================================="

# 0. Comprobar dependencias del sistema
if ! command -v swiftc &> /dev/null; then
    echo "✗ Error: No se encontró el compilador 'swiftc'."
    echo "  Por favor instala las herramientas de Xcode ejecutando:"
    echo "  xcode-select --install"
    exit 1
fi

if ! command -v whisper-cli &> /dev/null && [ ! -f "/opt/homebrew/bin/whisper-cli" ] && [ ! -f "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli" ]; then
    echo "✗ Error: No se encontró 'whisper-cli'."
    echo "  En tu nuevo Mac puedes instalarlo fácilmente con Homebrew:"
    echo "  brew install whisper-cpp"
    exit 1
fi

# 1. Comprobar modelos Whisper
if [ ! -f "$DIR/models/ggml-small.bin" ]; then
    echo "[1/3] Descargando modelo recomendado Whisper Small..."
    ./download_model.sh small
else
    echo "[1/3] ✓ Modelo Whisper Small (Recomendado) verificado (465 MB)"
fi

if [ ! -f "$DIR/models/ggml-base.bin" ]; then
    echo "[1/3] Descargando modelo Whisper Base..."
    ./download_model.sh base
fi

if [ ! -f "$DIR/models/ggml-tiny.bin" ]; then
    echo "[1/3] Descargando modelo Whisper Tiny..."
    ./download_model.sh tiny
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
