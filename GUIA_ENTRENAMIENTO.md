# Guía de Entrenamiento de Voces Piper en Español

Esta guía te ayudará a entrenar un modelo de voz Piper en español para que suene más fluido y menos robótico, partiendo del modelo base `es_ES-sharvard-medium`.

## Tabla de Contenidos

1. [Requisitos del Sistema](#requisitos-del-sistema)
2. [Instalación de Dependencias](#instalación-de-dependencias)
3. [Preparación del Dataset](#preparación-del-dataset)
4. [Descarga del Modelo Base](#descarga-del-modelo-base)
5. [Preprocesamiento de Datos](#preprocesamiento-de-datos)
6. [Entrenamiento del Modelo](#entrenamiento-del-modelo)
7. [Exportación del Modelo](#exportación-del-modelo)
8. [Optimizaciones para tu Hardware](#optimizaciones-para-tu-hardware)
9. [Consejos para Mejorar la Fluidez](#consejos-para-mejorar-la-fluidez)

## Requisitos del Sistema

### Hardware Recomendado

Tu equipo es adecuado para entrenar modelos Piper:

- **GPU**: AMD Radeon RX 6600 (8GB VRAM) ✅
- **CPU**: AMD Ryzen 5 5600G ✅
- **RAM**: 32GB ✅
- **Almacenamiento**: Al menos 50GB libres

### Software Requerido

- **Sistema Operativo**: Ubuntu 20.04/22.04 LTS (recomendado para ROCm)
- **ROCm**: 6.0+ (para aceleración con GPU AMD)
- **Python**: 3.9 o superior
- **Git**: Para clonar repositorios

## Instalación de Dependencias

### 1. Instalar ROCm (Soporte para GPU AMD)

```bash
# Descargar e instalar ROCm
wget https://repo.radeon.com/amdgpu-install/6.2.2/ubuntu/jammy/amdgpu-install_6.2.60202-1_all.deb
sudo apt install ./amdgpu-install_6.2.60202-1_all.deb

# Instalar ROCm
sudo amdgpu-install --usecase=graphics,rocm

# Agregar usuario a grupos necesarios
sudo usermod -a -G render,video $USER

# Reiniciar el sistema
sudo reboot
```

Después del reinicio, verifica la instalación:

```bash
rocm-smi
```

### 2. Crear Entorno Virtual de Python

```bash
# Instalar virtualenv si no lo tienes
sudo apt install python3-pip python3-venv

# Crear entorno virtual
python3 -m venv venv-piper

# Activar entorno virtual
source venv-piper/bin/activate
```

### 3. Instalar PyTorch con Soporte ROCm

```bash
# Para ROCm 6.0
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
```

Verifica que PyTorch detecta tu GPU:

```bash
python3 -c "import torch; print(f'CUDA disponible: {torch.cuda.is_available()}'); print(f'Dispositivo: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"CPU\"}')"
```

### 4. Instalar Piper Training

```bash
# Clonar el repositorio de Piper
git clone https://github.com/rhasspy/piper.git
cd piper/src/python

# Instalar dependencias de entrenamiento
pip install -e .
pip install piper-phonemize

# Instalar herramientas adicionales
pip install numpy scipy librosa soundfile onnx onnxruntime-gpu
```

### 5. Instalar espeak-ng (para fonemas en español)

```bash
sudo apt-get update
sudo apt-get install espeak-ng
```

## Preparación del Dataset

Para entrenar un modelo que suene más natural, necesitas un dataset de audio de alta calidad en español.

### Opciones de Dataset

#### Opción 1: Grabar tu Propia Voz

**Ventajas**: Control total sobre el estilo y características de la voz
**Desventaja**: Requiere tiempo y equipo de grabación

Requisitos:
- Mínimo: 30-60 minutos de audio limpio
- Recomendado: 2-5 horas para mejor calidad
- Formato: WAV, 22050Hz, mono
- Sin ruido de fondo, reverberación o artefactos

#### Opción 2: Usar Datasets Públicos en Español

Datasets recomendados:
- **Common Voice** (Mozilla): https://commonvoice.mozilla.org/es
- **M-AILABS** (Español): https://www.caito.de/2019/01/the-m-ailabs-speech-dataset/
- **CSS10 Spanish**: https://github.com/Kyubyong/css10

### Estructura del Dataset

Tu dataset debe seguir el formato LJSpeech:

```
mi_dataset/
├── wavs/
│   ├── audio001.wav
│   ├── audio002.wav
│   └── ...
└── metadata.csv
```

**Formato del archivo metadata.csv**:

```csv
audio001|Este es el texto transcrito del primer audio.
audio002|Este es el texto del segundo audio con puntuación correcta.
audio003|Asegúrate de que las transcripciones sean exactas.
```

**Importante**:
- No incluir encabezados en metadata.csv
- Usar pipe `|` como separador
- Las transcripciones deben ser exactas
- Incluir puntuación correcta

### Consejos para Grabaciones de Calidad

Si grabas tu propia voz:

1. **Ambiente silencioso**: Sin ruido de fondo
2. **Micrófono decente**: No necesitas equipamiento profesional, pero evita micrófonos de muy baja calidad
3. **Distancia consistente**: Mantén la misma distancia del micrófono
4. **Tono natural**: Habla naturalmente, no como robot
5. **Variedad de contenido**: Incluye diferentes tipos de frases (preguntas, exclamaciones, declaraciones)
6. **Duración de clips**: Entre 3-10 segundos cada uno

### Script para Limpiar Audio

```python
# limpiar_audio.py
import librosa
import soundfile as sf
import numpy as np
from pathlib import Path

def limpiar_audio(input_path, output_path, target_sr=22050):
    """
    Normaliza y limpia archivos de audio para entrenamiento
    """
    # Cargar audio
    audio, sr = librosa.load(input_path, sr=target_sr)
    
    # Normalizar volumen
    audio = librosa.util.normalize(audio)
    
    # Remover silencios al inicio y final
    audio, _ = librosa.effects.trim(audio, top_db=20)
    
    # Guardar
    sf.write(output_path, audio, target_sr)
    
if __name__ == "__main__":
    input_dir = Path("audio_crudo")
    output_dir = Path("mi_dataset/wavs")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for audio_file in input_dir.glob("*.wav"):
        output_file = output_dir / audio_file.name
        limpiar_audio(audio_file, output_file)
        print(f"Procesado: {audio_file.name}")
```

## Descarga del Modelo Base

Para hacer transfer learning desde `es_ES-sharvard-medium`:

```bash
# Crear directorio para modelos
mkdir -p modelos_base
cd modelos_base

# Descargar modelo base desde Hugging Face
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium/es_ES-sharvard-medium.ckpt

# También descargar el archivo de configuración
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx.json

cd ..
```

**Nota**: Si los enlaces no funcionan, puedes explorar el repositorio completo en:
https://huggingface.co/rhasspy/piper-voices/tree/main/es/es_ES/sharvard/medium

## Preprocesamiento de Datos

El preprocesamiento convierte tu audio y texto a un formato que Piper puede usar para entrenar.

### Usando el Script Automatizado

```bash
# Usar el script proporcionado en este repositorio
./scripts/preprocess.sh mi_dataset dataset_procesado es-es
```

### Comando Manual

```bash
python -m piper_train.preprocess \
    --language es-es \
    --input-dir mi_dataset \
    --output-dir dataset_procesado \
    --dataset-format ljspeech \
    --single-speaker \
    --sample-rate 22050
```

**Parámetros importantes**:
- `--language es-es`: Idioma español
- `--single-speaker`: Para una sola voz (usa `--multi-speaker` si tienes múltiples voces)
- `--sample-rate 22050`: Frecuencia de muestreo para modelos "medium"

Esto generará:
- `dataset_procesado/phonemes.txt`: Texto convertido a fonemas
- `dataset_procesado/config.json`: Configuración del dataset
- Archivos procesados listos para entrenamiento

## Entrenamiento del Modelo

### Usando el Script Automatizado

```bash
# Entrenar con configuración optimizada para tu hardware
./scripts/train.sh dataset_procesado modelos_base/es_ES-sharvard-medium.ckpt
```

### Comando Manual

```bash
python -m piper_train \
    --dataset-dir dataset_procesado \
    --accelerator gpu \
    --devices 1 \
    --batch-size 8 \
    --validation-split 0.05 \
    --num-test-examples 5 \
    --max_epochs 10000 \
    --checkpoint-epochs 1000 \
    --precision 16-mixed \
    --resume-from-checkpoint modelos_base/es_ES-sharvard-medium.ckpt \
    --quality medium
```

**Parámetros clave para tu RX 6600**:

- `--batch-size 8`: Ajustado para 8GB de VRAM. Si tienes errores de memoria, reduce a 4 o 6
- `--precision 16-mixed`: Usa precisión mixta para ahorrar memoria
- `--checkpoint-epochs 1000`: Guarda checkpoints cada 1000 épocas
- `--max_epochs 10000`: Número máximo de épocas (puedes ajustar)

### Monitoreo del Entrenamiento

El entrenamiento mostrará algo como:

```
Epoch 1000/10000 [=====>....] Loss: 0.234 | Val Loss: 0.267
```

**Cuándo parar**:
- Cuando la pérdida de validación deje de mejorar (early stopping)
- Típicamente entre 5,000-15,000 épocas dependiendo del tamaño del dataset
- Para transfer learning, puede converger más rápido (3,000-8,000 épocas)

### Tiempo de Entrenamiento Estimado

Con tu hardware:
- Dataset pequeño (30 min): ~2-4 horas
- Dataset mediano (2 horas): ~8-16 horas
- Dataset grande (5 horas): ~24-48 horas

## Exportación del Modelo

Una vez completado el entrenamiento:

### Usando el Script Automatizado

```bash
./scripts/export.sh checkpoints/modelo_final.ckpt mi_voz_es.onnx
```

### Comando Manual

```bash
python -m piper_train.export_onnx \
    --checkpoint-path checkpoints/modelo_final.ckpt \
    --output-file mi_voz_es.onnx
```

### Probar el Modelo

```bash
# Instalar piper para inferencia si no lo tienes
pip install piper-tts

# Generar audio de prueba
echo "Hola, este es mi nuevo modelo de voz entrenado." | \
    piper --model mi_voz_es.onnx --output_file prueba.wav

# Reproducir
aplay prueba.wav  # En Linux
# o
ffplay prueba.wav
```

## Optimizaciones para tu Hardware

### Para AMD Radeon RX 6600 (8GB VRAM)

1. **Ajustar Batch Size**:
   - Comienza con `batch-size 8`
   - Si tienes errores de memoria: reduce a 6 o 4
   - Si funciona bien y VRAM no está al máximo: prueba 12 o 16

2. **Usar Mixed Precision**:
   - Siempre usa `--precision 16-mixed` con ROCm
   - Reduce uso de memoria y acelera entrenamiento

3. **Gradient Accumulation** (si batch size muy pequeño):
   ```bash
   --accumulate-grad-batches 2
   ```
   Esto simula batch size más grande

4. **Liberar Caché de GPU**:
   Si tienes problemas de memoria, agrega al script de Python:
   ```python
   torch.cuda.empty_cache()
   ```

### Variables de Entorno Útiles

```bash
# Optimizaciones para ROCm
export HSA_OVERRIDE_GFX_VERSION=10.3.0  # Para RX 6600
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:512

# Monitorear GPU durante entrenamiento
watch -n 1 rocm-smi
```

## Consejos para Mejorar la Fluidez

### 1. Calidad del Dataset

**Más importante que la cantidad**:
- 1 hora de audio perfecto > 5 horas de audio con ruido
- Mantén consistencia en:
  - Tono de voz
  - Velocidad de habla
  - Distancia del micrófono
  - Ambiente de grabación

### 2. Variedad en el Dataset

Incluye:
- Diferentes tipos de frases (afirmativas, interrogativas, exclamativas)
- Palabras comunes y palabras raras
- Números y fechas
- Abreviaciones comunes
- Emociones variadas (neutro, alegre, serio)

### 3. Transcripciones Precisas

- Usa puntuación correcta (., ?, !, ,)
- La puntuación afecta la entonación
- Transcribe exactamente lo que se dice
- Incluye pausas naturales con comas

### 4. Transfer Learning es Clave

Partir de `es_ES-sharvard-medium`:
- Reduce tiempo de entrenamiento
- Mejora calidad con menos datos
- El modelo ya conoce español
- Solo necesitas "ajustar" con tu voz/estilo

### 5. Ajuste de Hiperparámetros

Si el modelo suena robótico:
- Entrena más épocas (no sobre-entrenes)
- Aumenta el tamaño del dataset
- Revisa la calidad del audio
- Ajusta learning rate:
  ```bash
  --learning-rate 1e-4  # Por defecto es 1e-3
  ```

### 6. Post-procesamiento

Después de generar audio con Piper:
- Normaliza volumen
- Aplica ecualización suave
- Agrega reverb muy ligero (opcional, para más naturalidad)

Ejemplo con `sox`:
```bash
sox input.wav output.wav \
    norm -1 \
    equalizer 100 1q +2 \
    reverb 20 50 80 0 0 2
```

### 7. Prosodia y Entonación

Para mejorar la prosodia:
- Asegúrate de que las frases de entrenamiento tengan buena entonación natural
- No leas en tono monótono durante la grabación
- Usa signos de puntuación apropiados en las transcripciones
- Considera agregar símbolos SSML en el texto si Piper los soporta

### 8. Evaluación Continua

Durante el entrenamiento:
1. Genera muestras cada 1000 épocas
2. Escucha la evolución
3. Compara con el modelo base
4. Para cuando la mejora sea marginal

### 9. Configuraciones Avanzadas

Edita el archivo de configuración del modelo (`config.json`):
```json
{
  "audio": {
    "sample_rate": 22050,
    "filter_length": 1024,
    "hop_length": 256,
    "win_length": 1024
  },
  "inference": {
    "noise_scale": 0.667,      // Afecta variabilidad
    "length_scale": 1.0,       // Velocidad (1.0 = normal)
    "noise_w": 0.8             // Variación en duración
  }
}
```

Puedes ajustar estos valores durante la inferencia:
- `noise_scale`: 0.5 (menos variación) a 1.0 (más natural)
- `length_scale`: 0.8 (más rápido) a 1.2 (más lento)

## Solución de Problemas

### Error: GPU no detectada

```bash
# Verificar ROCm
rocm-smi

# Verificar PyTorch
python -c "import torch; print(torch.cuda.is_available())"

# Si es False, reinstala PyTorch con ROCm
pip uninstall torch
pip install torch --index-url https://download.pytorch.org/whl/rocm6.0
```

### Error: Out of Memory

1. Reduce batch size: `--batch-size 4`
2. Reduce longitud de secuencia en config
3. Cierra otros programas que usen GPU

### Error: Modelo suena robótico

1. Entrena más épocas
2. Mejora calidad del dataset
3. Verifica transcripciones
4. Aumenta tamaño del dataset
5. Ajusta parámetros de inferencia (noise_scale, length_scale)

### Audio de Entrenamiento con Ruido

Usa herramientas de limpieza:
```bash
# Con ffmpeg
ffmpeg -i input.wav -af "highpass=f=200, lowpass=f=3000" output.wav

# Con sox
sox input.wav output.wav noisered noise_profile.txt 0.21
```

## Recursos Adicionales

### Documentación Oficial
- Piper GitHub: https://github.com/rhasspy/piper
- Guía de Entrenamiento: https://github.com/rhasspy/piper/blob/master/TRAINING.md
- ROCm Documentation: https://rocm.docs.amd.com/

### Comunidad
- Discord de Rhasspy: https://discord.gg/rhasspy
- Foro de Home Assistant (usa Piper): https://community.home-assistant.io/

### Modelos Pre-entrenados
- Hugging Face - Piper Voices: https://huggingface.co/rhasspy/piper-voices
- Explorar modelos en español: https://rhasspy.github.io/piper-samples/

### Datasets en Español
- Common Voice: https://commonvoice.mozilla.org/es
- VoxPopuli: https://github.com/facebookresearch/voxpopuli
- CSS10 Spanish: https://github.com/Kyubyong/css10

## Conclusión

Entrenar un modelo Piper personalizado requiere paciencia, pero con tu hardware (RX 6600, 32GB RAM) es totalmente factible. Los puntos clave son:

1. **Calidad sobre cantidad** en el dataset
2. **Transfer learning** desde es_ES-sharvard-medium
3. **Paciencia** durante el entrenamiento
4. **Iteración** y ajustes basados en resultados

¡Buena suerte con tu entrenamiento! Si tienes dudas o problemas, consulta la comunidad de Rhasspy o abre un issue en este repositorio.
