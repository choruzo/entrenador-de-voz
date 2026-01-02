#!/bin/bash
# Script de preprocesamiento de datos para Piper
# Convierte audio y texto al formato requerido para entrenamiento

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
if [ "$#" -lt 2 ]; then
    echo "Uso: $0 <directorio_dataset> <directorio_salida> [idioma]"
    echo ""
    echo "Argumentos:"
    echo "  directorio_dataset  - Ruta al dataset en formato LJSpeech"
    echo "  directorio_salida   - Donde guardar los datos procesados"
    echo "  idioma              - Código de idioma (por defecto: es-es)"
    echo ""
    echo "Ejemplo:"
    echo "  $0 mi_dataset dataset_procesado es-es"
    echo ""
    echo "Estructura esperada del dataset:"
    echo "  mi_dataset/"
    echo "  ├── wavs/"
    echo "  │   ├── audio001.wav"
    echo "  │   └── ..."
    echo "  └── metadata.csv"
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"
LANGUAGE="${3:-es-es}"

# Verificar que el directorio de entrada existe
if [ ! -d "$INPUT_DIR" ]; then
    print_error "El directorio de entrada no existe: $INPUT_DIR"
    exit 1
fi

# Verificar estructura del dataset
if [ ! -d "$INPUT_DIR/wavs" ]; then
    print_error "No se encontró el directorio 'wavs' en $INPUT_DIR"
    print_info "El dataset debe tener la estructura:"
    echo "  $INPUT_DIR/"
    echo "  ├── wavs/"
    echo "  └── metadata.csv"
    exit 1
fi

if [ ! -f "$INPUT_DIR/metadata.csv" ]; then
    print_error "No se encontró metadata.csv en $INPUT_DIR"
    exit 1
fi

# Contar archivos de audio
NUM_WAVS=$(find "$INPUT_DIR/wavs" -type f \( -name "*.wav" -o -name "*.WAV" \) | wc -l)
print_info "Archivos de audio encontrados: $NUM_WAVS"

if [ "$NUM_WAVS" -eq 0 ]; then
    print_error "No se encontraron archivos .wav en $INPUT_DIR/wavs"
    exit 1
fi

# Contar líneas en metadata.csv
NUM_LINES=$(wc -l < "$INPUT_DIR/metadata.csv")
print_info "Líneas en metadata.csv: $NUM_LINES"

if [ "$NUM_WAVS" -ne "$NUM_LINES" ]; then
    print_warning "Número de archivos WAV ($NUM_WAVS) no coincide con líneas en metadata ($NUM_LINES)"
    print_warning "Asegúrate de que cada archivo de audio tenga su entrada en metadata.csv"
fi

# Verificar que espeak-ng está instalado
if ! command -v espeak-ng &> /dev/null; then
    print_error "espeak-ng no está instalado"
    print_info "Instálalo con: sudo apt-get install espeak-ng"
    exit 1
fi

# Crear directorio de salida
mkdir -p "$OUTPUT_DIR"

print_info "Iniciando preprocesamiento..."
print_info "Dataset de entrada: $INPUT_DIR"
print_info "Dataset de salida: $OUTPUT_DIR"
print_info "Idioma: $LANGUAGE"
echo ""

# Determinar si es single-speaker o multi-speaker
# Verificar formato de metadata.csv
FIRST_LINE=$(head -n 1 "$INPUT_DIR/metadata.csv")
NUM_PIPES=$(echo "$FIRST_LINE" | tr -cd '|' | wc -c)

if [ "$NUM_PIPES" -eq 1 ]; then
    SPEAKER_TYPE="--single-speaker"
    print_info "Detectado: Dataset de un solo hablante"
elif [ "$NUM_PIPES" -eq 2 ]; then
    SPEAKER_TYPE="" # Multi-speaker es el valor por defecto
    print_info "Detectado: Dataset multi-hablante"
else
    print_error "Formato de metadata.csv no reconocido"
    print_info "Formatos válidos:"
    echo "  Single-speaker: archivo|transcripción"
    echo "  Multi-speaker:  archivo|hablante|transcripción"
    exit 1
fi

# Ejecutar preprocesamiento con Piper
print_info "Ejecutando preprocesamiento de Piper..."
echo ""

python3 -m piper_train.preprocess \
    --language "$LANGUAGE" \
    --input-dir "$INPUT_DIR" \
    --output-dir "$OUTPUT_DIR" \
    --dataset-format ljspeech \
    --sample-rate 22050 \
    $SPEAKER_TYPE

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    print_info "¡Preprocesamiento completado exitosamente!"
    print_info "Dataset procesado guardado en: $OUTPUT_DIR"
    echo ""
    
    # Mostrar estadísticas
    if [ -f "$OUTPUT_DIR/config.json" ]; then
        print_info "Archivos generados:"
        ls -lh "$OUTPUT_DIR"
        echo ""
        
        print_info "Información del dataset:"
        python3 << END
import json
try:
    with open("$OUTPUT_DIR/config.json", "r") as f:
        config = json.load(f)
    
    if "audio" in config:
        print(f"  Frecuencia de muestreo: {config['audio'].get('sample_rate', 'N/A')} Hz")
    
    if "num_speakers" in config:
        print(f"  Número de hablantes: {config['num_speakers']}")
    
    print(f"  Dataset listo para entrenamiento")
except Exception as e:
    print(f"  No se pudo leer la configuración: {e}")
END
    fi
    
    echo ""
    print_info "Siguiente paso: Entrenar el modelo"
    echo "  ./scripts/train.sh $OUTPUT_DIR modelos_base/es_ES-sharvard-medium.ckpt"
else
    echo ""
    print_error "El preprocesamiento falló con código de salida $EXIT_CODE"
    print_info "Verifica que:"
    echo "  1. El formato de metadata.csv es correcto"
    echo "  2. Los archivos de audio existen y son válidos"
    echo "  3. espeak-ng está instalado correctamente"
    exit $EXIT_CODE
fi
