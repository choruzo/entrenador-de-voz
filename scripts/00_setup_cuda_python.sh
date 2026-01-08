#!/bin/bash
# 00_setup_cuda_python.sh
# Instala CUDA 12.8 y Python 3.10 para compilar PyTorch con soporte sm_120

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "🔧 CONFIGURACIÓN DE CUDA 12.8 Y PYTHON 3.10"
echo "========================================"

# Verificar si se ejecuta con privilegios
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}❌ No ejecutes este script como root/sudo${NC}"
   echo "El script pedirá contraseña cuando sea necesario"
   exit 1
fi

echo ""
echo -e "${YELLOW}Este script instalará:${NC}"
echo "  - CUDA Toolkit 12.8"
echo "  - Drivers NVIDIA (si es necesario)"
echo "  - Python 3.10"
echo ""
echo -e "${RED}⚠️  ADVERTENCIA: Se eliminarán versiones previas de CUDA${NC}"
echo ""
read -p "¿Continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Instalación cancelada"
    exit 0
fi

# ============================================
# 1. LIMPIAR INSTALACIONES PREVIAS DE CUDA
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}📦 Limpiando instalaciones previas de CUDA...${NC}"
echo -e "${BLUE}========================================${NC}"

sudo apt-get purge -y "*cublas*" "*cufft*" "*curand*" "*cusolver*" "*cusparse*" "*npp*" "*nvjpeg*" "cuda*" "nsight*" 2>/dev/null || true
sudo apt-get autoremove -y

echo -e "${GREEN}✅ Limpieza completada${NC}"

# ============================================
# 2. INSTALAR CUDA 12.8
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}📥 Instalando CUDA 12.8...${NC}"
echo -e "${BLUE}========================================${NC}"

cd /tmp

# Descargar el pin del repositorio
echo -e "${YELLOW}Descargando configuración del repositorio...${NC}"
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600

# Instalar el llavero (keyring)
echo -e "${YELLOW}Instalando keyring de NVIDIA...${NC}"
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
rm cuda-keyring_1.1-1_all.deb

# Actualizar e instalar CUDA Toolkit 12.8
echo -e "${YELLOW}Actualizando repositorios...${NC}"
sudo apt-get update

echo -e "${YELLOW}Instalando CUDA Toolkit 12.8 (esto puede tardar varios minutos)...${NC}"
sudo apt-get install -y cuda-toolkit-12-8

echo -e "${YELLOW}Instalando drivers NVIDIA...${NC}"
sudo apt-get install -y cuda-drivers

echo -e "${GREEN}✅ CUDA 12.8 instalado${NC}"

# ============================================
# 3. CONFIGURAR VARIABLES DE ENTORNO
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}🔧 Configurando variables de entorno...${NC}"
echo -e "${BLUE}========================================${NC}"

# Verificar si ya están en .bashrc
if ! grep -q "cuda-12.8" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# CUDA 12.8 configuration" >> ~/.bashrc
    echo 'export PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
    echo 'export CUDA_HOME=/usr/local/cuda-12.8' >> ~/.bashrc
    echo -e "${GREEN}✅ Variables añadidas a ~/.bashrc${NC}"
else
    echo -e "${YELLOW}⚠️  Variables ya configuradas en ~/.bashrc${NC}"
fi

# Aplicar variables en la sesión actual
export PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export CUDA_HOME=/usr/local/cuda-12.8

# ============================================
# 4. INSTALAR PYTHON 3.10
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}🐍 Instalando Python 3.10...${NC}"
echo -e "${BLUE}========================================${NC}"

# Agregar repositorio deadsnakes si no existe
if ! grep -q "deadsnakes" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    echo -e "${YELLOW}Agregando repositorio deadsnakes PPA...${NC}"
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update
else
    echo -e "${YELLOW}⚠️  Repositorio deadsnakes ya existe${NC}"
fi

# Instalar Python 3.10 y herramientas
echo -e "${YELLOW}Instalando Python 3.10...${NC}"
sudo apt-get install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils

echo -e "${GREEN}✅ Python 3.10 instalado${NC}"

# ============================================
# 5. VERIFICACIÓN
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Verificando instalación...${NC}"
echo -e "${BLUE}========================================${NC}"

# Verificar nvcc
if command -v nvcc &> /dev/null; then
    NVCC_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | tr -d ',')
    echo -e "${GREEN}✅ nvcc version: $NVCC_VERSION${NC}"
else
    echo -e "${RED}❌ nvcc no encontrado${NC}"
fi

# Verificar Python
if command -v python3.10 &> /dev/null; then
    PYTHON_VERSION=$(python3.10 --version)
    echo -e "${GREEN}✅ $PYTHON_VERSION${NC}"
else
    echo -e "${RED}❌ python3.10 no encontrado${NC}"
fi

# Verificar drivers NVIDIA
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✅ Drivers NVIDIA:${NC}"
    nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader
else
    echo -e "${YELLOW}⚠️  nvidia-smi no disponible (instala drivers si es necesario)${NC}"
fi

# ============================================
# FINALIZACIÓN
# ============================================
echo -e "\n${GREEN}========================================"
echo "✅ INSTALACIÓN COMPLETADA"
echo "========================================${NC}"

echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE: Debes reiniciar el sistema para aplicar los cambios de drivers${NC}"
echo ""
echo "Después del reinicio, verifica con:"
echo -e "  ${BLUE}nvcc --version${NC}"
echo -e "  ${BLUE}nvidia-smi${NC}"
echo -e "  ${BLUE}python3.10 --version${NC}"
echo ""
read -p "¿Reiniciar ahora? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Reiniciando en 5 segundos...${NC}"
    sleep 5
    sudo reboot
else
    echo -e "${YELLOW}Recuerda reiniciar antes de continuar con la instalación de Piper${NC}"
fi
