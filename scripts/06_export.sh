#!/bin/bash
# 06_export.sh
# Exporta el modelo entrenado a formato ONNX

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="$HOME/piper-training"

# Verificar que estamos en el entorno virtual
if [ -z "$VIRTUAL_ENV" ]; then
    echo -e "${YELLOW}⚠️ Activando entorno virtual...${NC}"
    source "$WORK_DIR/venv/bin/activate"
fi

echo "========================================"
echo "📦 EXPORTACIÓN DE MODELO A ONNX"
echo "========================================"

# Si no se proporciona checkpoint, buscar el último automáticamente
if [ -z "$1" ]; then
    echo -e "${YELLOW}Buscando último checkpoint...${NC}"
    
    # Buscar en todos los datasets
    LAST_CHECKPOINT=""
    for dataset_dir in "$WORK_DIR"/datasets/*/; do
        if [ -d "${dataset_dir}lightning_logs" ]; then
            latest_version=$(ls -1 "${dataset_dir}lightning_logs/" | grep "version_" | sort -V | tail -1)
            if [ -n "$latest_version" ]; then
                ckpt_dir="${dataset_dir}lightning_logs/${latest_version}/checkpoints"
                if [ -d "$ckpt_dir" ]; then
                    ckpt=$(ls -1t "$ckpt_dir"/*.ckpt 2>/dev/null | head -1)
                    if [ -n "$ckpt" ]; then
                        LAST_CHECKPOINT="$ckpt"
                        DATASET_DIR=$(dirname "$(dirname "$(dirname "$ckpt_dir")")")
                    fi
                fi
            fi
        fi
    done
    
    if [ -z "$LAST_CHECKPOINT" ]; then
        echo -e "${RED}❌ No se encontró ningún checkpoint${NC}"
        echo ""
        echo "Uso: $0 <ruta_al_checkpoint.ckpt> [directorio_salida]"
        echo ""
        echo "Ejemplo:"
        echo "  $0 \$HOME/piper-training/datasets/mi_voz/lightning_logs/version_0/checkpoints/epoch=100-step=5000.ckpt"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Checkpoint encontrado:${NC}"
    echo "   $LAST_CHECKPOINT"
else
    LAST_CHECKPOINT="$1"
    # Intentar determinar el dataset desde el checkpoint
    DATASET_DIR=$(dirname "$(dirname "$(dirname "$(dirname "$LAST_CHECKPOINT")")")")
fi

# Directorio de salida
OUTPUT_DIR="${2:-$WORK_DIR/outputs}"
mkdir -p "$OUTPUT_DIR"

# Verificar que el checkpoint existe
if [ ! -f "$LAST_CHECKPOINT" ]; then
    echo -e "${RED}❌ Error: Checkpoint no encontrado: $LAST_CHECKPOINT${NC}"
    exit 1
fi

# Cambiar al directorio de piper python
PIPER_PYTHON_DIR="$WORK_DIR/piper/src/python"
export PYTHONPATH="$PIPER_PYTHON_DIR:$PYTHONPATH"

echo ""
echo -e "${BLUE}📋 Configuración de exportación:${NC}"
echo "   Checkpoint: $LAST_CHECKPOINT"
echo "   Salida: $OUTPUT_DIR/model.onnx"
echo ""

# Exportar a ONNX
echo -e "${YELLOW}🔄 Exportando a ONNX...${NC}"

python3 -m piper_train.export_onnx \
    "$LAST_CHECKPOINT" \
    "$OUTPUT_DIR/model.onnx"

if [ $? -ne 0 ]; then
    echo -e "\n${RED}❌ Error durante la exportación${NC}"
    exit 1
fi

# Copiar archivo de configuración JSON
CONFIG_SRC="$DATASET_DIR/config.json"
if [ -f "$CONFIG_SRC" ]; then
    cp "$CONFIG_SRC" "$OUTPUT_DIR/model.onnx.json"
    echo -e "${GREEN}✅ Configuración copiada${NC}"
else
    echo -e "${YELLOW}⚠️ No se encontró config.json en $DATASET_DIR${NC}"
    echo "Necesitarás proporcionar manualmente el archivo model.onnx.json"
fi

echo -e "\n${GREEN}========================================"
echo "✅ EXPORTACIÓN COMPLETADA"
echo "========================================${NC}"
echo ""
echo "Archivos generados:"
echo -e "  ${GREEN}$OUTPUT_DIR/model.onnx${NC}"
if [ -f "$OUTPUT_DIR/model.onnx.json" ]; then
    echo -e "  ${GREEN}$OUTPUT_DIR/model.onnx.json${NC}"
fi

# Mostrar tamaño de los archivos
if [ -f "$OUTPUT_DIR/model.onnx" ]; then
    SIZE=$(du -h "$OUTPUT_DIR/model.onnx" | cut -f1)
    echo ""
    echo "Tamaño del modelo: $SIZE"
fi

echo ""
echo "Para probar el modelo:"
echo -e "  ${YELLOW}echo \"Hola mundo\" | piper --model $OUTPUT_DIR/model.onnx --output_file test.wav${NC}"
echo ""
echo "Los archivos están listos para usar con Piper TTS"
