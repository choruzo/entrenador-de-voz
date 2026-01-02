#!/usr/bin/env python3
"""
Script de exportación de modelo Piper a formato ONNX

Versión Python compatible con Windows y Linux
"""

import argparse
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


def create_test_script(output_file):
    """Crea un script de prueba para el modelo exportado"""
    output_path = Path(output_file)
    output_dir = output_path.parent
    test_script_path = output_dir / "test_model.py"
    
    test_script = f'''#!/usr/bin/env python3
"""Script de prueba para el modelo exportado"""

import subprocess
import sys
from pathlib import Path

MODEL_FILE = r"{output_path.absolute()}"

def test_model(text=None):
    """Genera y reproduce audio de prueba"""
    if not Path(MODEL_FILE).exists():
        print("Error: Modelo no encontrado")
        return False
    
    # Texto de prueba
    if text is None:
        text = "Hola, soy una voz sintética entrenada con Piper. Este es un mensaje de prueba."
    
    print(f"Generando audio de prueba...")
    print(f"Texto: {{text}}")
    
    output_wav = "prueba.wav"
    
    try:
        # Generar audio con piper
        result = subprocess.run(
            ["piper", "--model", MODEL_FILE, "--output_file", output_wav],
            input=text.encode('utf-8'),
            capture_output=True
        )
        
        if result.returncode != 0:
            print(f"Error generando audio: {{result.stderr.decode()}}")
            return False
        
        print(f"Audio generado: {{output_wav}}")
        
        # Intentar reproducir
        print("Reproduciendo...")
        
        # Intentar diferentes reproductores según el sistema
        players = []
        if sys.platform == 'win32':
            # Windows
            players = [
                ['powershell', '-c', f'(New-Object Media.SoundPlayer "{{output_wav}}").PlaySync()'],
                ['ffplay', '-autoexit', '-nodisp', output_wav]
            ]
        elif sys.platform == 'darwin':
            # macOS
            players = [
                ['afplay', output_wav],
                ['ffplay', '-autoexit', '-nodisp', output_wav]
            ]
        else:
            # Linux
            players = [
                ['aplay', output_wav],
                ['ffplay', '-autoexit', '-nodisp', output_wav],
                ['paplay', output_wav]
            ]
        
        played = False
        for player_cmd in players:
            try:
                subprocess.run(player_cmd, check=True, capture_output=True)
                played = True
                break
            except (FileNotFoundError, subprocess.CalledProcessError):
                continue
        
        if not played:
            print("No se pudo reproducir automáticamente.")
            if sys.platform == 'win32':
                print("Instala ffmpeg o abre prueba.wav manualmente")
            else:
                print("Instala 'aplay', 'paplay' o 'ffplay' para reproducir")
        
        return True
    
    except FileNotFoundError:
        print("Error: 'piper' no está instalado")
        print("Instálalo con: pip install piper-tts")
        return False
    except Exception as e:
        print(f"Error: {{e}}")
        return False

def main():
    """Función principal"""
    text = None
    if len(sys.argv) > 1:
        text = ' '.join(sys.argv[1:])
    
    success = test_model(text)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
'''
    
    with open(test_script_path, 'w', encoding='utf-8') as f:
        f.write(test_script)
    
    # Hacer el script ejecutable en Linux/Mac
    if sys.platform != 'win32':
        test_script_path.chmod(0o755)
    
    return test_script_path


def export_model(checkpoint, output_file):
    """
    Exporta un modelo Piper entrenado a formato ONNX
    
    Args:
        checkpoint: Archivo .ckpt del modelo entrenado
        output_file: Nombre del archivo ONNX de salida
        
    Returns:
        bool: True si fue exitoso, False si falló
    """
    checkpoint_path = Path(checkpoint)
    output_path = Path(output_file)
    
    # Verificar que el checkpoint existe
    if not checkpoint_path.exists():
        print_error(f"Checkpoint no encontrado: {checkpoint}")
        return False
    
    # Verificar extensión del archivo de salida
    if not output_path.suffix == '.onnx':
        print_warning("El archivo de salida debería tener extensión .onnx")
        output_path = output_path.with_suffix('.onnx')
        print_info(f"Usando nombre de archivo: {output_path}")
    
    # Crear directorio de salida
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    print_info("Exportando modelo a ONNX...")
    print_info(f"Checkpoint: {checkpoint}")
    print_info(f"Salida: {output_path}")
    print()
    
    # Exportar modelo
    cmd = [
        sys.executable, '-m', 'piper_train.export_onnx',
        '--checkpoint', str(checkpoint_path),
        '--output', str(output_path)
    ]
    
    try:
        result = subprocess.run(cmd, check=False, capture_output=True, text=True)
        exit_code = result.returncode
        
        # Mostrar output si hay
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
    
    except FileNotFoundError:
        print_error("No se pudo ejecutar piper_train.export_onnx")
        print_info("Asegúrate de que Piper está instalado correctamente")
        return False
    except Exception as e:
        print_error(f"Error ejecutando exportación: {e}")
        return False
    
    if exit_code == 0:
        print()
        print_info("¡Modelo exportado exitosamente!")
        
        # Mostrar información del archivo
        if output_path.exists():
            file_size = output_path.stat().st_size
            if file_size < 1024*1024:
                size_str = f"{file_size:,} bytes"
            else:
                size_str = f"{file_size/(1024*1024):.2f} MB"
            
            print_info(f"Tamaño del modelo: {size_str}")
            
            # Buscar archivo de configuración JSON asociado
            json_file = output_path.with_suffix('.onnx.json')
            if json_file.exists():
                print_info(f"Archivo de configuración: {json_file}")
        
        print()
        print_info("Ahora puedes usar tu modelo con Piper:")
        print()
        
        if sys.platform == 'win32':
            print("  # Instalar Piper (si no lo tienes)")
            print("  pip install piper-tts")
            print()
            print("  # Generar audio de prueba")
            print(f'  echo "Hola, esta es mi voz personalizada." | piper --model {output_path} --output_file prueba.wav')
            print()
            print("  # Reproducir audio")
            print("  prueba.wav  # Abre con reproductor predeterminado")
        else:
            print("  # Instalar Piper (si no lo tienes)")
            print("  pip install piper-tts")
            print()
            print("  # Generar audio de prueba")
            print(f'  echo "Hola, esta es mi voz personalizada." | \\')
            print(f'    piper --model {output_path} --output_file prueba.wav')
            print()
            print("  # Reproducir audio")
            print("  aplay prueba.wav  # Linux")
            print("  ffplay prueba.wav # Con FFmpeg")
        print()
        
        # Crear script de prueba
        test_script = create_test_script(output_path)
        print_info(f"Script de prueba creado: {test_script}")
        print()
        
        if sys.platform == 'win32':
            print(f"  Para probar el modelo: python {test_script}")
            print(f'  O con tu propio texto: python {test_script} "Tu texto aquí"')
        else:
            print(f"  Para probar el modelo: python {test_script}")
            print(f'  O con tu propio texto: python {test_script} "Tu texto aquí"')
        
        return True
    else:
        print()
        print_error(f"La exportación falló con código de salida {exit_code}")
        print_info("Verifica que:")
        print("  1. El checkpoint es válido")
        print("  2. Tienes suficiente espacio en disco")
        print("  3. piper_train está instalado correctamente")
        return False


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(
        description='Exporta modelo Piper a formato ONNX (compatible con Windows y Linux)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  python export.py checkpoints/modelo-epoch-8000.ckpt mi_voz_es.onnx
  python export.py checkpoints/best.ckpt output/mi_modelo.onnx
        """
    )
    
    parser.add_argument(
        'checkpoint',
        help='Archivo .ckpt del modelo entrenado'
    )
    
    parser.add_argument(
        'output_file',
        help='Nombre del archivo ONNX de salida'
    )
    
    args = parser.parse_args()
    
    success = export_model(args.checkpoint, args.output_file)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
