#!/bin/bash
# 00_install_gpu_drivers.sh
# Instala los drivers de NVIDIA recomendados para el sistema
# Basado en ubuntu-drivers common

set -e

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "🎮 INSTALACIÓN DE DRIVERS NVIDIA (RTX 5060 Ti)"
echo "=================================================="

# Verificar si se está ejecutando como root
if [ "$EUID" -eq 0 ]; then 
  echo -e "${RED}Por favor, no ejecutes este script como root (sudo).${NC}"
  echo "El script solicitará sudo cuando sea necesario."
  exit 1
fi

echo -e "\n${YELLOW}1. Actualizando repositorios...${NC}"
sudo apt update

echo -e "\n${YELLOW}2. Instalando herramienta de detección (ubuntu-drivers-common)...${NC}"
sudo apt install -y ubuntu-drivers-common

echo -e "\n${YELLOW}3. Buscando drivers disponibles...${NC}"
# Mostrar lista de dispositivos y drivers
ubuntu-drivers devices

# Obtener driver recomendado automáticamente
RECOMMENDED_DRIVER=$(ubuntu-drivers devices | grep "recommended" | awk '{print $3}')

if [ -z "$RECOMMENDED_DRIVER" ]; then
    echo -e "\n${RED}⚠️ No se encontró una recomendación específica.${NC}"
    echo "Intentando autoinstalación genérica..."
    sudo ubuntu-drivers autoinstall
else
    echo -e "\n${GREEN}✅ Driver recomendado identificado: $RECOMMENDED_DRIVER${NC}"
    
    echo -e "${YELLOW}¿Deseas instalar $RECOMMENDED_DRIVER ahora? (s/n)${NC}"
    read -p ">> " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "\n${YELLOW}Instalando $RECOMMENDED_DRIVER...${NC}"
        echo "⚠️  Esta operación puede tardar unos minutos."
        sudo apt install -y "$RECOMMENDED_DRIVER"
        
        echo -e "\n${GREEN}🎉 Instalación completada.${NC}"
        echo -e "${YELLOW}❗ ES NECESARIO REINICIAR EL SISTEMA.${NC}"
        echo "¿Deseas reiniciar ahora? (s/n)"
        read -p ">> " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            sudo reboot
        else
            echo "Por favor, reinicia manualmente con 'sudo reboot' para activar los drivers."
        fi
    else
        echo "Instalación cancelada por el usuario."
    fi
fi
