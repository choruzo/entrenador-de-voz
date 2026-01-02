#!/bin/bash
# Script de entrenamiento para Piper TTS
# Optimizado para AMD Radeon RX 6600 (8GB VRAM)

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar argumentos
if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <directorio_dataset_procesado> [checkpoint_base] [opciones]"
    echo ""
    echo "Argumentos:"
    echo "  directorio_dataset_procesado - Dataset preprocesado"
    echo "  checkpoint_base              - (Opcional) Checkpoint del modelo base para transfer learning"
    echo ""
    echo "Opciones de entorno:"
    echo "  BATCH_SIZE      - Tamaño del batch (por defecto: 8)"
    echo "  MAX_EPOCHS      - Número máximo de épocas (por defecto: 10000)"
    echo "  LEARNING_RATE   - Tasa de aprendizaje (por defecto: 1e-4)"
    echo "  QUALITY         - Calidad del modelo: x_low, low, medium, high (por defecto: medium)"
    echo ""
    echo "Ejemplo:"
    echo "  $0 dataset_procesado modelos_base/es_ES-sharvard-medium.ckpt"
    echo "  BATCH_SIZE=4 $0 dataset_procesado"
    exit 1
fi

DATASET_DIR="$1"
CHECKPOINT_BASE="${2:-}"

# Verificar que el dataset existe
if [ ! -d "$DATASET_DIR" ]; then
    print_error "El directorio del dataset no existe: $DATASET_DIR"
    exit 1
fi

if [ ! -f "$DATASET_DIR/config.json" ]; then
    print_error "No se encontró config.json en $DATASET_DIR"
    print_info "Ejecuta primero el preprocesamiento: ./scripts/preprocess.sh"
    exit 1
fi

# Parámetros de entrenamiento (pueden ser sobrescritos con variables de entorno)
BATCH_SIZE="${BATCH_SIZE:-8}"
MAX_EPOCHS="${MAX_EPOCHS:-10000}"
CHECKPOINT_EPOCHS="${CHECKPOINT_EPOCHS:-1000}"
LEARNING_RATE="${LEARNING_RATE:-1e-4}"
VALIDATION_SPLIT="${VALIDATION_SPLIT:-0.05}"
NUM_TEST_EXAMPLES="${NUM_TEST_EXAMPLES:-5}"
QUALITY="${QUALITY:-medium}"
PRECISION="${PRECISION:-16-mixed}"

# Directorio de checkpoints
CHECKPOINT_DIR="${CHECKPOINTS_DIR:-./checkpoints}"
mkdir -p "$CHECKPOINT_DIR"

# Variables de entorno para optimizar ROCm (AMD GPU)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:512

print_info "Configuración de entrenamiento:"
echo "  Dataset: $DATASET_DIR"
echo "  Batch size: $BATCH_SIZE"
echo "  Épocas máximas: $MAX_EPOCHS"
echo "  Tasa de aprendizaje: $LEARNING_RATE"
echo "  Calidad: $QUALITY"
echo "  Precisión: $PRECISION"
echo "  Validación: ${VALIDATION_SPLIT}%"

if [ -n "$CHECKPOINT_BASE" ]; then
    if [ ! -f "$CHECKPOINT_BASE" ]; then
        print_error "Checkpoint base no encontrado: $CHECKPOINT_BASE"
        exit 1
    fi
    print_info "Transfer learning desde: $CHECKPOINT_BASE"
    RESUME_FLAG="--resume-from-checkpoint $CHECKPOINT_BASE"
else
    print_warning "Entrenando desde cero (sin transfer learning)"
    print_info "Recomendación: Usa un modelo base para mejores resultados"
    RESUME_FLAG=""
fi

echo ""

# Verificar GPU
print_info "Verificando GPU disponible..."
python3 << END
import torch
if torch.cuda.is_available():
    print(f"GPU detectada: {torch.cuda.get_device_name(0)}")
    total_mem = torch.cuda.get_device_properties(0).total_memory / 1024**3
    print(f"VRAM total: {total_mem:.2f} GB")
    if total_mem < 6:
        print("ADVERTENCIA: GPU con menos de 6GB VRAM. Considera reducir batch_size")
else:
    print("No se detectó GPU. Entrenamiento usará CPU (será muy lento)")
    print("Asegúrate de tener ROCm instalado y PyTorch compilado con soporte ROCm")
END

echo ""
read -p "¿Continuar con el entrenamiento? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    print_info "Entrenamiento cancelado"
    exit 0
fi

# Crear script de monitoreo en segundo plano
cat > "$CHECKPOINT_DIR/monitor.sh" << 'MONITOR_EOF'
#!/bin/bash
while true; do
    clear
    echo "========== Monitor de Entrenamiento Piper =========="
    echo ""
    if command -v rocm-smi &> /dev/null; then
        echo "Estado de GPU:"
        rocm-smi --showuse --showtemp --showmeminfo vram | head -20
        echo ""
    fi
    echo "Últimas líneas del log de entrenamiento:"
    if [ -f "training.log" ]; then
        tail -15 training.log
    else
        echo "Esperando inicio del entrenamiento..."
    fi
    echo ""
    echo "Presiona Ctrl+C para salir del monitor"
    echo "El entrenamiento continúa en background"
    sleep 5
done
MONITOR_EOF

chmod +x "$CHECKPOINT_DIR/monitor.sh"

print_info "Iniciando entrenamiento..."
print_info "Los checkpoints se guardarán en: $CHECKPOINT_DIR"
print_info "Para monitorear GPU: watch -n 2 rocm-smi"
print_info "Para ver progreso: tail -f $CHECKPOINT_DIR/training.log"
echo ""

# Ejecutar entrenamiento
python3 -m piper_train \
    --dataset-dir "$DATASET_DIR" \
    --accelerator gpu \
    --devices 1 \
    --batch-size "$BATCH_SIZE" \
    --validation-split "$VALIDATION_SPLIT" \
    --num-test-examples "$NUM_TEST_EXAMPLES" \
    --max_epochs "$MAX_EPOCHS" \
    --checkpoint-epochs "$CHECKPOINT_EPOCHS" \
    --precision "$PRECISION" \
    --quality "$QUALITY" \
    --learning-rate "$LEARNING_RATE" \
    $RESUME_FLAG \
    2>&1 | tee "$CHECKPOINT_DIR/training.log"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    print_info "¡Entrenamiento completado!"
    
    # Buscar el último checkpoint
    LAST_CHECKPOINT=$(ls -t "$CHECKPOINT_DIR"/*.ckpt 2>/dev/null | head -1)
    
    if [ -n "$LAST_CHECKPOINT" ]; then
        print_info "Último checkpoint: $LAST_CHECKPOINT"
        echo ""
        print_info "Siguiente paso: Exportar el modelo"
        echo "  ./scripts/export.sh $LAST_CHECKPOINT mi_modelo.onnx"
    else
        print_warning "No se encontraron checkpoints guardados"
    fi
else
    echo ""
    print_error "El entrenamiento falló con código de salida $EXIT_CODE"
    print_info "Revisa el log en: $CHECKPOINT_DIR/training.log"
    
    if [ $EXIT_CODE -eq 137 ]; then
        print_error "Error 137: Out of Memory (OOM)"
        print_info "Soluciones:"
        echo "  1. Reduce el batch size: BATCH_SIZE=4 $0 $@"
        echo "  2. Cierra otras aplicaciones que usen GPU"
        echo "  3. Reduce la resolución/calidad del modelo"
    fi
    
    exit $EXIT_CODE
fi
