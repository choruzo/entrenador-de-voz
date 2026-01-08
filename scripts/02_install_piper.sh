#!/bin/bash
# 02_install_piper.sh
# Instala Piper, piper-phonemize y todas las dependencias Python necesarias

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORK_DIR="$HOME/piper-training"
cd "$WORK_DIR" || exit 1

echo "========================================"
echo "📦 INSTALACIÓN DE PIPER Y DEPENDENCIAS"
echo "========================================"

# Crear entorno virtual Python
echo -e "\n${YELLOW}🐍 Creando entorno virtual Python...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✅ Entorno virtual creado${NC}"
else
    echo -e "${GREEN}✅ Entorno virtual ya existe${NC}"
fi

# Activar entorno virtual
source venv/bin/activate

# Actualizar pip
echo -e "\n${YELLOW}🔧 Actualizando pip...${NC}"
pip install --upgrade pip setuptools wheel

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
pip install "pytorch-lightning==1.7.7" "torchmetrics==0.11.4"
pip install piper-phonemize==1.1.0
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

# Crear parche de PyTorch para weights_only
echo -e "\n${YELLOW}🔧 Aplicando parche de seguridad para PyTorch...${NC}"
PATCH_FILE="$PIPER_PYTHON_DIR/piper_train/torch_patch.py"
cat > "$PATCH_FILE" << 'EOF'
import torch
import functools
# Monkey-patch torch.load to default weights_only=False for old checkpoints
_original_load = torch.load
@functools.wraps(_original_load)
def safe_load(*args, **kwargs):
    if 'weights_only' not in kwargs:
        kwargs['weights_only'] = False
    return _original_load(*args, **kwargs)
torch.load = safe_load

# PyTorch Lightning 1.7 vs PyTorch 2.x LR Scheduler Fix
try:
    import pytorch_lightning.core.optimizer
    def no_op(*args, **kwargs):
        pass
    pytorch_lightning.core.optimizer._validate_scheduler_api = no_op
except ImportError:
    pass
EOF

# Modificar __main__.py para importar el parche
MAIN_FILE="$PIPER_PYTHON_DIR/piper_train/__main__.py"
if ! grep -q "torch_patch" "$MAIN_FILE"; then
    sed -i '1i from . import torch_patch' "$MAIN_FILE"
fi

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
