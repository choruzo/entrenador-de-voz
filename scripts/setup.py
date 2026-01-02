#!/usr/bin/env python3
"""
Script de configuración inicial para entrenamiento de voces Piper
Optimizado para AMD Radeon (ROCm) y NVIDIA (CUDA)

Versión Python compatible con Windows, Linux y macOS
"""

import argparse
import logging
import os
import platform
import subprocess
import sys
import urllib.request
from pathlib import Path

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'
)
logger = logging.getLogger(__name__)


class Colors:
    """Colores ANSI para terminal (funciona en Windows 10+)"""
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color
    
    @classmethod
    def disable_if_unsupported(cls):
        """Deshabilita colores en Windows antiguo sin soporte ANSI"""
        if sys.platform == 'win32':
            try:
                # Habilitar colores ANSI en Windows 10+
                import ctypes
                kernel32 = ctypes.windll.kernel32
                kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
            except:
                # Deshabilitar colores si falla
                cls.GREEN = cls.YELLOW = cls.RED = cls.NC = ''


Colors.disable_if_unsupported()


def print_info(msg):
    """Imprime mensaje informativo"""
    print(f"{Colors.GREEN}[INFO]{Colors.NC} {msg}")


def print_warning(msg):
    """Imprime mensaje de advertencia"""
    print(f"{Colors.YELLOW}[ADVERTENCIA]{Colors.NC} {msg}")


def print_error(msg):
    """Imprime mensaje de error"""
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")


def print_header(msg):
    """Imprime encabezado"""
    print()
    print("=" * 50)
    print(msg)
    print("=" * 50)
    print()


def detect_system():
    """Detecta el sistema operativo y arquitectura"""
    system = platform.system()
    machine = platform.machine()
    
    print_info(f"Sistema operativo: {system}")
    print_info(f"Arquitectura: {machine}")
    print_info(f"Versión de Python: {sys.version}")
    
    return system, machine


def check_rocm():
    """Verifica si ROCm está instalado (solo Linux)"""
    if sys.platform != 'linux':
        return False
    
    try:
        result = subprocess.run(['rocm-smi'], capture_output=True, timeout=5)
        if result.returncode == 0:
            print_info("ROCm está instalado")
            # Mostrar información de ROCm
            subprocess.run(['rocm-smi'])
            return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    
    return False


def check_cuda():
    """Verifica si CUDA está instalado"""
    try:
        result = subprocess.run(['nvidia-smi'], capture_output=True, timeout=5)
        if result.returncode == 0:
            print_info("CUDA/NVIDIA GPU detectada")
            # Mostrar información
            subprocess.run(['nvidia-smi'])
            return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    
    return False


def create_venv(work_dir, force=False):
    """Crea un entorno virtual de Python"""
    venv_dir = work_dir / "venv-piper"
    
    if venv_dir.exists() and not force:
        print_info("Entorno virtual ya existe")
        return venv_dir
    
    print_info("Creando entorno virtual de Python...")
    try:
        subprocess.run([sys.executable, '-m', 'venv', str(venv_dir)], check=True)
        print_info("Entorno virtual creado")
        return venv_dir
    except subprocess.CalledProcessError as e:
        print_error(f"Error creando entorno virtual: {e}")
        return None


def get_venv_python(venv_dir):
    """Obtiene la ruta del ejecutable de Python del entorno virtual"""
    if sys.platform == 'win32':
        return venv_dir / "Scripts" / "python.exe"
    else:
        return venv_dir / "bin" / "python"


def get_venv_pip(venv_dir):
    """Obtiene la ruta del ejecutable de pip del entorno virtual"""
    if sys.platform == 'win32':
        return venv_dir / "Scripts" / "pip.exe"
    else:
        return venv_dir / "bin" / "pip"


def run_in_venv(venv_dir, cmd, check=True):
    """Ejecuta un comando en el entorno virtual"""
    python_exe = get_venv_python(venv_dir)
    
    if cmd[0] in ['pip', 'python', 'python3']:
        # Reemplazar pip/python con la versión del venv
        if cmd[0] == 'pip':
            cmd[0] = str(get_venv_pip(venv_dir))
        else:
            cmd[0] = str(python_exe)
    
    return subprocess.run(cmd, check=check)


def install_pytorch(venv_dir, gpu_type=None):
    """Instala PyTorch con el soporte adecuado"""
    print_info("Instalando PyTorch...")
    
    pip_exe = str(get_venv_pip(venv_dir))
    
    if gpu_type == 'rocm':
        print_info("Instalando PyTorch con soporte ROCm...")
        cmd = [
            pip_exe, 'install', 'torch', 'torchvision', 'torchaudio',
            '--index-url', 'https://download.pytorch.org/whl/rocm6.0'
        ]
    elif gpu_type == 'cuda':
        print_info("Instalando PyTorch con soporte CUDA...")
        cmd = [
            pip_exe, 'install', 'torch', 'torchvision', 'torchaudio',
            '--index-url', 'https://download.pytorch.org/whl/cu121'
        ]
    else:
        print_warning("Instalando PyTorch para CPU solamente")
        cmd = [pip_exe, 'install', 'torch', 'torchvision', 'torchaudio']
    
    try:
        subprocess.run(cmd, check=True)
        print_info("PyTorch instalado correctamente")
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"Error instalando PyTorch: {e}")
        return False


def verify_pytorch(venv_dir):
    """Verifica la instalación de PyTorch"""
    print_info("Verificando instalación de PyTorch...")
    
    python_exe = str(get_venv_python(venv_dir))
    
    verify_script = """
import torch
print(f"PyTorch versión: {torch.__version__}")
print(f"CUDA disponible: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"Dispositivo detectado: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    print(f"VRAM disponible: {props.total_memory / 1024**3:.2f} GB")
else:
    print("Usando CPU para entrenamiento")
"""
    
    try:
        result = subprocess.run(
            [python_exe, '-c', verify_script],
            check=True,
            capture_output=True,
            text=True
        )
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"Error verificando PyTorch: {e}")
        if e.stderr:
            print(e.stderr)
        return False


def check_espeak_ng():
    """Verifica e instala espeak-ng si es necesario"""
    print_info("Verificando espeak-ng...")
    
    # Verificar si ya está instalado
    try:
        result = subprocess.run(['espeak-ng', '--version'], capture_output=True, timeout=5)
        if result.returncode == 0:
            print_info("espeak-ng ya está instalado")
            return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    
    print_warning("espeak-ng no está instalado")
    
    if sys.platform == 'linux':
        # En Linux, intentar instalar con apt
        system = platform.freedesktop_os_release()
        if system.get('ID') in ['ubuntu', 'debian']:
            print_info("Instalando espeak-ng con apt...")
            try:
                subprocess.run(['sudo', 'apt-get', 'update'], check=True)
                subprocess.run(['sudo', 'apt-get', 'install', '-y', 'espeak-ng'], check=True)
                print_info("espeak-ng instalado correctamente")
                return True
            except subprocess.CalledProcessError:
                print_error("Error instalando espeak-ng")
                return False
        else:
            print_warning("Por favor instala espeak-ng manualmente para tu distribución")
            return False
    
    elif sys.platform == 'win32':
        print_info("Instrucciones para Windows:")
        print("  1. Descarga espeak-ng desde: https://github.com/espeak-ng/espeak-ng/releases")
        print("  2. Instala y agrega al PATH de Windows")
        print("  3. Reinicia esta configuración")
        return False
    
    elif sys.platform == 'darwin':
        print_info("En macOS, instala con Homebrew:")
        print("  brew install espeak-ng")
        return False
    
    return False


def clone_piper(work_dir):
    """Clona el repositorio de Piper"""
    piper_dir = work_dir / "piper"
    
    if piper_dir.exists():
        print_info("Repositorio de Piper ya existe")
        # Intentar actualizar
        try:
            subprocess.run(['git', 'pull'], cwd=piper_dir, check=True, capture_output=True)
            print_info("Repositorio actualizado")
        except subprocess.CalledProcessError:
            print_warning("No se pudo actualizar el repositorio")
        return piper_dir
    
    print_info("Clonando repositorio de Piper...")
    try:
        subprocess.run(
            ['git', 'clone', 'https://github.com/rhasspy/piper.git', str(piper_dir)],
            check=True
        )
        print_info("Repositorio clonado")
        return piper_dir
    except subprocess.CalledProcessError as e:
        print_error(f"Error clonando repositorio: {e}")
        return None


def install_piper(venv_dir, piper_dir):
    """Instala Piper para entrenamiento"""
    print_info("Instalando Piper training...")
    
    pip_exe = str(get_venv_pip(venv_dir))
    piper_src = piper_dir / "src" / "python"
    
    if not piper_src.exists():
        print_error(f"No se encontró el código fuente de Piper en {piper_src}")
        return False
    
    try:
        # Instalar Piper en modo editable
        subprocess.run([pip_exe, 'install', '-e', str(piper_src)], check=True)
        
        # Instalar piper-phonemize
        subprocess.run([pip_exe, 'install', 'piper-phonemize'], check=True)
        
        print_info("Piper training instalado correctamente")
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"Error instalando Piper: {e}")
        return False


def install_dependencies(venv_dir):
    """Instala dependencias adicionales"""
    print_info("Instalando dependencias adicionales...")
    
    pip_exe = str(get_venv_pip(venv_dir))
    
    packages = [
        'numpy', 'scipy', 'librosa', 'soundfile',
        'onnx', 'onnxruntime',
        'pandas', 'tqdm', 'pydub'
    ]
    
    try:
        subprocess.run([pip_exe, 'install'] + packages, check=True)
        print_info("Dependencias instaladas correctamente")
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"Error instalando dependencias: {e}")
        return False


def create_directory_structure(work_dir):
    """Crea estructura de directorios"""
    print_info("Creando estructura de directorios...")
    
    dirs = ['datasets', 'models_base', 'checkpoints', 'outputs']
    
    for dir_name in dirs:
        dir_path = work_dir / dir_name
        dir_path.mkdir(parents=True, exist_ok=True)
    
    print_info("Estructura de directorios creada")


def create_env_script(work_dir, gpu_type=None):
    """Crea script de activación de entorno"""
    print_info("Creando archivo de configuración...")
    
    if sys.platform == 'win32':
        env_file = work_dir / "env_setup.bat"
        script_content = f'''@echo off
REM Script de activación de entorno para Piper (Windows)

REM Activar entorno virtual
call venv-piper\\Scripts\\activate.bat

REM Variables útiles
set PIPER_TRAIN_DIR={work_dir}
set DATASETS_DIR=%PIPER_TRAIN_DIR%\\datasets
set MODELS_DIR=%PIPER_TRAIN_DIR%\\models_base
set CHECKPOINTS_DIR=%PIPER_TRAIN_DIR%\\checkpoints
set OUTPUTS_DIR=%PIPER_TRAIN_DIR%\\outputs

echo Entorno de Piper activado
echo Directorio de trabajo: %PIPER_TRAIN_DIR%
'''
    else:
        env_file = work_dir / "env_setup.sh"
        
        # Configuraciones específicas de GPU
        gpu_config = ""
        if gpu_type == 'rocm':
            gpu_config = """
# Optimizaciones para ROCm (AMD GPU)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:512
"""
        
        script_content = f'''#!/bin/bash
# Script de activación de entorno para Piper (Linux/Mac)

# Activar entorno virtual
source venv-piper/bin/activate

{gpu_config}
# Variables útiles
export PIPER_TRAIN_DIR="{work_dir}"
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
elif command -v nvidia-smi &> /dev/null; then
    echo ""
    echo "Estado de GPU NVIDIA:"
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv
fi
'''
    
    with open(env_file, 'w', encoding='utf-8') as f:
        f.write(script_content)
    
    # Hacer ejecutable en Linux/Mac
    if sys.platform != 'win32':
        env_file.chmod(0o755)
    
    print_info(f"Script de configuración creado: {env_file}")
    return env_file


def download_base_model(work_dir):
    """Descarga el modelo base es_ES-sharvard-medium"""
    print_info("Descargando modelo base es_ES-sharvard-medium...")
    
    models_dir = work_dir / "models_base"
    models_dir.mkdir(parents=True, exist_ok=True)
    
    files = {
        'es_ES-sharvard-medium.ckpt': 'https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium/es_ES-sharvard-medium.ckpt',
        'es_ES-sharvard-medium.onnx.json': 'https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx.json'
    }
    
    for filename, url in files.items():
        file_path = models_dir / filename
        
        if file_path.exists():
            print_info(f"{filename} ya existe")
            continue
        
        print_info(f"Descargando {filename}...")
        try:
            urllib.request.urlretrieve(url, file_path)
            print_info(f"{filename} descargado")
        except Exception as e:
            print_warning(f"No se pudo descargar {filename}: {e}")
            print_info(f"Descárgalo manualmente desde Hugging Face:")
            print(f"  {url}")


def setup_piper_training(work_dir=None, cpu_only=False):
    """
    Configura el entorno para entrenamiento de Piper
    
    Args:
        work_dir: Directorio de trabajo (default: ~/piper-training)
        cpu_only: Forzar instalación solo para CPU
        
    Returns:
        bool: True si fue exitoso, False si falló
    """
    print_header("Configuración de Entorno para Piper TTS")
    
    # Detectar sistema
    system, machine = detect_system()
    
    # Determinar directorio de trabajo
    if work_dir is None:
        work_dir = Path.home() / "piper-training"
    else:
        work_dir = Path(work_dir)
    
    print_info(f"Creando directorio de trabajo en {work_dir}")
    work_dir.mkdir(parents=True, exist_ok=True)
    
    # Detectar GPU
    gpu_type = None
    if not cpu_only:
        print_info("Verificando GPUs disponibles...")
        
        if check_rocm():
            gpu_type = 'rocm'
        elif check_cuda():
            gpu_type = 'cuda'
        else:
            print_warning("No se detectó GPU compatible")
            
            if sys.stdin.isatty():
                try:
                    response = input("¿Deseas continuar con CPU solamente? (s/N): ")
                    if response.lower() not in ['s', 'si', 'y', 'yes']:
                        print_info("Configuración cancelada")
                        return False
                except (EOFError, KeyboardInterrupt):
                    print()
                    print_info("Configuración cancelada")
                    return False
    
    # Crear entorno virtual
    venv_dir = create_venv(work_dir)
    if venv_dir is None:
        return False
    
    # Actualizar pip
    print_info("Actualizando pip...")
    pip_exe = str(get_venv_pip(venv_dir))
    try:
        subprocess.run([pip_exe, 'install', '--upgrade', 'pip', 'setuptools', 'wheel'], check=True)
    except subprocess.CalledProcessError:
        print_warning("No se pudo actualizar pip")
    
    # Instalar PyTorch
    if not install_pytorch(venv_dir, gpu_type):
        return False
    
    # Verificar PyTorch
    if not verify_pytorch(venv_dir):
        return False
    
    # Verificar/instalar espeak-ng
    if not check_espeak_ng():
        print_warning("espeak-ng no está disponible. Instálalo antes de continuar.")
    
    # Clonar Piper
    piper_dir = clone_piper(work_dir)
    if piper_dir is None:
        return False
    
    # Instalar Piper
    if not install_piper(venv_dir, piper_dir):
        return False
    
    # Instalar dependencias adicionales
    if not install_dependencies(venv_dir):
        return False
    
    # Crear estructura de directorios
    create_directory_structure(work_dir)
    
    # Crear script de activación
    env_script = create_env_script(work_dir, gpu_type)
    
    # Descargar modelo base
    download_base_model(work_dir)
    
    # Resumen final
    print_header("¡Configuración completada!")
    
    print("Para usar el entorno:")
    if sys.platform == 'win32':
        print(f"  cd {work_dir}")
        print(f"  env_setup.bat")
    else:
        print(f"  cd {work_dir}")
        print(f"  source env_setup.sh")
    
    print()
    print("Luego sigue estos pasos:")
    print("  1. Preparar tu dataset")
    print("  2. Preprocesar los datos")
    print("  3. Entrenar el modelo")
    print("  4. Exportar y probar")
    print()
    print_info(f"Directorio de trabajo: {work_dir}")
    print_info("Guía completa: GUIA_ENTRENAMIENTO.md")
    print()
    
    return True


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(
        description='Configuración inicial para entrenamiento de voces Piper (compatible con Windows, Linux y macOS)',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        '--work-dir',
        help='Directorio de trabajo (por defecto: ~/piper-training)'
    )
    
    parser.add_argument(
        '--cpu-only',
        action='store_true',
        help='Forzar instalación solo para CPU (sin GPU)'
    )
    
    args = parser.parse_args()
    
    try:
        success = setup_piper_training(args.work_dir, args.cpu_only)
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        print_info("Configuración interrumpida por el usuario")
        sys.exit(1)
    except Exception as e:
        print_error(f"Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
