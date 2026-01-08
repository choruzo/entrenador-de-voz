#!/bin/bash
# 03_download_base_model.sh
# Descarga el modelo base (checkpoint) para fine-tuning

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORK_DIR="$HOME/piper-training"
cd "$WORK_DIR" || exit 1

echo "========================================"
echo "📥 DESCARGA DE MODELO BASE"
echo "========================================"

# Crear directorio para modelos base
mkdir -p models_base
cd models_base

# Descargar checkpoint en_US-lessac-high (952 MB)
CHECKPOINT_FILE="en_US-lessac-high.ckpt"

if [ ! -f "$CHECKPOINT_FILE" ]; then
    echo -e "\n${YELLOW}📥 Descargando checkpoint (952 MB)...${NC}"
    echo "Esto puede tardar varios minutos dependiendo de tu conexión"
    
    wget --show-progress \
        "https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/7bf647cb000d8c8319c6cdd4289dd6b7d0d3eeb8/en/en_US/lessac/high/epoch=2218-step=838782.ckpt" \
        -O "$CHECKPOINT_FILE" \
        || { echo -e "${RED}❌ Error descargando checkpoint${NC}"; exit 1; }
    
    echo -e "${GREEN}✅ Checkpoint descargado exitosamente${NC}"
else
    echo -e "${GREEN}✅ Checkpoint ya existe${NC}"
fi

# Verificar tamaño del archivo (debe ser ~952 MB)
FILE_SIZE=$(stat -f%z "$CHECKPOINT_FILE" 2>/dev/null || stat -c%s "$CHECKPOINT_FILE" 2>/dev/null)
FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))

echo -e "\n📊 Información del checkpoint:"
echo "   Archivo: $CHECKPOINT_FILE"
echo "   Tamaño: ${FILE_SIZE_MB} MB"
echo "   Ubicación: $(pwd)"

if [ "$FILE_SIZE_MB" -lt 900 ]; then
    echo -e "${RED}⚠️ ADVERTENCIA: El archivo parece incompleto (< 900 MB)${NC}"
    echo "Considera eliminar el archivo y volver a ejecutar este script"
else
    echo -e "${GREEN}✅ Tamaño del archivo correcto${NC}"
fi

cd "$WORK_DIR"

echo -e "\n${GREEN}========================================"
echo "✅ DESCARGA DE MODELO BASE COMPLETADA"
echo "========================================${NC}"
echo ""
echo "Modelo disponible en:"
echo -e "  ${GREEN}$WORK_DIR/models_base/$CHECKPOINT_FILE${NC}"
echo ""
echo "Siguiente paso: Preparar tu dataset y ejecutar 04_clean_dataset.sh"
