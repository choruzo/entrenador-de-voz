#!/usr/bin/env python3
"""
Herramienta para validar dataset antes del entrenamiento.
Verifica la estructura, formato y calidad de los datos.
"""

import argparse
import csv
import logging
from pathlib import Path
import librosa

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


def validar_metadata(metadata_path, wavs_dir):
    """
    Valida el archivo metadata.csv.
    
    Returns:
        tuple: (es_valido, num_entradas, errores)
    """
    errores = []
    entradas = []
    
    try:
        with open(metadata_path, 'r', encoding='utf-8') as f:
            # Detectar si tiene encabezados
            primera_linea = f.readline().strip()
            if '|' not in primera_linea:
                errores.append("metadata.csv debe usar '|' como separador")
                return False, 0, errores
            
            # Verificar si parece un encabezado
            if primera_linea.lower().startswith('file') or primera_linea.lower().startswith('audio'):
                logger.warning("Posible encabezado detectado en metadata.csv")
                logger.warning("metadata.csv NO debe tener encabezados")
            
            # Reiniciar lectura
            f.seek(0)
            
            for i, linea in enumerate(f, 1):
                linea = linea.strip()
                if not linea:
                    continue
                
                partes = linea.split('|')
                
                # Verificar formato
                if len(partes) == 2:
                    # Formato single-speaker: archivo|transcripcion
                    archivo, transcripcion = partes
                    speaker = None
                elif len(partes) == 3:
                    # Formato multi-speaker: archivo|speaker|transcripcion
                    archivo, speaker, transcripcion = partes
                else:
                    errores.append(f"Línea {i}: formato inválido (debe tener 2 o 3 campos)")
                    continue
                
                # Verificar que el archivo existe
                archivo_completo = wavs_dir / f"{archivo}.wav"
                if not archivo_completo.exists():
                    # Intentar con extensión .WAV
                    archivo_completo = wavs_dir / f"{archivo}.WAV"
                    if not archivo_completo.exists():
                        errores.append(f"Línea {i}: archivo no encontrado: {archivo}.wav")
                        continue
                
                # Verificar transcripción no vacía
                if not transcripcion.strip():
                    errores.append(f"Línea {i}: transcripción vacía para {archivo}")
                
                entradas.append({
                    'archivo': archivo,
                    'speaker': speaker,
                    'transcripcion': transcripcion,
                    'linea': i
                })
    
    except FileNotFoundError:
        errores.append(f"No se encontró metadata.csv en {metadata_path}")
        return False, 0, errores
    except Exception as e:
        errores.append(f"Error leyendo metadata.csv: {e}")
        return False, 0, errores
    
    return len(errores) == 0, len(entradas), errores


def validar_audio(wavs_dir, sample_rate_esperado=22050):
    """
    Valida archivos de audio.
    
    Returns:
        tuple: (avisos, estadisticas)
    """
    avisos = []
    estadisticas = {
        'total': 0,
        'duracion_total': 0,
        'duracion_min': float('inf'),
        'duracion_max': 0,
        'sample_rates': set()
    }
    
    wav_files = list(wavs_dir.glob("*.wav")) + list(wavs_dir.glob("*.WAV"))
    
    for wav_file in wav_files:
        try:
            # Cargar solo para obtener metadata (rápido)
            duration = librosa.get_duration(path=str(wav_file))
            y, sr = librosa.load(wav_file, sr=None, duration=0.1)  # Solo cargar 0.1s
            
            estadisticas['total'] += 1
            estadisticas['duracion_total'] += duration
            estadisticas['duracion_min'] = min(estadisticas['duracion_min'], duration)
            estadisticas['duracion_max'] = max(estadisticas['duracion_max'], duration)
            estadisticas['sample_rates'].add(sr)
            
            # Verificaciones
            if sr != sample_rate_esperado:
                avisos.append(f"{wav_file.name}: sample rate {sr} Hz (esperado: {sample_rate_esperado} Hz)")
            
            if duration < 0.5:
                avisos.append(f"{wav_file.name}: muy corto ({duration:.2f}s)")
            
            if duration > 15:
                avisos.append(f"{wav_file.name}: muy largo ({duration:.2f}s) - considera dividirlo")
        
        except Exception as e:
            avisos.append(f"{wav_file.name}: error al procesar - {e}")
    
    return avisos, estadisticas


def validar_dataset(dataset_dir, sample_rate=22050):
    """
    Valida un dataset completo para Piper.
    """
    dataset_path = Path(dataset_dir)
    
    logger.info(f"Validando dataset: {dataset_dir}")
    logger.info("=" * 60)
    
    # Verificar estructura
    wavs_dir = dataset_path / "wavs"
    metadata_path = dataset_path / "metadata.csv"
    
    errores_criticos = []
    advertencias = []
    
    # 1. Verificar que existe directorio wavs
    if not wavs_dir.exists():
        errores_criticos.append("No se encontró el directorio 'wavs'")
    
    # 2. Verificar que existe metadata.csv
    if not metadata_path.exists():
        errores_criticos.append("No se encontró 'metadata.csv'")
    
    if errores_criticos:
        logger.error("Errores críticos encontrados:")
        for error in errores_criticos:
            logger.error(f"  - {error}")
        logger.error("\nEstructura esperada:")
        logger.error(f"  {dataset_dir}/")
        logger.error(f"  ├── wavs/")
        logger.error(f"  │   ├── audio001.wav")
        logger.error(f"  │   └── ...")
        logger.error(f"  └── metadata.csv")
        return False
    
    # 3. Validar metadata.csv
    logger.info("\n1. Validando metadata.csv...")
    metadata_valido, num_entradas, errores_metadata = validar_metadata(metadata_path, wavs_dir)
    
    if errores_metadata:
        logger.error("Errores en metadata.csv:")
        for error in errores_metadata[:10]:  # Mostrar solo primeros 10
            logger.error(f"  - {error}")
        if len(errores_metadata) > 10:
            logger.error(f"  ... y {len(errores_metadata) - 10} errores más")
    else:
        logger.info(f"✓ metadata.csv válido ({num_entradas} entradas)")
    
    # 4. Validar archivos de audio
    logger.info("\n2. Validando archivos de audio...")
    avisos_audio, stats = validar_audio(wavs_dir, sample_rate)
    
    if stats['total'] == 0:
        logger.error("No se encontraron archivos de audio")
        return False
    
    logger.info(f"✓ Archivos de audio: {stats['total']}")
    
    if stats['duracion_total'] > 0:
        duracion_promedio = stats['duracion_total'] / stats['total']
        duracion_horas = stats['duracion_total'] / 3600
        
        logger.info(f"  Duración total: {duracion_horas:.2f} horas")
        logger.info(f"  Duración promedio: {duracion_promedio:.2f}s")
        logger.info(f"  Duración mínima: {stats['duracion_min']:.2f}s")
        logger.info(f"  Duración máxima: {stats['duracion_max']:.2f}s")
        
        if len(stats['sample_rates']) > 1:
            logger.warning(f"  ⚠ Múltiples sample rates detectados: {stats['sample_rates']}")
            logger.warning(f"    Se recomienda normalizar todos a {sample_rate} Hz")
        
        # Recomendaciones según duración
        if duracion_horas < 0.5:
            logger.warning("\n⚠ Dataset pequeño (<30 min)")
            logger.warning("  Recomendación: Graba más audio para mejores resultados")
        elif duracion_horas < 2:
            logger.info("\n✓ Tamaño de dataset adecuado para transfer learning")
        else:
            logger.info("\n✓ Buen tamaño de dataset")
    
    # Mostrar algunos avisos
    if avisos_audio:
        logger.info(f"\n3. Avisos de calidad de audio ({len(avisos_audio)} total):")
        for aviso in avisos_audio[:5]:
            logger.warning(f"  - {aviso}")
        if len(avisos_audio) > 5:
            logger.info(f"  ... y {len(avisos_audio) - 5} avisos más")
    
    # Resumen final
    logger.info("\n" + "=" * 60)
    if metadata_valido and not errores_criticos and stats['total'] > 0:
        logger.info("✓ Dataset válido y listo para preprocesamiento")
        logger.info("\nSiguiente paso:")
        logger.info(f"  ./scripts/preprocess.sh {dataset_dir} dataset_procesado es-es")
        return True
    else:
        logger.error("✗ Dataset tiene errores que deben corregirse")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Valida un dataset de Piper antes del entrenamiento"
    )
    parser.add_argument(
        "dataset_dir",
        help="Directorio del dataset a validar"
    )
    parser.add_argument(
        "--sample-rate",
        type=int,
        default=22050,
        help="Sample rate esperado (default: 22050)"
    )
    
    args = parser.parse_args()
    
    exito = validar_dataset(args.dataset_dir, args.sample_rate)
    exit(0 if exito else 1)


if __name__ == "__main__":
    main()
