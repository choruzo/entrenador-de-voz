#!/bin/bash
# 01_setup_system.sh
# Configura las dependencias del sistema para Piper Training en Ubuntu

set -e

echo "========================================"
echo "🔧 CONFIGURACIÓN DEL SISTEMA PARA PIPER"
echo "========================================"

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar GPU NVIDIA (opcional pero recomendado)
echo -e "\n${YELLOW}🔍 Verificando GPU NVIDIA...${NC}"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
    echo -e "${GREEN}✅ GPU NVIDIA detectada${NC}"
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/')
    echo -e "${GREEN}   Driver: $DRIVER_VERSION${NC}"
    echo -e "${GREEN}   CUDA Runtime: $CUDA_VERSION${NC}"
    
    # Verificar que el driver sea reciente (>=525 para CUDA 12+)
    DRIVER_MAJOR=$(echo $DRIVER_VERSION | cut -d. -f1)
    if [ "$DRIVER_MAJOR" -lt 525 ]; then
        echo -e "${YELLOW}⚠️ ADVERTENCIA: Se recomienda actualizar los drivers NVIDIA${NC}"
        echo -e "${YELLOW}   Para RTX 5060 Ti, instala drivers >= 525${NC}"
        echo -e "${YELLOW}   Visita: https://www.nvidia.com/Download/index.aspx${NC}"
    fi
else
    echo -e "${RED}⚠️ nvidia-smi no encontrado${NC}"
    echo -e "${YELLOW}Para usar la GPU NVIDIA RTX 5060 Ti:${NC}"
    echo -e "${YELLOW}1. Instala los drivers NVIDIA más recientes:${NC}"
    echo -e "   ${YELLOW}sudo apt install nvidia-driver-545${NC}"
    echo -e "${YELLOW}2. Reinicia el sistema${NC}"
    echo -e "${YELLOW}3. Verifica con: nvidia-smi${NC}"
    echo ""
    read -p "¿Continuar sin GPU? El entrenamiento será MUY lento (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Instalación pausada. Instala los drivers NVIDIA y vuelve a ejecutar."
        exit 0
    fi
fi

# Actualizar repositorios
echo -e "\n${YELLOW}📦 Actualizando repositorios...${NC}"
sudo apt-get update -qq

# Instalar dependencias del sistema
echo -e "\n${YELLOW}📦 Instalando dependencias del sistema...${NC}"
sudo apt-get install -y \
    espeak-ng \
    wget \
    git \
    python3-pip \
    python3-venv \
    build-essential \
    ffmpeg \
    sox \
    libsox-fmt-all \
    2>&1 | grep -v "debconf" || true

# Verificar espeak-ng
if command -v espeak-ng &> /dev/null; then
    echo -e "${GREEN}✅ espeak-ng instalado:${NC}"
    espeak-ng --version
else
    echo -e "${RED}❌ Error: espeak-ng no se instaló correctamente${NC}"
    exit 1
fi

# Verificar Python
echo -e "\n${YELLOW}🐍 Verificando Python...${NC}"
python3 --version
pip3 --version

# Crear directorio de trabajo
WORK_DIR="$HOME/piper-training"
echo -e "\n${YELLOW}📁 Creando directorio de trabajo: ${WORK_DIR}${NC}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo -e "\n${GREEN}========================================"
echo "✅ CONFIGURACIÓN DEL SISTEMA COMPLETADA"
echo "========================================${NC}"
echo -e "Directorio de trabajo: ${GREEN}$WORK_DIR${NC}"
echo ""
echo "Siguiente paso: Ejecutar 02_install_piper.sh"
