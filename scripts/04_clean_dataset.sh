#!/bin/bash
# 04_clean_dataset.sh
# Limpia y valida el dataset, filtrando audios muy cortos que causan errores

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORK_DIR="$HOME/piper-training"

# Verificar que estamos en el entorno virtual
if [ -z "$VIRTUAL_ENV" ]; then
    echo -e "${YELLOW}⚠️ Activando entorno virtual...${NC}"
    source "$WORK_DIR/venv/bin/activate"
fi

# Solicitar ruta del dataset si no se proporciona
if [ -z "$1" ]; then
    echo -e "${YELLOW}Uso: $0 <ruta_al_dataset>${NC}"
    echo ""
    echo "Ejemplo: $0 $WORK_DIR/datasets/mi_voz"
    echo ""
    echo "El dataset debe tener la estructura:"
    echo "  mi_voz/"
    echo "    ├── config.json"
    echo "    ├── dataset.jsonl"
    echo "    └── wavs/"
    echo "        ├── audio001.wav"
    echo "        ├── audio002.wav"
    echo "        └── ..."
    exit 1
fi

DATASET_DIR="$1"

echo "========================================"
echo "🧹 LIMPIEZA Y VALIDACIÓN DE DATASET"
echo "========================================"

# Verificar que el dataset existe
if [ ! -d "$DATASET_DIR" ]; then
    echo -e "${RED}❌ Error: El directorio $DATASET_DIR no existe${NC}"
    exit 1
fi

cd "$DATASET_DIR" || exit 1

# Verificar archivos requeridos
echo -e "\n${YELLOW}🔍 Verificando estructura del dataset...${NC}"

if [ ! -f "config.json" ]; then
    echo -e "${RED}❌ Error: config.json no encontrado${NC}"
    exit 1
fi
echo -e "${GREEN}✅ config.json${NC}"

if [ ! -f "dataset.jsonl" ]; then
    echo -e "${RED}❌ Error: dataset.jsonl no encontrado${NC}"
    exit 1
fi
echo -e "${GREEN}✅ dataset.jsonl${NC}"

if [ ! -d "wavs" ]; then
    echo -e "${RED}❌ Error: directorio wavs/ no encontrado${NC}"
    exit 1
fi
echo -e "${GREEN}✅ wavs/${NC}"

# Contar archivos
NUM_WAV=$(find wavs/ -name "*.wav" | wc -l)
echo -e "\n📊 Archivos de audio encontrados: ${NUM_WAV}"

# Ejecutar script de limpieza en Python
echo -e "\n${YELLOW}🧹 Filtrando audios muy cortos (< 1.0s)...${NC}"

python3 << 'PYEOF'
import json
import os
from pathlib import Path
import sys

try:
    import librosa
except ImportError:
    print("❌ Error: librosa no está instalado")
    sys.exit(1)

DATASET_DIR = Path(".")
JSONL_PATH = DATASET_DIR / "dataset.jsonl"
JSONL_FILTERED = DATASET_DIR / "dataset_filtered.jsonl"

print(f"🔍 Analizando {JSONL_PATH}...")

valid_lines = []
rejected = 0
MIN_DURATION = 1.0  # Segundos mínimos

if not JSONL_PATH.exists():
    print("❌ ERROR: No se encuentra dataset.jsonl")
    sys.exit(1)

with open(JSONL_PATH, 'r', encoding='utf-8') as f:
    for line in f:
        item = json.loads(line)
        audio_rel = item.get('audio_file')
        
        if not audio_rel:
            audio_id = item.get('id', item.get('audio_norm_file', ''))
            if audio_id:
                wav_path = DATASET_DIR / "wavs" / f"{audio_id}.wav"
            else:
                print(f"⚠️ Línea sin ID: {line[:50]}...")
                rejected += 1
                continue
        else:
            wav_path = DATASET_DIR / audio_rel

        if wav_path.exists():
            try:
                duration = librosa.get_duration(path=str(wav_path))
                if duration >= MIN_DURATION:
                    valid_lines.append(line)
                else:
                    print(f"⚠️ Ignorando (muy corto): {wav_path.name} ({duration:.2f}s)")
                    rejected += 1
            except Exception as e:
                print(f"⚠️ Ignorando (corrupto/error): {wav_path.name} - {e}")
                rejected += 1
        else:
            print(f"⚠️ Ignorando (no encontrado): {wav_path}")
            rejected += 1

print(f"\n✅ Muestras válidas: {len(valid_lines)}")
print(f"🗑️ Rechazadas: {rejected}")

if len(valid_lines) == 0:
    print("❌ ERROR: dataset vacío después del filtrado")
    sys.exit(1)

# Guardar dataset filtrado
with open(JSONL_FILTERED, 'w', encoding='utf-8') as f:
    f.writelines(valid_lines)

# Crear backup y reemplazar solo si hubo cambios
if rejected > 0:
    print(f"\n🔄 Reemplazando dataset.jsonl (backup creado)...")
    backup_path = DATASET_DIR / "dataset_backup.jsonl"
    if backup_path.exists():
        backup_path.unlink()
    JSONL_PATH.rename(backup_path)
    JSONL_FILTERED.rename(JSONL_PATH)
    print("✅ Dataset actualizado")
else:
    print("\n✅ Dataset ya estaba limpio, no se requieren cambios")
    JSONL_FILTERED.unlink()
PYEOF

# Mostrar estadísticas finales
echo -e "\n${GREEN}========================================"
echo "✅ LIMPIEZA COMPLETADA"
echo "========================================${NC}"

NUM_SAMPLES=$(wc -l < dataset.jsonl)
echo -e "📊 Muestras en el dataset: ${GREEN}${NUM_SAMPLES}${NC}"

# Calcular duración estimada de entrenamiento
SAMPLES_PER_EPOCH=$NUM_SAMPLES
TIME_PER_SAMPLE=0.3  # segundos en GPU T4
TIME_PER_EPOCH=$(echo "scale=1; ($SAMPLES_PER_EPOCH * $TIME_PER_SAMPLE) / 60" | bc)

echo -e "⏱️ Tiempo estimado por época: ${TIME_PER_EPOCH} minutos (GPU T4)"
echo ""
echo "Dataset listo para entrenamiento:"
echo -e "  ${GREEN}$DATASET_DIR${NC}"
echo ""
echo "Siguiente paso: Ejecutar 05_train.sh $DATASET_DIR"
