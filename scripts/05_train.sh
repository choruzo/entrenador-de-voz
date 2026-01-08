#!/bin/bash
# 05_train.sh
# Entrena el modelo de voz con Piper

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

# Solicitar ruta del dataset si no se proporciona
if [ -z "$1" ]; then
    echo -e "${YELLOW}Uso: $0 <ruta_al_dataset> [max_epochs] [batch_size]${NC}"
    echo ""
    echo "Ejemplo: $0 $WORK_DIR/datasets/mi_voz 3000 8"
    echo ""
    echo "Parámetros opcionales:"
    echo "  max_epochs  - Número máximo de épocas (default: 3000)"
    echo "  batch_size  - Tamaño del batch (default: 8)"
    exit 1
fi

DATASET_DIR="$1"
MAX_EPOCHS="${2:-3000}"
BATCH_SIZE="${3:-8}"

echo "========================================"
echo "🎯 ENTRENAMIENTO DE MODELO PIPER"
echo "========================================"

# Verificar que el dataset existe
if [ ! -d "$DATASET_DIR" ]; then
    echo -e "${RED}❌ Error: El directorio $DATASET_DIR no existe${NC}"
    exit 1
fi

# Verificar que el checkpoint base existe
CHECKPOINT_PATH="$WORK_DIR/models_base/en_US-lessac-high.ckpt"
if [ ! -f "$CHECKPOINT_PATH" ]; then
    echo -e "${RED}❌ Error: Checkpoint base no encontrado en $CHECKPOINT_PATH${NC}"
    echo "Ejecuta primero: 03_download_base_model.sh"
    exit 1
fi

# Configuración de entrenamiento
VALIDATION_SPLIT="0.05"
NUM_TEST_EXAMPLES="0"
PRECISION="32"
QUALITY="high"  # Debe coincidir con el checkpoint base
CHECKPOINT_EPOCHS="5"

# Detectar acelerador (GPU o CPU)
ACCELERATOR="cpu"
DEVICES="auto"
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        ACCELERATOR="gpu"
        DEVICES="1"
        echo -e "${GREEN}✅ GPU detectada - entrenamiento acelerado${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ GPU no detectada - entrenamiento en CPU (muy lento)${NC}"
fi

echo ""
echo -e "${BLUE}📋 Configuración de entrenamiento:${NC}"
echo "   Dataset: $DATASET_DIR"
echo "   Checkpoint base: $CHECKPOINT_PATH"
echo "   Épocas máximas: $MAX_EPOCHS"
echo "   Batch size: $BATCH_SIZE"
echo "   Acelerador: $ACCELERATOR"
echo "   Validación: ${VALIDATION_SPLIT} (${VALIDATION_SPLIT}% del dataset)"
echo "   Guardar cada: $CHECKPOINT_EPOCHS épocas"
echo "   Calidad: $QUALITY"
echo ""

# Preguntar confirmación
read -p "¿Continuar con el entrenamiento? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Entrenamiento cancelado"
    exit 0
fi

# Cambiar al directorio de piper python
PIPER_PYTHON_DIR="$WORK_DIR/piper/src/python"
export PYTHONPATH="$PIPER_PYTHON_DIR:$PYTHONPATH"

# Iniciar entrenamiento
echo -e "\n${GREEN}🚀 Iniciando entrenamiento...${NC}"
echo "Esto puede tardar varias horas dependiendo de tu hardware"
echo ""

python3 -m piper_train \
  --dataset-dir "$DATASET_DIR" \
  --batch-size "$BATCH_SIZE" \
  --validation-split "$VALIDATION_SPLIT" \
  --num-test-examples "$NUM_TEST_EXAMPLES" \
    --resume_from_single_speaker_checkpoint "$CHECKPOINT_PATH" \
  --checkpoint-epochs "$CHECKPOINT_EPOCHS" \
  --quality "$QUALITY"

# Verificar si el entrenamiento completó exitosamente
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}========================================"
    echo "✅ ENTRENAMIENTO COMPLETADO"
    echo "========================================${NC}"
    
    # Buscar el último checkpoint
    LOGS_DIR="$DATASET_DIR/lightning_logs"
    if [ -d "$LOGS_DIR" ]; then
        LATEST_VERSION=$(ls -1 "$LOGS_DIR" | grep "version_" | sort -V | tail -1)
        if [ -n "$LATEST_VERSION" ]; then
            CHECKPOINTS_DIR="$LOGS_DIR/$LATEST_VERSION/checkpoints"
            if [ -d "$CHECKPOINTS_DIR" ]; then
                LATEST_CHECKPOINT=$(ls -1t "$CHECKPOINTS_DIR"/*.ckpt 2>/dev/null | head -1)
                if [ -n "$LATEST_CHECKPOINT" ]; then
                    echo ""
                    echo "Último checkpoint guardado:"
                    echo -e "  ${GREEN}$LATEST_CHECKPOINT${NC}"
                    echo ""
                    echo "Para exportar el modelo:"
                    echo -e "  ${YELLOW}./06_export.sh \"$LATEST_CHECKPOINT\"${NC}"
                fi
            fi
        fi
    fi
else
    echo -e "\n${RED}❌ Error durante el entrenamiento${NC}"
    exit 1
fi
