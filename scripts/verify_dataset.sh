#!/bin/bash
# Script para verificar que un dataset está correctamente preprocesado

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

if [ $# -lt 1 ]; then
    echo "Uso: $0 <ruta_dataset>"
    echo ""
    echo "Verifica que el dataset esté correctamente preprocesado para Piper"
    exit 1
fi

DATASET_DIR="$1"

if [ ! -d "$DATASET_DIR" ]; then
    print_error "El directorio no existe: $DATASET_DIR"
    exit 1
fi

print_info "=========================================="
print_info "Verificando dataset: $DATASET_DIR"
print_info "=========================================="
echo ""

ERRORS=0

# Verificar estructura básica
print_info "Verificando estructura de directorios..."
for dir in wavs spec audio_norm; do
    if [ -d "$DATASET_DIR/$dir" ]; then
        echo "  ✅ $dir/"
    else
        echo "  ❌ $dir/ - NO ENCONTRADO"
        ERRORS=$((ERRORS + 1))
    fi
done

# Verificar archivos requeridos
print_info "Verificando archivos requeridos..."
for file in metadata.csv dataset.jsonl config.json; do
    if [ -f "$DATASET_DIR/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file - NO ENCONTRADO"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Verificar dataset.jsonl con Python
if [ -f "$DATASET_DIR/dataset.jsonl" ]; then
    print_info "Verificando contenido de dataset.jsonl..."
    
    # Activar entorno virtual si no está activo
    if [ -z "$VIRTUAL_ENV" ]; then
        if [ -f "$HOME/piper-training/venv-piper/bin/activate" ]; then
            source "$HOME/piper-training/venv-piper/bin/activate"
        fi
    fi
    
    python3 << PYTHON_SCRIPT
import json
import sys
from pathlib import Path

dataset_dir = Path("$DATASET_DIR")
jsonl_file = dataset_dir / "dataset.jsonl"

errors = 0
warnings = 0

# Leer todas las entradas
entries = []
with open(jsonl_file, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f, 1):
        try:
            entry = json.loads(line)
            entries.append(entry)
        except json.JSONDecodeError as e:
            print(f"  ❌ Línea {i}: JSON inválido - {e}")
            errors += 1

print(f"  Total de entradas: {len(entries)}")

# Verificar campos requeridos
required_fields = ['audio_file', 'text', 'phoneme_ids', 'audio_norm_path', 'audio_spec_path']
for i, entry in enumerate(entries[:10], 1):  # Verificar primeras 10
    missing = [f for f in required_fields if f not in entry]
    if missing:
        print(f"  ❌ Entrada {i}: faltan campos: {missing}")
        errors += 1

if entries:
    # Verificar que los archivos existen
    print("\n  Verificando archivos referenciados...")
    sample_entry = entries[0]
    
    for field in ['audio_norm_path', 'audio_spec_path']:
        if field in sample_entry:
            file_path = dataset_dir / sample_entry[field]
            if file_path.exists():
                print(f"  ✅ {field}: {sample_entry[field]}")
            else:
                print(f"  ❌ {field}: archivo no existe - {sample_entry[field]}")
                errors += 1
    
    # Verificar phoneme_ids
    if 'phoneme_ids' in sample_entry:
        phoneme_ids = sample_entry['phoneme_ids']
        if isinstance(phoneme_ids, list) and len(phoneme_ids) > 0:
            print(f"  ✅ phoneme_ids: {len(phoneme_ids)} tokens")
        else:
            print(f"  ❌ phoneme_ids: formato inválido")
            errors += 1

sys.exit(errors)
PYTHON_SCRIPT
    
    if [ $? -eq 0 ]; then
        echo "  ✅ dataset.jsonl válido"
    else
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Verificar configuración
if [ -f "$DATASET_DIR/config.json" ]; then
    print_info "Verificando config.json..."
    python3 << PYTHON_SCRIPT
import json
from pathlib import Path

config_file = Path("$DATASET_DIR/config.json")
with open(config_file, 'r') as f:
    config = json.load(f)

required = ['audio', 'espeak', 'inference']
for key in required:
    if key in config:
        print(f"  ✅ {key}: presente")
    else:
        print(f"  ⚠️  {key}: no encontrado")

# Mostrar configuración importante
if 'audio' in config:
    sample_rate = config['audio'].get('sample_rate', 'N/A')
    print(f"  Sample rate: {sample_rate} Hz")

if 'espeak' in config:
    voice = config['espeak'].get('voice', 'N/A')
    print(f"  Voice: {voice}")
PYTHON_SCRIPT
fi
echo ""

# Contar archivos
print_info "Estadísticas del dataset..."
if [ -d "$DATASET_DIR/wavs" ]; then
    WAV_COUNT=$(find "$DATASET_DIR/wavs" -name "*.wav" 2>/dev/null | wc -l)
    echo "  Archivos WAV: $WAV_COUNT"
fi

if [ -d "$DATASET_DIR/spec" ]; then
    SPEC_COUNT=$(find "$DATASET_DIR/spec" -name "*.pt" 2>/dev/null | wc -l)
    echo "  Espectrogramas: $SPEC_COUNT"
fi

if [ -d "$DATASET_DIR/audio_norm" ]; then
    NORM_COUNT=$(find "$DATASET_DIR/audio_norm" -name "*.pt" 2>/dev/null | wc -l)
    echo "  Audios normalizados: $NORM_COUNT"
fi

if [ -f "$DATASET_DIR/dataset.jsonl" ]; then
    JSONL_COUNT=$(wc -l < "$DATASET_DIR/dataset.jsonl")
    echo "  Entradas en dataset.jsonl: $JSONL_COUNT"
fi
echo ""

# Verificar que los conteos coinciden
if [ ! -z "$WAV_COUNT" ] && [ ! -z "$SPEC_COUNT" ] && [ ! -z "$NORM_COUNT" ] && [ ! -z "$JSONL_COUNT" ]; then
    if [ "$WAV_COUNT" -eq "$SPEC_COUNT" ] && [ "$SPEC_COUNT" -eq "$NORM_COUNT" ] && [ "$NORM_COUNT" -eq "$JSONL_COUNT" ]; then
        echo "  ✅ Todos los conteos coinciden ($WAV_COUNT archivos)"
    else
        print_warning "Los conteos no coinciden:"
        echo "    WAV: $WAV_COUNT, Spec: $SPEC_COUNT, Norm: $NORM_COUNT, JSONL: $JSONL_COUNT"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Resultado final
print_info "=========================================="
if [ $ERRORS -eq 0 ]; then
    print_info "✅ DATASET VÁLIDO"
    print_info "=========================================="
    echo ""
    print_info "El dataset está listo para entrenamiento"
    exit 0
else
    print_error "❌ DATASET CON ERRORES ($ERRORS encontrados)"
    print_info "=========================================="
    echo ""
    print_error "Por favor corrige los errores antes de entrenar"
    exit 1
fi
