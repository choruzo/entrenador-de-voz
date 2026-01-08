#!/bin/bash
# verify_gpu.sh
# Verifica que la GPU NVIDIA y PyTorch estén configurados correctamente

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="$HOME/piper-training"

echo "========================================"
echo "🔍 VERIFICACIÓN DE GPU NVIDIA"
echo "========================================"
echo ""

# 1. Verificar nvidia-smi
echo -e "${BLUE}1. Verificando drivers NVIDIA...${NC}"
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}❌ nvidia-smi no encontrado${NC}"
    echo ""
    echo "Para instalar drivers NVIDIA en Ubuntu:"
    echo -e "  ${YELLOW}sudo apt update${NC}"
    echo -e "  ${YELLOW}sudo apt install nvidia-driver-545${NC}"
    echo -e "  ${YELLOW}sudo reboot${NC}"
    exit 1
fi

echo -e "${GREEN}✅ nvidia-smi encontrado${NC}"
nvidia-smi

# Extraer información
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/')

echo ""
echo -e "${GREEN}Driver NVIDIA: $DRIVER_VERSION${NC}"
echo -e "${GREEN}GPU: $GPU_NAME${NC}"
echo -e "${GREEN}VRAM: $GPU_MEMORY${NC}"
echo -e "${GREEN}CUDA Runtime: $CUDA_VERSION${NC}"

# Verificar versión de driver
DRIVER_MAJOR=$(echo $DRIVER_VERSION | cut -d. -f1)
if [ "$DRIVER_MAJOR" -lt 525 ]; then
    echo -e "${YELLOW}⚠️ ADVERTENCIA: Driver antiguo detectado${NC}"
    echo -e "${YELLOW}   Se recomienda driver >= 525 para CUDA 12.x${NC}"
fi

echo ""

# 2. Verificar PyTorch y CUDA
echo -e "${BLUE}2. Verificando PyTorch y CUDA...${NC}"
if [ ! -d "$WORK_DIR/venv" ]; then
    echo -e "${YELLOW}⚠️ Entorno virtual no encontrado en $WORK_DIR${NC}"
    echo "Ejecuta primero install_all.sh o 02_install_piper.sh"
    exit 1
fi

source "$WORK_DIR/venv/bin/activate"

python3 << 'PYEOF'
import sys
import torch

print("\n🐍 PyTorch:")
print(f"   Versión: {torch.__version__}")
print(f"   CUDA compilado: {torch.version.cuda if torch.version.cuda else 'No'}")

if torch.cuda.is_available():
    print(f"   ✅ CUDA disponible: Sí")
    print(f"   Dispositivos GPU: {torch.cuda.device_count()}")
    for i in range(torch.cuda.device_count()):
        gpu_name = torch.cuda.get_device_name(i)
        gpu_capability = torch.cuda.get_device_capability(i)
        print(f"   GPU {i}: {gpu_name}")
        print(f"   Compute Capability: {gpu_capability[0]}.{gpu_capability[1]}")
        
        # Test de tensor en GPU
        try:
            test_tensor = torch.randn(100, 100).cuda(i)
            result = test_tensor @ test_tensor.T
            print(f"   ✅ Test de operación en GPU {i}: OK")
        except Exception as e:
            print(f"   ❌ Error en test de GPU {i}: {e}")
            sys.exit(1)
else:
    print("   ❌ CUDA NO disponible")
    print("\n   Posibles causas:")
    print("   1. PyTorch instalado sin soporte CUDA")
    print("   2. Drivers NVIDIA no instalados o incompatibles")
    print("   3. CUDA toolkit no instalado")
    print("\n   Solución: Ejecuta de nuevo 02_install_piper.sh")
    sys.exit(1)

# Verificar compatibilidad de CUDA
cuda_runtime = torch.version.cuda
if cuda_runtime:
    major = int(cuda_runtime.split('.')[0])
    if major >= 12:
        print(f"   ✅ CUDA {cuda_runtime} compatible con RTX 50xx/40xx/30xx")
    else:
        print(f"   ⚠️ CUDA {cuda_runtime} puede no ser óptimo para GPUs recientes")
PYEOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================"
    echo "✅ GPU CONFIGURADA CORRECTAMENTE"
    echo "========================================${NC}"
    echo ""
    echo "Tu sistema está listo para entrenar con GPU"
    echo ""
    echo "Próximos pasos:"
    echo "  1. Prepara tu dataset"
    echo "  2. Ejecuta: ./04_clean_dataset.sh <ruta_dataset>"
    echo "  3. Ejecuta: ./05_train.sh <ruta_dataset> 3000 8"
    echo ""
else
    echo ""
    echo -e "${RED}========================================"
    echo "❌ PROBLEMA CON LA CONFIGURACIÓN DE GPU"
    echo "========================================${NC}"
    echo ""
    echo "Revisa los errores anteriores y:"
    echo "  1. Verifica que los drivers NVIDIA estén instalados"
    echo "  2. Ejecuta de nuevo: ./02_install_piper.sh"
    echo ""
    exit 1
fi
