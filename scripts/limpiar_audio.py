#!/usr/bin/env python3
"""
Script para limpiar y normalizar archivos de audio para entrenamiento de Piper.
Procesa archivos WAV para asegurar calidad consistente.
"""

import argparse
import logging
from pathlib import Path
import librosa
import soundfile as sf
import numpy as np
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


def limpiar_audio(input_path, output_path, target_sr=22050, top_db=20):
    """
    Limpia y normaliza un archivo de audio.
    
    Args:
        input_path: Ruta al archivo de entrada
        output_path: Ruta al archivo de salida
        target_sr: Frecuencia de muestreo objetivo (22050 para modelos medium)
        top_db: Umbral en dB para recortar silencios
    """
    try:
        # Cargar audio
        audio, sr = librosa.load(input_path, sr=target_sr, mono=True)
        
        # Verificar que el audio no esté vacío
        if len(audio) == 0:
            logger.error(f"Audio vacío: {input_path}")
            return False
        
        # Normalizar volumen
        audio = librosa.util.normalize(audio)
        
        # Remover silencios al inicio y final
        audio, _ = librosa.effects.trim(audio, top_db=top_db)
        
        # Verificar duración mínima (1 segundo)
        if len(audio) < target_sr:
            logger.warning(f"Audio muy corto (<1s): {input_path}")
        
        # Verificar duración máxima (15 segundos para mejores resultados)
        if len(audio) > target_sr * 15:
            logger.warning(f"Audio largo (>15s): {input_path}. Considera dividirlo.")
        
        # Guardar
        sf.write(output_path, audio, target_sr)
        return True
        
    except Exception as e:
        logger.error(f"Error procesando {input_path}: {e}")
        return False


def procesar_directorio(input_dir, output_dir, target_sr=22050, top_db=20):
    """
    Procesa todos los archivos WAV en un directorio.
    
    Args:
        input_dir: Directorio con archivos de entrada
        output_dir: Directorio para archivos procesados
        target_sr: Frecuencia de muestreo objetivo
        top_db: Umbral para recortar silencios
    """
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    
    # Crear directorio de salida
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Encontrar todos los archivos WAV
    wav_files = list(input_path.glob("*.wav")) + list(input_path.glob("*.WAV"))
    
    if not wav_files:
        logger.error(f"No se encontraron archivos WAV en {input_dir}")
        return
    
    logger.info(f"Encontrados {len(wav_files)} archivos de audio")
    logger.info(f"Frecuencia de muestreo objetivo: {target_sr} Hz")
    
    # Procesar cada archivo
    exitosos = 0
    fallidos = 0
    
    for wav_file in tqdm(wav_files, desc="Procesando audio"):
        output_file = output_path / wav_file.name
        
        if limpiar_audio(wav_file, output_file, target_sr, top_db):
            exitosos += 1
        else:
            fallidos += 1
    
    logger.info(f"\nResumen:")
    logger.info(f"  Exitosos: {exitosos}")
    logger.info(f"  Fallidos: {fallidos}")
    
    if exitosos > 0:
        logger.info(f"\nArchivos procesados guardados en: {output_dir}")


def main():
    parser = argparse.ArgumentParser(
        description="Limpia y normaliza archivos de audio para entrenamiento de Piper"
    )
    parser.add_argument(
        "input_dir",
        help="Directorio con archivos de audio de entrada"
    )
    parser.add_argument(
        "output_dir",
        help="Directorio para archivos de audio procesados"
    )
    parser.add_argument(
        "--sample-rate",
        type=int,
        default=22050,
        help="Frecuencia de muestreo objetivo (default: 22050)"
    )
    parser.add_argument(
        "--top-db",
        type=int,
        default=20,
        help="Umbral en dB para recortar silencios (default: 20)"
    )
    
    args = parser.parse_args()
    
    procesar_directorio(
        args.input_dir,
        args.output_dir,
        args.sample_rate,
        args.top_db
    )


if __name__ == "__main__":
    main()
