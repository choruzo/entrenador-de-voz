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
else
    echo -e "${YELLOW}⚠️ nvidia-smi no encontrado. Entrenamiento será en CPU (muy lento)${NC}"
    echo "Para usar GPU, instala los drivers NVIDIA y CUDA toolkit"
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
