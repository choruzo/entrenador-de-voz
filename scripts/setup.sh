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

# Instalar piper-phonemize desde Wheels precompilados
print_info "Instalando piper-phonemize desde release precompilado..."
PYTHON_VERSION=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')")
PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
print_info "Versión de Python detectada: $PYTHON_VERSION"

# Determinar el wheel correcto según la versión de Python
# Nota: v1.1.0 solo tiene wheels para cp39, cp310 y cp311
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
    cp312|cp313)
        # Python 3.12+ requiere renombrar el wheel para que sea compatible
        PHONEMIZE_WHEEL="piper_phonemize-1.1.0-cp311-cp311-manylinux_2_28_x86_64.whl"
        RENAMED_WHEEL="piper_phonemize-1.1.0-py3-none-any.whl"
        print_info "Adaptando wheel para $PYTHON_VERSION"
        ;;
    *)
        print_error "Versión de Python no soportada: $PYTHON_VERSION"
        print_error "Por favor usa Python 3.9, 3.10, 3.11 o 3.12"
        exit 1
        ;;
esac

print_info "Descargando $PHONEMIZE_WHEEL desde GitHub..."
PHONEMIZE_WHEEL_URL="https://github.com/rhasspy/piper-phonemize/releases/download/v1.1.0/$PHONEMIZE_WHEEL"
wget -c "$PHONEMIZE_WHEEL_URL" || {
    print_error "No se pudo descargar piper-phonemize"
    exit 1
}

if [ -n "$RENAMED_WHEEL" ]; then
    # Para Python 3.12+, renombrar el wheel como universal
    cp "$PHONEMIZE_WHEEL" "$RENAMED_WHEEL"
    pip install "$RENAMED_WHEEL" --force-reinstall
    rm "$PHONEMIZE_WHEEL" "$RENAMED_WHEEL"
else
    pip install "$PHONEMIZE_WHEEL" --force-reinstall
    rm "$PHONEMIZE_WHEEL"
fi

# Instalar Piper training y dependencias
print_info "Instalando Piper training..."
cd piper/src/python

# pytorch-lightning 1.7.x tiene metadatos inválidos con pip 25.x
# Usar versión 1.8.x que es compatible y funciona igual
print_info "Instalando dependencias compatibles..."
pip install cython
pip install "pytorch-lightning>=1.8.0,<2.0.0"
pip install librosa onnxruntime

pip install -e . --no-deps || {
    print_warning "Instalación en modo editable falló, instalando dependencias manualmente"
    pip install -r requirements.txt || print_warning "Algunas dependencias pueden faltar"
}

cd ../../..

# Instalar dependencias adicionales
print_info "Instalando dependencias adicionales..."
pip install numpy scipy librosa soundfile onnx onnxruntime

# Crear estructura de directorios
print_info "Creando estructura de directorios..."
mkdir -p datasets
mkdir -p models_base
mkdir -p checkpoints
mkdir -p outputs

# Crear archivo de variables de entorno
print_info "Creando archivo de configuración..."
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
cd ..

# Nota informativa
print_info "El modelo en_US-lessac-high se puede re-entrenar con tu dataset en español"
print_info "Esto permite aprovechar la arquitectura de alta calidad del modelo lessac"

echo ""
echo "=========================================="
print_info "¡Configuración completada!"
echo "=========================================="
echo ""
echo "Para usar el entorno, ejecuta:"
echo "  cd $WORK_DIR"
echo "  source env_setup.sh"
echo ""
echo "Luego sigue la GUIA_ENTRENAMIENTO.md para:"
echo "  1. Preparar tu dataset"
echo "  2. Preprocesar los datos"
echo "  3. Entrenar el modelo"
echo "  4. Exportar y probar"
echo ""
print_info "Directorio de trabajo: $WORK_DIR"
print_info "Guía completa: GUIA_ENTRENAMIENTO.md"
echo ""
