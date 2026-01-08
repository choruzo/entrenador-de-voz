#!/bin/bash
# 02_install_piper.sh
# Instala Piper, piper-phonemize y todas las dependencias Python necesarias

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK_DIR="$HOME/piper-training"
cd "$WORK_DIR" || exit 1

echo "========================================"
echo "📦 INSTALACIÓN DE PIPER Y DEPENDENCIAS"
echo "========================================"

# Verificar versión de Python
echo -e "\n${YELLOW}🐍 Verificando versión de Python...${NC}"
PYTHON_CMD="python3.10"
if ! command -v python3.10 &> /dev/null; then
    echo -e "${YELLOW}⚠️ Python 3.10 no encontrado, usando python3 por defecto${NC}"
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [[ "$PYTHON_VERSION" != "3.10" ]]; then
        echo -e "${RED}⚠️ ADVERTENCIA: Tienes Python $PYTHON_VERSION${NC}"
        echo -e "${YELLOW}   Se recomienda Python 3.10 para mejor compatibilidad${NC}"
        echo -e "${YELLOW}   Instálalo con: sudo apt install python3.10 python3.10-venv${NC}"
        echo ""
        read -p "¿Continuar de todos modos? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 0
        fi
    fi
else
    echo -e "${GREEN}✅ Python 3.10 encontrado${NC}"
fi

# Crear entorno virtual Python
echo -e "\n${YELLOW}🐍 Creando entorno virtual Python...${NC}"
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
    echo -e "${GREEN}✅ Entorno virtual creado${NC}"
else
    echo -e "${GREEN}✅ Entorno virtual ya existe${NC}"
fi

# Activar entorno virtual
source venv/bin/activate

# Actualizar pip (mantener <24.1 por compatibilidad con metadatos antiguos de pytorch-lightning 1.7.7)
echo -e "\n${YELLOW}🔧 Actualizando pip...${NC}"
pip install "pip<24.1" setuptools wheel

# Descargar piper-phonemize
echo -e "\n${YELLOW}📥 Descargando piper-phonemize...${NC}"
if [ ! -d "piper_phonemize" ]; then
    wget --show-progress \
        https://github.com/rhasspy/piper-phonemize/releases/download/2023.11.14-4/piper-phonemize_linux_x86_64.tar.gz \
        || { echo -e "${RED}❌ Error descargando piper-phonemize${NC}"; exit 1; }

    tar -xzf piper-phonemize_linux_x86_64.tar.gz \
        || { echo -e "${RED}❌ Error descomprimiendo piper-phonemize${NC}"; exit 1; }

    rm piper-phonemize_linux_x86_64.tar.gz
    echo -e "${GREEN}✅ piper-phonemize instalado${NC}"
    ls -la piper_phonemize/ | head -10
else
    echo -e "${GREEN}✅ piper-phonemize ya existe${NC}"
fi

# Configurar LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$WORK_DIR/piper_phonemize/lib:$LD_LIBRARY_PATH"
echo "export LD_LIBRARY_PATH=\"$WORK_DIR/piper_phonemize/lib:\$LD_LIBRARY_PATH\"" >> venv/bin/activate

# Clonar Piper
echo -e "\n${YELLOW}📥 Clonando repositorio Piper...${NC}"
if [ ! -d "piper" ]; then
    git clone https://github.com/rhasspy/piper.git
    echo -e "${GREEN}✅ Piper clonado${NC}"
else
    echo -e "${GREEN}✅ Piper ya existe${NC}"
fi

PIPER_PYTHON_DIR="$WORK_DIR/piper/src/python"

if [ ! -d "$PIPER_PYTHON_DIR" ]; then
    echo -e "${RED}❌ ERROR: piper/src/python no existe${NC}"
    exit 1
fi

# Instalar dependencias Python
echo -e "\n${YELLOW}📦 Instalando dependencias Python...${NC}"

# Detectar si hay GPU NVIDIA
HAS_GPU=false
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null 2>&1; then
        HAS_GPU=true
        echo -e "${GREEN}✅ GPU NVIDIA detectada - instalando PyTorch con CUDA${NC}"
    fi
fi

# Instalar PyTorch con soporte CUDA si hay GPU, sino versión CPU
if [ "$HAS_GPU" = true ]; then
    # Verificar compute capability de la GPU
    COMPUTE_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
    echo -e "${GREEN}   Compute Capability: sm_$COMPUTE_CAP${NC}"
    
    # RTX 5060 Ti es Blackwell (sm_120), necesita PyTorch 2.6+ o nightly
        if [ "$COMPUTE_CAP" -ge 120 ]; then
                echo -e "${YELLOW}   GPU Blackwell detectada (sm_$COMPUTE_CAP)${NC}"
                echo -e "${YELLOW}   Construyendo PyTorch desde fuente para sm_120...${NC}"
                bash "$SCRIPT_DIR/02b_build_torch_from_source.sh"
    else
        echo -e "${YELLOW}   Instalando PyTorch 2.5.1 con CUDA 12.4...${NC}"
        pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu124
    fi
else
    echo -e "${YELLOW}⚠️ No se detectó GPU - instalando PyTorch para CPU${NC}"
    pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cpu
fi

# Usar pytorch-lightning 1.9.5 (API compatible con CLI actual de Piper)
echo -e "${YELLOW}   Instalando PyTorch Lightning 1.9.5...${NC}"
pip install "pytorch-lightning==1.9.5" "torchmetrics==0.11.4"
# piper-phonemize se instala como binario (descargado arriba), no desde PyPI
pip install librosa
pip install "numpy<2.0.0" "scipy==1.11.4"
pip install git+https://github.com/resemble-ai/monotonic_align.git
pip install onnxruntime

# Copiar monotonic_align al directorio de piper
echo -e "\n${YELLOW}🔧 Copiando monotonic_align...${NC}"
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
SITE_PACKAGES="$WORK_DIR/venv/lib/python${PYTHON_VERSION}/site-packages"
cp -r "$SITE_PACKAGES/monotonic_align" "$PIPER_PYTHON_DIR/"

# Parchear piper_train __init__.py
echo -e "\n${YELLOW}🔧 Parcheando monotonic_align en piper_train...${NC}"
INIT_FILE="$PIPER_PYTHON_DIR/piper_train/vits/monotonic_align/__init__.py"
cat > "$INIT_FILE" << 'EOF'
"""Monotonic alignment search"""
import os, sys
_piper_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import torch
import numpy as np
if _piper_dir not in sys.path:
    sys.path.append(_piper_dir)
from monotonic_align.core import maximum_path_c
def maximum_path(neg_cent, mask):
    device, dtype = neg_cent.device, neg_cent.dtype
    neg_cent = neg_cent.data.cpu().numpy().astype(np.float32)
    path = np.zeros(neg_cent.shape, dtype=np.int32)
    t_t_max = mask.sum(1)[:, 0].data.cpu().numpy().astype(np.int32)
    t_s_max = mask.sum(2)[:, 0].data.cpu().numpy().astype(np.int32)
    maximum_path_c(path, neg_cent, t_t_max, t_s_max)
    return torch.from_numpy(path).to(device=device, dtype=dtype)
EOF

# Crear parche de PyTorch para weights_only y PyTorch Lightning 2.4
echo -e "\n${YELLOW}🔧 Aplicando parches de compatibilidad...${NC}"
PATCH_FILE="$PIPER_PYTHON_DIR/piper_train/torch_patch.py"
cat > "$PATCH_FILE" << 'EOF'
import torch
import functools
import warnings

# Monkey-patch torch.load to default weights_only=False for old checkpoints
_original_load = torch.load
@functools.wraps(_original_load)
def safe_load(*args, **kwargs):
    if 'weights_only' not in kwargs:
        kwargs['weights_only'] = False
    return _original_load(*args, **kwargs)
torch.load = safe_load

# Set matmul precision for Tensor Cores
try:
    torch.set_float32_matmul_precision('high')
except:
    pass

# Suprimir warnings de PyTorch Lightning deprecation
warnings.filterwarnings('ignore', category=DeprecationWarning, module='pytorch_lightning')
EOF

# Modificar __main__.py para importar el parche
MAIN_FILE="$PIPER_PYTHON_DIR/piper_train/__main__.py"
if ! grep -q "torch_patch" "$MAIN_FILE"; then
    sed -i '1i from . import torch_patch' "$MAIN_FILE"
fi

# Crear parche para compatibilidad con PyTorch Lightning 2.4
echo -e "\n${YELLOW}🔧 Parcheando código de Piper para PyTorch Lightning 2.4...${NC}"
COMPAT_PATCH="$PIPER_PYTHON_DIR/piper_train/pl_compat_patch.py"
cat > "$COMPAT_PATCH" << 'EOF'
"""Compatibilidad con PyTorch Lightning 2.4"""
import pytorch_lightning as pl
from packaging import version

def apply_patches_to_main():
    """Parchea __main__.py para usar CLI de Lightning 2.4"""
    import sys
    import os
    
    # Solo aplicar si es PL >= 2.0
    if version.parse(pl.__version__) < version.parse("2.0.0"):
        return
    
    # Importar módulo __main__ de piper_train
    main_path = os.path.join(os.path.dirname(__file__), '__main__.py')
    
    # Leer contenido
    with open(main_path, 'r') as f:
        content = f.read()
    
    # Si ya está parcheado, salir
    if 'pl_compat_patch applied' in content:
        return
    
    # Reemplazar Trainer.add_argparse_args con LightningCLI approach
    if 'Trainer.add_argparse_args' in content:
        # Backup
        with open(main_path + '.bak', 'w') as f:
            f.write(content)
        
        # Aplicar parche: comentar la línea problemática
        content = content.replace(
            'Trainer.add_argparse_args(parser)',
            '# Trainer.add_argparse_args(parser)  # pl_compat_patch applied'
        )
        
        with open(main_path, 'w') as f:
            f.write(content)
        
        print("✅ Parche de compatibilidad aplicado a __main__.py")

if __name__ == '__main__':
    apply_patches_to_main()
EOF

python3 "$COMPAT_PATCH"

# Instalar piper-train
echo -e "\n${YELLOW}🛠️ Instalando piper-train...${NC}"
cd "$PIPER_PYTHON_DIR"
pip install --no-deps -e .
cd "$WORK_DIR"

# Verificar instalación
echo -e "\n${YELLOW}🔍 Verificando instalación...${NC}"
python3 << 'PYEOF'
import sys
sys.path.insert(0, "$PIPER_PYTHON_DIR")

import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA disponible: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA versión: {torch.version.cuda}")
    print(f"Dispositivos GPU: {torch.cuda.device_count()}")
    for i in range(torch.cuda.device_count()):
        print(f"  GPU {i}: {torch.cuda.get_device_name(i)}")
else:
    print("⚠️ CUDA no disponible - entrenamiento será en CPU")

import numpy as np
import scipy
print(f"numpy: {np.__version__}")
print(f"scipy: {scipy.__version__}")

import pytorch_lightning as pl
print(f"pytorch-lightning: {pl.__version__}")

import piper_train
print("piper_train: OK")
from piper_train.vits.monotonic_align import maximum_path
print("monotonic_align: OK")
import librosa
print(f"librosa: {librosa.__version__}")

# Verificar parche de torch
from piper_train import torch_patch
print("Torch patch: OK")

# Test
test_neg = torch.randn(1, 10, 20)
test_mask = torch.ones(1, 10, 20)
result = maximum_path(test_neg, test_mask)
print(f"Test maximum_path: {result.shape}")
print("\n✅ TODO LISTO PARA ENTRENAR")
PYEOF

echo -e "\n${GREEN}========================================"
echo "✅ INSTALACIÓN DE PIPER COMPLETADA"
echo "========================================${NC}"
echo ""
echo "Para usar Piper en una nueva sesión:"
echo -e "  ${YELLOW}source $WORK_DIR/venv/bin/activate${NC}"
echo ""
echo "Siguiente paso: Ejecutar 03_download_base_model.sh"
