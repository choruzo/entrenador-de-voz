#!/usr/bin/env python3
"""
Script de entrenamiento para Piper TTS
Optimizado para GPUs AMD (ROCm) y NVIDIA (CUDA), y CPU

Versión Python compatible con Windows y Linux
"""

import argparse
import json
import logging
import os
import subprocess
import sys
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


def check_gpu_availability():
    """Verifica si hay GPU disponible y muestra información"""
    try:
        import torch
        
        if torch.cuda.is_available():
            device_name = torch.cuda.get_device_name(0)
            total_mem = torch.cuda.get_device_properties(0).total_memory / (1024**3)
            print(f"GPU detectada: {device_name}")
            print(f"VRAM total: {total_mem:.2f} GB")
            
            if total_mem < 6:
                print_warning("GPU con menos de 6GB VRAM. Considera reducir batch_size")
            
            return True
        else:
            print("No se detectó GPU. Entrenamiento usará CPU (será muy lento)")
            if sys.platform == 'linux':
                print("Para GPU AMD: Asegúrate de tener ROCm instalado y PyTorch compilado con soporte ROCm")
                print("Para GPU NVIDIA: Asegúrate de tener CUDA instalado y PyTorch compilado con soporte CUDA")
            elif sys.platform == 'win32':
                print("Para GPU NVIDIA: Asegúrate de tener CUDA instalado")
                print("Para GPU AMD en Windows: El soporte es limitado, considera usar Linux o WSL")
            return False
    except ImportError:
        print_error("PyTorch no está instalado")
        return False
    except Exception as e:
        print_error(f"Error verificando GPU: {e}")
        return False


def create_monitor_script(checkpoint_dir):
    """Crea un script de monitoreo para el entrenamiento"""
    monitor_path = checkpoint_dir / "monitor.py"
    
    monitor_script = '''#!/usr/bin/env python3
"""Script de monitoreo para el entrenamiento de Piper"""

import os
import sys
import time
import subprocess
from pathlib import Path

def clear_screen():
    """Limpia la pantalla de forma compatible con Windows y Linux"""
    os.system('cls' if sys.platform == 'win32' else 'clear')

def show_gpu_status():
    """Muestra el estado de la GPU si está disponible"""
    try:
        # Intentar rocm-smi (AMD)
        if subprocess.run(['rocm-smi', '--showuse', '--showtemp', '--showmeminfo', 'vram'],
                         capture_output=True).returncode == 0:
            subprocess.run(['rocm-smi', '--showuse', '--showtemp', '--showmeminfo', 'vram'])
            return
    except FileNotFoundError:
        pass
    
    try:
        # Intentar nvidia-smi (NVIDIA)
        if subprocess.run(['nvidia-smi'], capture_output=True).returncode == 0:
            subprocess.run(['nvidia-smi'])
            return
    except FileNotFoundError:
        pass
    
    print("No se detectó comando de monitoreo de GPU (rocm-smi o nvidia-smi)")

def main():
    """Monitorea el entrenamiento"""
    log_file = Path("training.log")
    
    print("========== Monitor de Entrenamiento Piper ==========")
    print("Presiona Ctrl+C para salir del monitor")
    print("El entrenamiento continúa en background")
    print()
    
    try:
        while True:
            clear_screen()
            print("========== Monitor de Entrenamiento Piper ==========")
            print()
            
            print("Estado de GPU:")
            show_gpu_status()
            print()
            
            print("Últimas líneas del log de entrenamiento:")
            if log_file.exists():
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    for line in lines[-15:]:
                        print(line.rstrip())
            else:
                print("Esperando inicio del entrenamiento...")
            
            print()
            print("Presiona Ctrl+C para salir del monitor")
            print("El entrenamiento continúa en background")
            
            time.sleep(5)
    
    except KeyboardInterrupt:
        print("\\nSaliendo del monitor...")

if __name__ == '__main__':
    main()
'''
    
    with open(monitor_path, 'w', encoding='utf-8') as f:
        f.write(monitor_script)
    
    # Hacer el script ejecutable en Linux/Mac
    if sys.platform != 'win32':
        monitor_path.chmod(0o755)
    
    return monitor_path


def train_model(dataset_dir, checkpoint_base=None, checkpoint_dir='./checkpoints', **kwargs):
    """
    Entrena un modelo de Piper TTS
    
    Args:
        dataset_dir: Directorio del dataset preprocesado
        checkpoint_base: Checkpoint del modelo base para transfer learning (opcional)
        checkpoint_dir: Directorio para guardar checkpoints
        **kwargs: Parámetros de entrenamiento adicionales
        
    Returns:
        bool: True si fue exitoso, False si falló
    """
    dataset_path = Path(dataset_dir)
    checkpoint_path = Path(checkpoint_dir)
    
    # Verificar que el dataset existe
    if not dataset_path.exists():
        print_error(f"El directorio del dataset no existe: {dataset_dir}")
        return False
    
    config_path = dataset_path / "config.json"
    if not config_path.exists():
        print_error(f"No se encontró config.json en {dataset_dir}")
        print_info("Ejecuta primero el preprocesamiento: python scripts/preprocess.py")
        return False
    
    # Verificar checkpoint base si se proporcionó
    if checkpoint_base and not Path(checkpoint_base).exists():
        print_error(f"Checkpoint base no encontrado: {checkpoint_base}")
        return False
    
    # Crear directorio de checkpoints
    checkpoint_path.mkdir(parents=True, exist_ok=True)
    
    # Obtener parámetros de entrenamiento (usar valores por defecto o de variables de entorno)
    batch_size = kwargs.get('batch_size') or int(os.environ.get('BATCH_SIZE', 8))
    max_epochs = kwargs.get('max_epochs') or int(os.environ.get('MAX_EPOCHS', 10000))
    checkpoint_epochs = kwargs.get('checkpoint_epochs') or int(os.environ.get('CHECKPOINT_EPOCHS', 1000))
    learning_rate = kwargs.get('learning_rate') or float(os.environ.get('LEARNING_RATE', 1e-4))
    validation_split = kwargs.get('validation_split') or float(os.environ.get('VALIDATION_SPLIT', 0.05))
    num_test_examples = kwargs.get('num_test_examples') or int(os.environ.get('NUM_TEST_EXAMPLES', 5))
    quality = kwargs.get('quality') or os.environ.get('QUALITY', 'medium')
    precision = kwargs.get('precision') or os.environ.get('PRECISION', '16-mixed')
    
    # Mostrar configuración
    print_info("Configuración de entrenamiento:")
    print(f"  Dataset: {dataset_dir}")
    print(f"  Batch size: {batch_size}")
    print(f"  Épocas máximas: {max_epochs}")
    print(f"  Tasa de aprendizaje: {learning_rate}")
    print(f"  Calidad: {quality}")
    print(f"  Precisión: {precision}")
    print(f"  Validación: {validation_split*100:.1f}%")
    
    if checkpoint_base:
        print_info(f"Transfer learning desde: {checkpoint_base}")
    else:
        print_warning("Entrenando desde cero (sin transfer learning)")
        print_info("Recomendación: Usa un modelo base para mejores resultados")
    
    print()
    
    # Configurar variables de entorno para ROCm (AMD GPU) si es Linux
    if sys.platform == 'linux':
        os.environ['HSA_OVERRIDE_GFX_VERSION'] = '10.3.0'
        os.environ['PYTORCH_HIP_ALLOC_CONF'] = 'max_split_size_mb:512'
    
    # Verificar GPU
    print_info("Verificando GPU disponible...")
    check_gpu_availability()
    print()
    
    # Preguntar confirmación (solo si es interactivo)
    if sys.stdin.isatty():
        try:
            response = input("¿Continuar con el entrenamiento? (s/N): ")
            if response.lower() not in ['s', 'si', 'y', 'yes']:
                print_info("Entrenamiento cancelado")
                return False
        except (EOFError, KeyboardInterrupt):
            print()
            print_info("Entrenamiento cancelado")
            return False
    
    # Crear script de monitoreo
    monitor_script = create_monitor_script(checkpoint_path)
    
    print_info("Iniciando entrenamiento...")
    print_info(f"Los checkpoints se guardarán en: {checkpoint_dir}")
    print_info(f"Para monitorear el progreso:")
    if sys.platform == 'win32':
        print(f"  python {monitor_script}")
    else:
        print(f"  python {monitor_script}")
        print(f"  # O para GPU: watch -n 2 'rocm-smi' (AMD) o 'nvidia-smi' (NVIDIA)")
    print_info(f"Log de entrenamiento: {checkpoint_path / 'training.log'}")
    print()
    
    # Construir comando de entrenamiento
    cmd = [
        sys.executable, '-m', 'piper_train',
        '--dataset-dir', str(dataset_path),
        '--accelerator', 'gpu',
        '--devices', '1',
        '--batch-size', str(batch_size),
        '--validation-split', str(validation_split),
        '--num-test-examples', str(num_test_examples),
        '--max_epochs', str(max_epochs),
        '--checkpoint-epochs', str(checkpoint_epochs),
        '--precision', precision,
        '--quality', quality,
        '--learning-rate', str(learning_rate),
    ]
    
    if checkpoint_base:
        cmd.extend(['--resume-from-checkpoint', checkpoint_base])
    
    # Ejecutar entrenamiento y guardar log
    log_path = checkpoint_path / 'training.log'
    try:
        with open(log_path, 'w', encoding='utf-8') as log_file:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1
            )
            
            # Mostrar output en tiempo real y guardar en log
            for line in process.stdout:
                print(line, end='')
                log_file.write(line)
                log_file.flush()
            
            process.wait()
            exit_code = process.returncode
    
    except FileNotFoundError:
        print_error("No se pudo ejecutar piper_train")
        print_info("Asegúrate de que Piper está instalado correctamente")
        return False
    except Exception as e:
        print_error(f"Error ejecutando entrenamiento: {e}")
        return False
    
    if exit_code == 0:
        print()
        print_info("¡Entrenamiento completado!")
        
        # Buscar el último checkpoint
        ckpt_files = sorted(checkpoint_path.glob("*.ckpt"), key=lambda p: p.stat().st_mtime, reverse=True)
        
        if ckpt_files:
            last_checkpoint = ckpt_files[0]
            print_info(f"Último checkpoint: {last_checkpoint}")
            print()
            print_info("Siguiente paso: Exportar el modelo")
            if sys.platform == 'win32':
                print(f"  python scripts\\export.py {last_checkpoint} mi_modelo.onnx")
            else:
                print(f"  python scripts/export.py {last_checkpoint} mi_modelo.onnx")
        else:
            print_warning("No se encontraron checkpoints guardados")
        
        return True
    else:
        print()
        print_error(f"El entrenamiento falló con código de salida {exit_code}")
        print_info(f"Revisa el log en: {log_path}")
        
        if exit_code == 137:
            print_error("Error 137: Out of Memory (OOM)")
            print_info("Soluciones:")
            print(f"  1. Reduce el batch size: --batch-size 4")
            print(f"  2. Cierra otras aplicaciones que usen GPU")
            print(f"  3. Reduce la resolución/calidad del modelo: --quality low")
        
        return False


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(
        description='Entrenamiento de modelo Piper TTS (compatible con Windows y Linux)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  python train.py dataset_procesado modelos_base/es_ES-sharvard-medium.ckpt
  python train.py dataset_procesado --batch-size 4 --max-epochs 5000
  python train.py dataset_procesado --quality low

Parámetros de entorno:
  BATCH_SIZE      - Tamaño del batch (por defecto: 8)
  MAX_EPOCHS      - Número máximo de épocas (por defecto: 10000)
  LEARNING_RATE   - Tasa de aprendizaje (por defecto: 1e-4)
  QUALITY         - Calidad: x_low, low, medium, high (por defecto: medium)
        """
    )
    
    parser.add_argument(
        'dataset_dir',
        help='Dataset preprocesado'
    )
    
    parser.add_argument(
        'checkpoint_base',
        nargs='?',
        default=None,
        help='Checkpoint del modelo base para transfer learning (opcional)'
    )
    
    parser.add_argument(
        '--checkpoint-dir',
        default='./checkpoints',
        help='Directorio para guardar checkpoints (por defecto: ./checkpoints)'
    )
    
    parser.add_argument(
        '--batch-size',
        type=int,
        help='Tamaño del batch (por defecto: 8)'
    )
    
    parser.add_argument(
        '--max-epochs',
        type=int,
        help='Número máximo de épocas (por defecto: 10000)'
    )
    
    parser.add_argument(
        '--checkpoint-epochs',
        type=int,
        help='Guardar checkpoint cada N épocas (por defecto: 1000)'
    )
    
    parser.add_argument(
        '--learning-rate',
        type=float,
        help='Tasa de aprendizaje (por defecto: 1e-4)'
    )
    
    parser.add_argument(
        '--validation-split',
        type=float,
        help='Fracción para validación (por defecto: 0.05)'
    )
    
    parser.add_argument(
        '--num-test-examples',
        type=int,
        help='Número de ejemplos de prueba (por defecto: 5)'
    )
    
    parser.add_argument(
        '--quality',
        choices=['x_low', 'low', 'medium', 'high'],
        help='Calidad del modelo (por defecto: medium)'
    )
    
    parser.add_argument(
        '--precision',
        help='Precisión de entrenamiento (por defecto: 16-mixed)'
    )
    
    args = parser.parse_args()
    
    # Preparar kwargs con valores no-None
    kwargs = {k: v for k, v in vars(args).items() 
              if v is not None and k not in ['dataset_dir', 'checkpoint_base', 'checkpoint_dir']}
    
    success = train_model(
        args.dataset_dir,
        args.checkpoint_base,
        args.checkpoint_dir,
        **kwargs
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
