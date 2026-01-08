#!/bin/bash
# Script de configuración inicial para entrenamiento de voces Piper
# Optimizado para AMD Radeon RX 6600 con ROCm
#
# NOTA: Está disponible una versión en Python compatible con Windows:
#   python scripts/setup.py
#
# Esta versión bash solo funciona en Linux.

set -e

echo "=========================================="
echo "Configuración de Entorno para Piper TTS"
echo "=========================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si estamos en Ubuntu/Debian
if ! [ -f /etc/os-release ]; then
    print_error "No se pudo detectar la distribución del sistema"
    exit 1
fi

source /etc/os-release
print_info "Sistema detectado: $PRETTY_NAME"

# Verificar si ROCm está instalado
print_info "Verificando instalación de ROCm..."
if command -v rocm-smi &> /dev/null; then
    print_info "ROCm está instalado"
    rocm-smi
else
    print_warning "ROCm no detectado. Por favor instala ROCm antes de continuar."
    print_info "Instrucciones de instalación:"
    echo "  1. Descarga el instalador desde: https://www.amd.com/en/support/linux-drivers"
    echo "  2. O sigue la guía en GUIA_ENTRENAMIENTO.md"
    echo ""
    read -p "¿Deseas continuar sin ROCm (solo CPU)? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Crear directorio de trabajo
WORK_DIR="$HOME/piper-training"
print_info "Creando directorio de trabajo en $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Crear entorno virtual de Python
print_info "Configurando entorno virtual de Python..."
if [ ! -d "venv-piper" ]; then
    python3 -m venv venv-piper
    print_info "Entorno virtual creado"
else
    print_info "Entorno virtual ya existe"
fi

# Activar entorno virtual
source venv-piper/bin/activate

# Actualizar pip
print_info "Actualizando pip..."
pip install --upgrade pip setuptools wheel

# Instalar PyTorch con soporte ROCm
print_info "Instalando PyTorch con soporte ROCm..."
if command -v rocm-smi &> /dev/null; then
    ROCM_VERSION=$(rocminfo | grep "Kernel driver version" | cut -d' ' -f4 | cut -d'.' -f1-2)
    print_info "Versión de ROCm detectada: $ROCM_VERSION"
    
    # Instalar PyTorch para ROCm 6.0 (compatible con la mayoría de versiones 6.x)
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
else
    print_warning "Instalando PyTorch para CPU solamente"
    pip install torch torchvision torchaudio
fi

# Verificar instalación de PyTorch
print_info "Verificando instalación de PyTorch..."
python3 << END
import torch
print(f"PyTorch versión: {torch.__version__}")
print(f"CUDA disponible (ROCm): {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"Dispositivo detectado: {torch.cuda.get_device_name(0)}")
    print(f"VRAM disponible: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
END

# Instalar espeak-ng
print_info "Instalando espeak-ng..."
if command -v espeak-ng &> /dev/null; then
    print_info "espeak-ng ya está instalado"
else
    if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
        sudo apt-get update
        sudo apt-get install -y espeak-ng
    else
        print_warning "Por favor instala espeak-ng manualmente para tu distribución"
    fi
fi

# Clonar repositorio de Piper
print_info "Clonando repositorio de Piper..."
if [ ! -d "piper" ]; then
    git clone https://github.com/rhasspy/piper.git
    print_info "Repositorio clonado"
else
    print_info "Repositorio ya existe"
    cd piper
    git pull
    cd ..
fi

# Instalar piper-phonemize como binario standalone
print_info "Instalando piper-phonemize binario standalone..."
PHONEMIZE_VERSION="1.2.0"
PHONEMIZE_DIR="$WORK_DIR/piper_phonemize"

if [ ! -d "$PHONEMIZE_DIR" ]; then
    print_info "Descargando piper-phonemize ${PHONEMIZE_VERSION}..."
    PHONEMIZE_URL="https://github.com/rhasspy/piper-phonemize/releases/download/2023.11.14-4/piper-phonemize_linux_x86_64.tar.gz"
    
    wget -c "$PHONEMIZE_URL" -O piper_phonemize.tar.gz || {
        print_error "No se pudo descargar piper-phonemize"
        exit 1
    }
    
    print_info "Extrayendo piper-phonemize..."
    tar -xzf piper_phonemize.tar.gz
    rm piper_phonemize.tar.gz
    
    print_info "piper-phonemize instalado en $PHONEMIZE_DIR"
else
    print_info "piper-phonemize ya está instalado en $PHONEMIZE_DIR"
fi

# Verificar instalación
if [ -f "$PHONEMIZE_DIR/bin/piper_phonemize" ]; then
    print_info "Probando piper_phonemize..."
    echo "Hola mundo" | "$PHONEMIZE_DIR/bin/piper_phonemize" -l es_ES --espeak-data "$PHONEMIZE_DIR/share/espeak-ng-data" > /dev/null 2>&1 && \
        print_info "✅ piper_phonemize funciona correctamente" || \
        print_warning "⚠️  piper_phonemize puede tener problemas"
else
    print_error "No se pudo instalar piper_phonemize correctamente"
    exit 1
fi

# Instalar también el módulo Python si es posible (para compatibilidad)
print_info "Intentando instalar módulo Python piper-phonemize..."
PYTHON_VERSION=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')")

case "$PYTHON_VERSION" in
    cp39)
        PHONEMIZE_WHEEL="piper_phonemize-1.1.0-cp39-cp39-manylinux_2_28_x86_64.whl"
        ;;
    cp310)
        PHONEMIZE_WHEEL="piper_phonemize-1.1.0-cp310-cp310-manylinux_2_28_x86_64.whl"
        ;;
    cp311)
        PHONEMIZE_WHEEL="piper_phonemize-1.1.0-cp311-cp311-manylinux_2_28_x86_64.whl"
        ;;
    *)
        print_warning "Módulo Python no disponible para $PYTHON_VERSION, usando solo binario"
        PHONEMIZE_WHEEL=""
        ;;
esac

if [ -n "$PHONEMIZE_WHEEL" ]; then
    PHONEMIZE_WHEEL_URL="https://github.com/rhasspy/piper-phonemize/releases/download/v1.1.0/$PHONEMIZE_WHEEL"
    wget -q -c "$PHONEMIZE_WHEEL_URL" && \
        pip install "$PHONEMIZE_WHEEL" --force-reinstall && \
        rm "$PHONEMIZE_WHEEL" && \
        print_info "Módulo Python instalado" || \
        print_warning "Módulo Python no instalado, se usará solo el binario"
fi

# Instalar Piper training y dependencias
print_info "Instalando Piper training..."
cd piper/src/python

# Instalar versiones específicas para compatibilidad
print_info "Instalando dependencias compatibles..."
pip install cython

# PyTorch 2.2.0 para compatibilidad con checkpoints antiguos
if ! command -v rocm-smi &> /dev/null; then
    print_info "Instalando PyTorch 2.2.0 para CPU..."
    pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 --index-url https://download.pytorch.org/whl/cpu
fi

# NumPy 1.26.x para compatibilidad con PyTorch 2.2.0
pip install "numpy>=1.26,<2.0"

# pytorch-lightning 1.9.x compatible con pip 25.x
pip install "pytorch-lightning>=1.9.0,<2.0.0"
pip install librosa onnxruntime scipy

pip install -e . --no-deps || {
    print_warning "Instalación en modo editable falló, instalando dependencias manualmente"
    pip install -r requirements.txt || print_warning "Algunas dependencias pueden faltar"
}

cd ../../..

# Instalar dependencias adicionales
print_info "Instalando dependencias adicionales..."
pip install numpy scipy librosa soundfile onnx onnxruntime

cat > env_setup.sh << 'EOF'
#!/bin/bash
# Variables de entorno para optimizar entrenamiento con AMD GPU

# Activar entorno virtual
source venv-piper/bin/activate

# Optimizaciones para ROCm (AMD Radeon RX 6600)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:512

# Variables útiles
export PIPER_TRAIN_DIR="$HOME/piper-training"
export DATASETS_DIR="$PIPER_TRAIN_DIR/datasets"
export MODELS_DIR="$PIPER_TRAIN_DIR/models_base"
export CHECKPOINTS_DIR="$PIPER_TRAIN_DIR/checkpoints"
export OUTPUTS_DIR="$PIPER_TRAIN_DIR/outputs"

# Añadir piper_phonemize al PATH
if [ -d "$PIPER_TRAIN_DIR/piper_phonemize/bin" ]; then
    export PATH="$PIPER_TRAIN_DIR/piper_phonemize/bin:$PATH"
    export LD_LIBRARY_PATH="$PIPER_TRAIN_DIR/piper_phonemize/lib:$LD_LIBRARY_PATH"
fi

echo "Entorno de Piper activado"
echo "Directorio de trabajo: $PIPER_TRAIN_DIR"

# Mostrar estado de GPU
if command -v rocm-smi &> /dev/null; then
    echo ""
    echo "Estado de GPU AMD:"
    rocm-smi --showuse --showtemp --showmeminfo vram
fi
EOF

chmod +x env_setup.sh

# Descargar modelo base en_US-lessac-high (modelo de alta calidad en inglés)
print_info "Descargando modelo base en_US-lessac-high (alta calidad)..."
print_info "Este modelo se re-entrenará con datos en español para mejor calidad"
cd models_base
if [ ! -f "en_US-lessac-high.ckpt" ]; then
    # Descargar el checkpoint desde el repositorio de checkpoints
    wget -c "https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/7bf647cb000d8c8319c6cdd4289dd6b7d0d3eeb8/en/en_US/lessac/high/epoch=2218-step=838782.ckpt" -O en_US-lessac-high.ckpt || \
        print_warning "No se pudo descargar el checkpoint. Descárgalo manualmente desde: https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/7bf647cb000d8c8319c6cdd4289dd6b7d0d3eeb8/en/en_US/lessac/high"
fi

if [ ! -f "en_US-lessac-high.onnx.json" ]; then
    # Intentar descargar la configuración
    wget -c https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx.json || \
        print_warning "No se pudo descargar la configuración. Descárgalo manualmente de Hugging Face."
fi
echo ""
echo "=========================================="
print_info "¡Configuración completada!"
echo "=========================================="
echo ""
echo "Para usar el entorno, ejecuta:"
echo "  cd $WORK_DIR"
echo "  source env_setup.sh"
echo ""
echo "Scripts disponibles:"
echo "  1. Preprocesar dataset:"
echo "     bash scripts/preprocess_dataset.sh <ruta_dataset>"
echo ""
echo "  2. Verificar dataset:"
echo "     bash scripts/verify_dataset.sh <ruta_dataset>"
echo ""
echo "  3. Entrenar modelo:"
echo "     python -m piper_train --dataset-dir <dataset> --quality high \\"
echo "       --resume_from_checkpoint models_base/en_US-lessac-high.ckpt \\"
echo "       --checkpoint-epochs 1 --max_epochs 10000"
echo ""
echo "  4. Exportar modelo:"
echo "     bash scripts/export.sh <checkpoint.ckpt> <output_dir>"
echo ""
print_info "Directorio de trabajo: $WORK_DIR"
print_info "Guía completa: GUIA_ENTRENAMIENTO.md"
print_info "Scripts en: $(dirname $0)/"
echo "" 2. Preprocesar los datos"
echo "  3. Entrenar el modelo"
echo "  4. Exportar y probar"
echo ""
print_info "Directorio de trabajo: $WORK_DIR"
print_info "Guía completa: GUIA_ENTRENAMIENTO.md"
echo ""
