#!/bin/bash
# install_all.sh
# Script maestro para instalación completa del entorno Piper Training

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "🎙️ INSTALACIÓN COMPLETA PIPER TRAINING"
echo "========================================"
echo ""
echo "Este script instalará todo lo necesario para entrenar"
echo "modelos de voz con Piper en Ubuntu"
echo ""
echo "Tiempo estimado: 15-30 minutos"
echo "Descarga requerida: ~1.5 GB"
echo ""

read -p "¿Deseas continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Instalación cancelada"
    exit 0
fi

# Función para ejecutar scripts y verificar errores
run_step() {
    local script=$1
    local description=$2
    
    echo ""
    echo -e "${BLUE}========================================"
    echo "▶ $description"
    echo -e "========================================${NC}"
    
    if [ -f "$SCRIPT_DIR/$script" ]; then
        chmod +x "$SCRIPT_DIR/$script"
        bash "$SCRIPT_DIR/$script"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ $description completado${NC}"
        else
            echo -e "${RED}❌ Error en: $description${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Script no encontrado: $script${NC}"
        exit 1
    fi
}

# Paso 1: Configuración del sistema
run_step "01_setup_system.sh" "Configuración del sistema"

# Paso 2: Instalación de Piper
run_step "02_install_piper.sh" "Instalación de Piper y dependencias"

# Paso 3: Descarga de modelo base
run_step "03_download_base_model.sh" "Descarga de modelo base"

echo ""
echo -e "${GREEN}========================================"
echo "✅ INSTALACIÓN COMPLETA EXITOSA"
echo "========================================${NC}"
echo ""
echo "📁 Directorio de trabajo: $HOME/piper-training"
echo ""
echo -e "${BLUE}🔍 Verificar configuración de GPU:${NC}"
echo -e "   ${YELLOW}cd $SCRIPT_DIR${NC}"
echo -e "   ${YELLOW}./verify_gpu.sh${NC}"
echo ""
echo -e "${BLUE}Próximos pasos:${NC}"
echo ""
echo "1. Prepara tu dataset con la estructura:"
echo "   mi_voz/"
echo "     ├── config.json"
echo "     ├── dataset.jsonl"
echo "     └── wavs/"
echo "         ├── audio001.wav"
echo "         └── ..."
echo ""
echo "2. Limpia y valida el dataset:"
echo -e "   ${YELLOW}cd $SCRIPT_DIR${NC}"
echo -e "   ${YELLOW}./04_clean_dataset.sh \$HOME/piper-training/datasets/mi_voz${NC}"
echo ""
echo "3. Entrena el modelo:"
echo -e "   ${YELLOW}./05_train.sh \$HOME/piper-training/datasets/mi_voz 3000 8${NC}"
echo ""
echo "4. Exporta el modelo entrenado:"
echo -e "   ${YELLOW}./06_export.sh${NC}"
echo ""
echo -e "${BLUE}Documentación adicional:${NC}"
echo "  - README.md - Información general"
echo "  - GUIA_ENTRENAMIENTO.md - Guía detallada"
echo "  - TROUBLESHOOTING.md - Solución de problemas"
echo ""
