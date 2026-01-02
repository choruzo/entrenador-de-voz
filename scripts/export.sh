#!/bin/bash
# Script de exportación de modelo Piper a formato ONNX
#
# NOTA: Está disponible una versión en Python compatible con Windows:
#   python scripts/export.py <checkpoint> <archivo_salida.onnx>
#
# Esta versión bash solo funciona en Linux.

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
    echo "Uso: $0 <checkpoint> <archivo_salida.onnx>"
    echo ""
    echo "Argumentos:"
    echo "  checkpoint        - Archivo .ckpt del modelo entrenado"
    echo "  archivo_salida    - Nombre del archivo ONNX de salida"
    echo ""
    echo "Ejemplo:"
    echo "  $0 checkpoints/modelo-epoch-8000.ckpt mi_voz_es.onnx"
    exit 1
fi

CHECKPOINT="$1"
OUTPUT_FILE="$2"

# Verificar que el checkpoint existe
if [ ! -f "$CHECKPOINT" ]; then
    print_error "Checkpoint no encontrado: $CHECKPOINT"
    exit 1
fi

# Verificar extensión del archivo de salida
if [[ ! "$OUTPUT_FILE" =~ \.onnx$ ]]; then
    print_warning "El archivo de salida debería tener extensión .onnx"
    OUTPUT_FILE="${OUTPUT_FILE}.onnx"
    print_info "Usando nombre de archivo: $OUTPUT_FILE"
fi

# Directorio de salida
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

print_info "Exportando modelo a ONNX..."
print_info "Checkpoint: $CHECKPOINT"
print_info "Salida: $OUTPUT_FILE"
echo ""

# Exportar modelo
python3 -m piper_train.export_onnx \
    --checkpoint "$CHECKPOINT" \
    --output "$OUTPUT_FILE"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    print_info "¡Modelo exportado exitosamente!"
    
    # Mostrar información del archivo
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        print_info "Tamaño del modelo: $FILE_SIZE"
        
        # Buscar archivo de configuración JSON asociado
        JSON_FILE="${OUTPUT_FILE}.json"
        if [ -f "$JSON_FILE" ]; then
            print_info "Archivo de configuración: $JSON_FILE"
        fi
    fi
    
    echo ""
    print_info "Ahora puedes usar tu modelo con Piper:"
    echo ""
    echo "  # Instalar Piper (si no lo tienes)"
    echo "  pip install piper-tts"
    echo ""
    echo "  # Generar audio de prueba"
    echo "  echo 'Hola, esta es mi voz personalizada.' | \\"
    echo "    piper --model $OUTPUT_FILE --output_file prueba.wav"
    echo ""
    echo "  # Reproducir audio"
    echo "  aplay prueba.wav  # Linux"
    echo "  ffplay prueba.wav # Con FFmpeg"
    echo ""
    
    # Crear script de prueba
    TEST_SCRIPT="${OUTPUT_DIR}/test_model.sh"
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
# Script de prueba para el modelo exportado

MODEL_FILE="$OUTPUT_FILE"

if [ ! -f "\$MODEL_FILE" ]; then
    echo "Error: Modelo no encontrado"
    exit 1
fi

# Texto de prueba
TEXT=\${1:-"Hola, soy una voz sintética entrenada con Piper. Este es un mensaje de prueba."}

echo "Generando audio de prueba..."
echo "\$TEXT" | piper --model "\$MODEL_FILE" --output_file prueba.wav

if [ -f "prueba.wav" ]; then
    echo "Audio generado: prueba.wav"
    echo "Reproduciendo..."
    
    if command -v aplay &> /dev/null; then
        aplay prueba.wav
    elif command -v ffplay &> /dev/null; then
        ffplay -autoexit -nodisp prueba.wav
    else
        echo "Instala 'aplay' o 'ffplay' para reproducir el audio"
    fi
else
    echo "Error al generar audio"
    exit 1
fi
EOF
    
    chmod +x "$TEST_SCRIPT"
    print_info "Script de prueba creado: $TEST_SCRIPT"
    echo ""
    echo "  Para probar el modelo: $TEST_SCRIPT"
    echo "  O con tu propio texto: $TEST_SCRIPT \"Tu texto aquí\""
    
else
    echo ""
    print_error "La exportación falló con código de salida $EXIT_CODE"
    print_info "Verifica que:"
    echo "  1. El checkpoint es válido"
    echo "  2. Tienes suficiente espacio en disco"
    echo "  3. piper_train está instalado correctamente"
    exit $EXIT_CODE
fi
