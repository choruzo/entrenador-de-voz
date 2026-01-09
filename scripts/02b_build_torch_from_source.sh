#!/bin/bash
# 02b_build_torch_from_source.sh
# Compila PyTorch desde fuente con soporte CUDA para sm_120 (Blackwell)

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORK_DIR="$HOME/piper-training"
cd "$WORK_DIR" || exit 1

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}🛠️ Construyendo PyTorch desde fuente (sm_120)${NC}"
echo -e "${YELLOW}========================================${NC}"

# Verificar entorno virtual activo
if [ -z "$VIRTUAL_ENV" ]; then
  echo -e "${RED}❌ Debes activar el entorno virtual antes de construir${NC}"
  echo -e "   ${YELLOW}source $WORK_DIR/venv/bin/activate${NC}"
  exit 1
fi

# Verificar CUDA toolkit (nvcc)
if ! command -v nvcc &> /dev/null; then
  echo -e "${RED}❌ nvcc no encontrado (CUDA toolkit no instalado)${NC}"
  echo -e "${YELLOW}Instala CUDA toolkit 12.4 antes de continuar.${NC}"
  echo -e "${YELLOW}Sugerencia:${NC} sudo apt install cuda-toolkit-12-4"
  exit 1
fi

# Dependencias de build
echo -e "${YELLOW}📦 Instalando dependencias de compilación...${NC}"
sudo apt-get update -qq
sudo apt-get install -y \
  build-essential \
  cmake \
  ninja-build \
  git \
  git-lfs \
  libopenblas-dev \
  libblas-dev \
  libomp-dev \
  pkg-config \
  python3.10-dev 2>/dev/null || true

# Paquetes Python para build
pip install --upgrade pip
# packaging es requerido por generate_torch_version.py; añadir herramientas comunes de build
pip install packaging setuptools wheel numpy pyyaml typing_extensions future six requests dataclasses ninja jinja2

# Clonar PyTorch (si no existe)
if [ ! -d "pytorch" ]; then
  echo -e "${YELLOW}📥 Clonando repositorio PyTorch...${NC}"
  git clone --recursive https://github.com/pytorch/pytorch.git
else
  echo -e "${GREEN}✅ Repositorio PyTorch ya existe${NC}"
fi

cd pytorch

# Actualizar submódulos
echo -e "${YELLOW}🔄 Actualizando submódulos...${NC}"
git submodule sync
git submodule update --init --recursive

# Opcional: checkout a una rama/commit reciente (mantener main por defecto)
# git checkout main

# Variables de build
export CUDA_HOME=/usr/local/cuda
export TORCH_CUDA_ARCH_LIST="12.0"
export USE_CUDA=1
export USE_ROCM=0
export USE_NINJA=1
#export MAX_JOBS=$(nproc)
export MAX_JOBS=5
export CMAKE_CUDA_COMPILER=$(command -v nvcc)
export USE_NCCL=0
export USE_SYSTEM_NCCL=0
export BUILD_TEST=0

# Limpieza de builds previos
python setup.py clean || true
rm -rf build || true

# Construir e instalar en editable
echo -e "${YELLOW}🏗️ Compilando PyTorch (esto puede tardar 30-90 min)...${NC}"
python setup.py develop

echo -e "${GREEN}✅ PyTorch compilado e instalado (editable)${NC}"

# Verificación rápida
python - <<'PY'
import torch
print('torch:', torch.__version__)
print('cuda available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('device capability:', torch.cuda.get_device_capability())
    print('arch list:', torch.cuda.get_arch_list())
PY

cd "$WORK_DIR"
