#!/bin/bash
set -e

MODEL_TYPE="${1:-base}"
MODELS_DIR="$(cd "$(dirname "$0")" && pwd)/models"
mkdir -p "$MODELS_DIR"

MODEL_FILE="ggml-${MODEL_TYPE}.bin"
TARGET_PATH="${MODELS_DIR}/${MODEL_FILE}"

if [ -f "$TARGET_PATH" ] && [ -s "$TARGET_PATH" ]; then
    echo "✓ El modelo $MODEL_FILE ya está descargado en $TARGET_PATH"
    exit 0
fi

echo "=========================================================="
echo " Descargando modelo Whisper GGML: $MODEL_FILE"
echo " Destino: $TARGET_PATH"
echo "=========================================================="

URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_FILE}"

curl -L -C - --progress-bar "$URL" -o "$TARGET_PATH"

if [ -f "$TARGET_PATH" ] && [ -s "$TARGET_PATH" ]; then
    echo "✓ Descarga completada exitosamente: $TARGET_PATH"
    ls -lh "$TARGET_PATH"
else
    echo "✗ Error al descargar el modelo."
    exit 1
fi
