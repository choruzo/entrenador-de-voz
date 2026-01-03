#!/bin/bash
# Script para preprocesar dataset para entrenamiento de Piper
# Genera phoneme_ids, espectrogramas lineales y audio normalizado

set -e

# Colores para output
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

# Verificar argumentos
if [ $# -lt 1 ]; then
    echo "Uso: $0 <ruta_dataset> [sample_rate]"
    echo ""
    echo "Argumentos:"
    echo "  ruta_dataset  : Ruta al directorio del dataset (ej: ~/piper-training/datasets/sig)"
    echo "  sample_rate   : Frecuencia de muestreo (default: 22050)"
    echo ""
    echo "Estructura esperada del dataset:"
    echo "  dataset/"
    echo "    ├── metadata.csv  (formato: wavs/archivo.wav|Texto transcrito)"
    echo "    ├── wavs/"
    echo "    │   ├── archivo001.wav"
    echo "    │   └── ..."
    echo "    └── config.json   (configuración del dataset)"
    exit 1
fi

DATASET_DIR="$1"
SAMPLE_RATE="${2:-22050}"

# Verificar que el dataset existe
if [ ! -d "$DATASET_DIR" ]; then
    print_error "El directorio del dataset no existe: $DATASET_DIR"
    exit 1
fi

if [ ! -f "$DATASET_DIR/metadata.csv" ]; then
    print_error "No se encontró metadata.csv en $DATASET_DIR"
    exit 1
fi

if [ ! -d "$DATASET_DIR/wavs" ]; then
    print_error "No se encontró el directorio wavs/ en $DATASET_DIR"
    exit 1
fi

# Verificar que piper_phonemize está disponible
PHONEMIZE_BIN=""
if command -v piper_phonemize &> /dev/null; then
    PHONEMIZE_BIN="piper_phonemize"
    print_info "piper_phonemize encontrado en PATH"
elif [ -f "$HOME/piper-training/piper_phonemize/bin/piper_phonemize" ]; then
    PHONEMIZE_BIN="$HOME/piper-training/piper_phonemize/bin/piper_phonemize"
    print_info "piper_phonemize encontrado en $PHONEMIZE_BIN"
else
    print_error "piper_phonemize no encontrado"
    print_error "Por favor ejecuta setup.sh primero"
    exit 1
fi

# Verificar entorno virtual
if [ -z "$VIRTUAL_ENV" ]; then
    print_warning "No se detectó entorno virtual activo"
    if [ -f "$HOME/piper-training/venv-piper/bin/activate" ]; then
        print_info "Activando entorno virtual..."
        source "$HOME/piper-training/venv-piper/bin/activate"
    else
        print_error "Entorno virtual no encontrado. Ejecuta setup.sh primero"
        exit 1
    fi
fi

# Verificar que Python tiene los módulos necesarios
python3 -c "import torch, torchaudio, json" 2>/dev/null || {
    print_error "Faltan módulos de Python requeridos (torch, torchaudio)"
    print_error "Por favor ejecuta setup.sh primero"
    exit 1
}

cd "$DATASET_DIR"

print_info "=========================================="
print_info "Preprocesando dataset: $DATASET_DIR"
print_info "Sample rate: $SAMPLE_RATE Hz"
print_info "=========================================="
echo ""

# Crear directorios necesarios
print_info "Creando directorios de trabajo..."
mkdir -p spec audio_norm

# Ejecutar script de Python para preprocesamiento
print_info "Generando phoneme_ids, espectrogramas y audio normalizado..."
python3 << 'PYTHON_SCRIPT'
import json
import sys
import subprocess
from pathlib import Path
import torch
import torchaudio
from tqdm import tqdm

# Configuración
dataset_dir = Path(".")
metadata_file = dataset_dir / "metadata.csv"
output_file = dataset_dir / "dataset.jsonl"
spec_dir = dataset_dir / "spec"
audio_norm_dir = dataset_dir / "audio_norm"

# Leer configuración
config_file = dataset_dir / "config.json"
if config_file.exists():
    with open(config_file, 'r') as f:
        config = json.load(f)
    sample_rate = config.get('audio', {}).get('sample_rate', 22050)
else:
    sample_rate = int(sys.argv[1]) if len(sys.argv) > 1 else 22050

# Configuración de espectrogramas (debe coincidir con el modelo)
n_fft = 1024
hop_length = 256
n_freq_bins = n_fft // 2 + 1  # 513 para n_fft=1024

print(f"📋 Configuración:")
print(f"   Sample rate: {sample_rate} Hz")
print(f"   n_fft: {n_fft} → {n_freq_bins} frequency bins")
print(f"   hop_length: {hop_length}")
print()

# Leer metadata.csv
print("📖 Leyendo metadata.csv...")
entries = []
with open(metadata_file, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('|', 1)
        if len(parts) == 2:
            audio_file, text = parts
            entries.append({
                'audio_file': audio_file,
                'text': text
            })

print(f"✅ {len(entries)} entradas encontradas")
print()

# Fonetizar textos
print("🗣️  Generando phoneme_ids...")
phonemize_bin = None
if Path("/usr/local/bin/piper_phonemize").exists():
    phonemize_bin = "/usr/local/bin/piper_phonemize"
elif Path.home().joinpath("piper-training/piper_phonemize/bin/piper_phonemize").exists():
    phonemize_bin = str(Path.home() / "piper-training/piper_phonemize/bin/piper_phonemize")

if not phonemize_bin:
    print("❌ Error: piper_phonemize no encontrado")
    sys.exit(1)

for entry in tqdm(entries, desc="Fonetizando"):
    text = entry['text']
    try:
        result = subprocess.run(
            [phonemize_bin, '-l', 'es_ES', '--espeak-data', str(Path.home() / 'piper-training/piper_phonemize/share/espeak-ng-data')],
            input=text,
            text=True,
            capture_output=True,
            check=True
        )
        phoneme_ids_str = result.stdout.strip()
        phoneme_ids = [int(x) for x in phoneme_ids_str.split()]
        entry['phoneme_ids'] = phoneme_ids
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error fonetizando: {text}")
        print(f"   Error: {e.stderr}")
        sys.exit(1)

print(f"✅ Phoneme_ids generados para {len(entries)} entradas")
print()

# Generar espectrogramas lineales
print("📊 Generando espectrogramas lineales...")
spec_transform = torchaudio.transforms.Spectrogram(
    n_fft=n_fft,
    hop_length=hop_length,
    power=1  # magnitud, no power
)

for entry in tqdm(entries, desc="Espectrogramas"):
    audio_file = dataset_dir / entry['audio_file']
    audio_name = audio_file.stem
    spec_file = spec_dir / f"{audio_name}.pt"
    
    # Cargar audio
    waveform, sr = torchaudio.load(audio_file)
    
    # Resample si necesario
    if sr != sample_rate:
        resampler = torchaudio.transforms.Resample(sr, sample_rate)
        waveform = resampler(waveform)
    
    # Convertir a mono
    if waveform.shape[0] > 1:
        waveform = torch.mean(waveform, dim=0, keepdim=True)
    
    # Generar espectrograma lineal
    spec = spec_transform(waveform)
    
    # Aplicar log scale
    spec = torch.log(torch.clamp(spec, min=1e-5))
    
    # Squeeze: (1, freq, time) -> (freq, time)
    spec = spec.squeeze(0)
    
    # Verificar shape
    if spec.shape[0] != n_freq_bins:
        print(f"\n❌ Error: espectrograma con shape incorrecta: {spec.shape}")
        sys.exit(1)
    
    # Guardar
    torch.save(spec, spec_file)
    
    # Actualizar entry con path relativo desde dataset_dir
    entry['audio_spec_path'] = f"spec/{audio_name}.pt"

print(f"✅ {len(entries)} espectrogramas generados")
print()

# Generar audio normalizado
print("🔊 Generando audio normalizado...")
for entry in tqdm(entries, desc="Audio norm"):
    audio_file = dataset_dir / entry['audio_file']
    audio_name = audio_file.stem
    norm_file = audio_norm_dir / f"{audio_name}.pt"
    
    # Cargar audio
    waveform, sr = torchaudio.load(audio_file)
    
    # Resample si necesario
    if sr != sample_rate:
        resampler = torchaudio.transforms.Resample(sr, sample_rate)
        waveform = resampler(waveform)
    
    # Convertir a mono
    if waveform.shape[0] > 1:
        waveform = torch.mean(waveform, dim=0, keepdim=True)
    
    # Si es 1D, agregar dimensión de canal
    if waveform.dim() == 1:
        waveform = waveform.unsqueeze(0)
    
    # Normalizar a rango [-1, 1]
    if waveform.abs().max() > 0:
        waveform = waveform / waveform.abs().max()
    
    # Verificar shape: debe ser (1, length)
    if waveform.dim() != 2 or waveform.shape[0] != 1:
        print(f"\n❌ Error: audio_norm con shape incorrecta: {waveform.shape}")
        sys.exit(1)
    
    # Guardar
    torch.save(waveform, norm_file)
    
    # Actualizar entry con path relativo desde dataset_dir
    entry['audio_norm_path'] = f"audio_norm/{audio_name}.pt"

print(f"✅ {len(entries)} audios normalizados")
print()

# Guardar dataset.jsonl
print("💾 Guardando dataset.jsonl...")
with open(output_file, 'w', encoding='utf-8') as f:
    for entry in entries:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')

print(f"✅ dataset.jsonl creado con {len(entries)} entradas")
print()

# Verificar un ejemplo
print("🔍 Verificación de ejemplo:")
test_entry = entries[0]
print(f"   Audio: {test_entry['audio_file']}")
print(f"   Texto: {test_entry['text']}")
print(f"   Phoneme IDs: {len(test_entry['phoneme_ids'])} tokens")
print(f"   Audio norm path: {test_entry['audio_norm_path']}")
print(f"   Audio spec path: {test_entry['audio_spec_path']}")

# Verificar archivos
spec_file = dataset_dir / test_entry['audio_spec_path']
norm_file = dataset_dir / test_entry['audio_norm_path']
test_spec = torch.load(spec_file)
test_norm = torch.load(norm_file)
print(f"   Spec shape: {test_spec.shape} (debe ser ({n_freq_bins}, tiempo))")
print(f"   Norm shape: {test_norm.shape} (debe ser (1, length))")
print()

print("=" * 50)
print("✅ ¡PREPROCESAMIENTO COMPLETADO!")
print("=" * 50)
print()
print(f"Dataset listo en: {dataset_dir}")
print(f"Total de muestras: {len(entries)}")
print()
print("Siguiente paso:")
print("  python -m piper_train --dataset-dir {} ...".format(dataset_dir))
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    print_info "=========================================="
    print_info "✅ Preprocesamiento completado exitosamente"
    print_info "=========================================="
    echo ""
    print_info "Archivos generados:"
    echo "  - dataset.jsonl: $(wc -l < dataset.jsonl) entradas"
    echo "  - spec/: $(ls spec/*.pt 2>/dev/null | wc -l) espectrogramas"
    echo "  - audio_norm/: $(ls audio_norm/*.pt 2>/dev/null | wc -l) audios normalizados"
    echo ""
    print_info "Dataset listo para entrenamiento!"
else
    print_error "Error durante el preprocesamiento"
    exit 1
fi
