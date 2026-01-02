#!/usr/bin/env python3
"""
Script de preprocesamiento de datos para Piper
Convierte audio y texto al formato requerido para entrenamiento

Versión Python compatible con Windows y Linux
"""

import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Configurar logging con colores
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


def check_espeak_ng():
    """Verifica que espeak-ng esté instalado"""
    if shutil.which('espeak-ng') is None:
        print_error("espeak-ng no está instalado")
        if sys.platform == 'win32':
            print_info("Descarga espeak-ng desde: https://github.com/espeak-ng/espeak-ng/releases")
            print_info("Asegúrate de agregarlo al PATH de Windows")
        else:
            print_info("Instálalo con: sudo apt-get install espeak-ng")
        return False
    return True


def count_files(directory, extensions):
    """Cuenta archivos con extensiones específicas"""
    count = 0
    for ext in extensions:
        count += len(list(directory.glob(f"*.{ext}")))
    return count


def detect_speaker_type(metadata_path):
    """Detecta si el dataset es single-speaker o multi-speaker"""
    try:
        with open(metadata_path, 'r', encoding='utf-8') as f:
            first_line = f.readline().strip()
            num_pipes = first_line.count('|')
            
            if num_pipes == 1:
                return '--single-speaker', 'un solo hablante'
            elif num_pipes == 2:
                return '', 'multi-hablante'
            else:
                return None, None
    except Exception as e:
        print_error(f"Error leyendo metadata.csv: {e}")
        return None, None


def preprocess_dataset(input_dir, output_dir, language='es-es'):
    """
    Preprocesa un dataset para entrenamiento con Piper
    
    Args:
        input_dir: Directorio del dataset en formato LJSpeech
        output_dir: Directorio donde guardar los datos procesados
        language: Código de idioma (default: es-es)
        
    Returns:
        bool: True si fue exitoso, False si falló
    """
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    
    # Verificar que el directorio de entrada existe
    if not input_path.exists():
        print_error(f"El directorio de entrada no existe: {input_dir}")
        return False
    
    # Verificar estructura del dataset
    wavs_dir = input_path / "wavs"
    metadata_path = input_path / "metadata.csv"
    
    if not wavs_dir.exists():
        print_error(f"No se encontró el directorio 'wavs' en {input_dir}")
        print_info("El dataset debe tener la estructura:")
        print(f"  {input_dir}/")
        print(f"  ├── wavs/")
        print(f"  └── metadata.csv")
        return False
    
    if not metadata_path.exists():
        print_error(f"No se encontró metadata.csv en {input_dir}")
        return False
    
    # Contar archivos de audio
    num_wavs = count_files(wavs_dir, ['wav', 'WAV'])
    print_info(f"Archivos de audio encontrados: {num_wavs}")
    
    if num_wavs == 0:
        print_error(f"No se encontraron archivos .wav en {wavs_dir}")
        return False
    
    # Contar líneas en metadata.csv
    try:
        with open(metadata_path, 'r', encoding='utf-8') as f:
            num_lines = sum(1 for line in f if line.strip())
        print_info(f"Líneas en metadata.csv: {num_lines}")
    except Exception as e:
        print_error(f"Error leyendo metadata.csv: {e}")
        return False
    
    if num_wavs != num_lines:
        print_warning(f"Número de archivos WAV ({num_wavs}) no coincide con líneas en metadata ({num_lines})")
        print_warning("Asegúrate de que cada archivo de audio tenga su entrada en metadata.csv")
    
    # Verificar que espeak-ng está instalado
    if not check_espeak_ng():
        return False
    
    # Crear directorio de salida
    output_path.mkdir(parents=True, exist_ok=True)
    
    print_info("Iniciando preprocesamiento...")
    print_info(f"Dataset de entrada: {input_dir}")
    print_info(f"Dataset de salida: {output_dir}")
    print_info(f"Idioma: {language}")
    print()
    
    # Detectar tipo de dataset
    speaker_flag, speaker_type = detect_speaker_type(metadata_path)
    if speaker_flag is None:
        print_error("Formato de metadata.csv no reconocido")
        print_info("Formatos válidos:")
        print("  Single-speaker: archivo|transcripción")
        print("  Multi-speaker:  archivo|hablante|transcripción")
        return False
    
    print_info(f"Detectado: Dataset de {speaker_type}")
    
    # Ejecutar preprocesamiento con Piper
    print_info("Ejecutando preprocesamiento de Piper...")
    print()
    
    cmd = [
        sys.executable, '-m', 'piper_train.preprocess',
        '--language', language,
        '--input-dir', str(input_path),
        '--output-dir', str(output_path),
        '--dataset-format', 'ljspeech',
        '--sample-rate', '22050'
    ]
    
    if speaker_flag:
        cmd.append(speaker_flag)
    
    try:
        result = subprocess.run(cmd, check=False)
        exit_code = result.returncode
    except FileNotFoundError:
        print_error("No se pudo ejecutar piper_train.preprocess")
        print_info("Asegúrate de que Piper está instalado correctamente")
        print_info("Instalación: cd piper/src/python && pip install -e .")
        return False
    except Exception as e:
        print_error(f"Error ejecutando preprocesamiento: {e}")
        return False
    
    if exit_code == 0:
        print()
        print_info("¡Preprocesamiento completado exitosamente!")
        print_info(f"Dataset procesado guardado en: {output_dir}")
        print()
        
        # Mostrar estadísticas
        config_path = output_path / "config.json"
        if config_path.exists():
            print_info("Archivos generados:")
            for item in output_path.iterdir():
                if item.is_file():
                    size = item.stat().st_size
                    size_str = f"{size:,} bytes" if size < 1024*1024 else f"{size/(1024*1024):.2f} MB"
                    print(f"  {item.name} ({size_str})")
            print()
            
            try:
                with open(config_path, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                
                print_info("Información del dataset:")
                if 'audio' in config:
                    sample_rate = config['audio'].get('sample_rate', 'N/A')
                    print(f"  Frecuencia de muestreo: {sample_rate} Hz")
                
                if 'num_speakers' in config:
                    print(f"  Número de hablantes: {config['num_speakers']}")
                
                print(f"  Dataset listo para entrenamiento")
            except Exception as e:
                print_info(f"  No se pudo leer la configuración: {e}")
        
        print()
        print_info("Siguiente paso: Entrenar el modelo")
        if sys.platform == 'win32':
            print(f"  python scripts\\train.py {output_dir} modelos_base\\es_ES-sharvard-medium.ckpt")
        else:
            print(f"  python scripts/train.py {output_dir} modelos_base/es_ES-sharvard-medium.ckpt")
        return True
    else:
        print()
        print_error(f"El preprocesamiento falló con código de salida {exit_code}")
        print_info("Verifica que:")
        print("  1. El formato de metadata.csv es correcto")
        print("  2. Los archivos de audio existen y son válidos")
        print("  3. espeak-ng está instalado correctamente")
        return False


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(
        description='Preprocesamiento de datos para Piper (compatible con Windows y Linux)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  python preprocess.py mi_dataset dataset_procesado
  python preprocess.py mi_dataset dataset_procesado --language es-es

Estructura esperada del dataset:
  mi_dataset/
  ├── wavs/
  │   ├── audio001.wav
  │   └── ...
  └── metadata.csv

Formato de metadata.csv:
  Single-speaker: archivo|transcripción
  Multi-speaker:  archivo|hablante|transcripción
        """
    )
    
    parser.add_argument(
        'input_dir',
        help='Ruta al dataset en formato LJSpeech'
    )
    
    parser.add_argument(
        'output_dir',
        help='Donde guardar los datos procesados'
    )
    
    parser.add_argument(
        '--language',
        default='es-es',
        help='Código de idioma (por defecto: es-es)'
    )
    
    args = parser.parse_args()
    
    success = preprocess_dataset(args.input_dir, args.output_dir, args.language)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
