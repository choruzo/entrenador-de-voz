# Guía de Uso en Windows

Esta guía te ayudará a usar el entrenador de voces Piper TTS en Windows 11.

## 📋 Requisitos Previos

### 1. Instalar Python

1. Descarga Python 3.9 o superior desde [python.org](https://www.python.org/downloads/)
2. Durante la instalación, **marca la casilla "Add Python to PATH"**
3. Verifica la instalación abriendo PowerShell o CMD:
   ```powershell
   python --version
   ```

### 2. Instalar Git

1. Descarga Git desde [git-scm.com](https://git-scm.com/download/win)
2. Instala con las opciones predeterminadas
3. Verifica la instalación:
   ```powershell
   git --version
   ```

### 3. Instalar espeak-ng

1. Descarga desde [GitHub Releases](https://github.com/espeak-ng/espeak-ng/releases)
2. Instala y asegúrate de agregarlo al PATH de Windows
3. Verifica la instalación:
   ```powershell
   espeak-ng --version
   ```

### 4. GPU (Opcional pero Recomendado)

Para entrenamiento con GPU NVIDIA:
1. Descarga e instala [CUDA Toolkit 12.1](https://developer.nvidia.com/cuda-downloads)
2. Los drivers de NVIDIA deben estar actualizados

**Nota:** Las GPU AMD en Windows tienen soporte limitado. Para GPU AMD, se recomienda usar Linux o WSL.

## 🚀 Instalación

### Paso 1: Clonar el Repositorio

Abre PowerShell o CMD y ejecuta:

```powershell
git clone https://github.com/choruzo/entrenador-de-voz.git
cd entrenador-de-voz
```

### Paso 2: Configuración Inicial

Ejecuta el script de configuración:

```powershell
python scripts\setup.py
```

Este script:
- Creará un entorno virtual en `%USERPROFILE%\piper-training\venv-piper`
- Instalará PyTorch con soporte GPU (si tienes NVIDIA) o CPU
- Instalará todas las dependencias necesarias
- Descargará el modelo base en español

**Opciones adicionales:**
```powershell
# Especificar directorio de trabajo personalizado
python scripts\setup.py --work-dir C:\MiEntrenamiento

# Forzar instalación solo para CPU
python scripts\setup.py --cpu-only
```

### Paso 3: Activar el Entorno

Después de la configuración, activa el entorno virtual:

```powershell
cd %USERPROFILE%\piper-training
.\venv-piper\Scripts\activate
```

También puedes usar el script de activación:
```powershell
.\env_setup.bat
```

## 📝 Uso Básico

### 1. Preparar tu Dataset

Crea un dataset en formato LJSpeech:

```
mi_dataset\
├── wavs\
│   ├── audio001.wav
│   ├── audio002.wav
│   └── ...
└── metadata.csv
```

**Formato de metadata.csv** (sin encabezado):
```
audio001|Este es el texto del primer audio.
audio002|Texto del segundo audio con puntuación correcta.
audio003|Cada línea debe tener el nombre del archivo y su transcripción.
```

### 2. Validar el Dataset

```powershell
python scripts\validar_dataset.py mi_dataset
```

### 3. Preprocesar los Datos

```powershell
python scripts\preprocess.py mi_dataset dataset_procesado --language es-es
```

### 4. Entrenar el Modelo

```powershell
# Con transfer learning (recomendado)
python scripts\train.py dataset_procesado %USERPROFILE%\piper-training\models_base\es_ES-sharvard-medium.ckpt

# Desde cero (no recomendado)
python scripts\train.py dataset_procesado

# Con parámetros personalizados
python scripts\train.py dataset_procesado --batch-size 4 --max-epochs 5000 --quality low
```

**Parámetros importantes:**
- `--batch-size`: Reduce si tienes poca VRAM (4 para 8GB, 2 para 4GB)
- `--max-epochs`: Número de épocas de entrenamiento
- `--quality`: `x_low`, `low`, `medium` (default), `high`
- `--checkpoint-dir`: Donde guardar los checkpoints

### 5. Exportar el Modelo

Después del entrenamiento, exporta el modelo a formato ONNX:

```powershell
python scripts\export.py checkpoints\modelo-epoch-8000.ckpt mi_voz_es.onnx
```

### 6. Probar tu Modelo

Instala piper-tts si no lo tienes:
```powershell
pip install piper-tts
```

Genera audio de prueba:
```powershell
echo "Hola, esta es mi voz personalizada con Piper TTS" | piper --model mi_voz_es.onnx --output_file prueba.wav
```

Reproduce el audio:
```powershell
# Abre con el reproductor predeterminado
start prueba.wav

# O con un script de Python
python -c "import winsound; winsound.PlaySound('prueba.wav', winsound.SND_FILENAME)"
```

También puedes usar el script de prueba generado automáticamente:
```powershell
python test_model.py
python test_model.py "Tu texto personalizado aquí"
```

## 🔧 Solución de Problemas

### Error: "python no se reconoce como comando"

**Solución:** Python no está en el PATH. Reinstala Python y marca "Add Python to PATH".

### Error: "espeak-ng no se reconoce como comando"

**Solución:** 
1. Verifica que espeak-ng esté instalado
2. Agrega manualmente al PATH:
   - Busca "Variables de entorno" en Windows
   - Edita la variable PATH
   - Agrega la ruta de instalación de espeak-ng (ej: `C:\Program Files\eSpeak NG`)

### Error: "Out of Memory" durante el entrenamiento

**Soluciones:**
1. Reduce el batch size: `--batch-size 4` o `--batch-size 2`
2. Reduce la calidad del modelo: `--quality low`
3. Cierra otras aplicaciones que usen GPU
4. Usa CPU si tu GPU es muy pequeña: edita el script train.py y cambia `--accelerator gpu` por `--accelerator cpu`

### El entrenamiento es muy lento

**Causas comunes:**
1. Estás usando CPU en lugar de GPU
2. Tu GPU no es compatible o no tiene drivers actualizados
3. PyTorch no detecta tu GPU

**Verificación:**
```powershell
python -c "import torch; print('CUDA:', torch.cuda.is_available())"
```

Si dice `CUDA: False`, revisa la instalación de CUDA y drivers.

### Error de codificación UTF-8

**Solución:** Asegúrate de que tu archivo `metadata.csv` esté guardado con codificación UTF-8 (sin BOM). En el Bloc de notas, guarda como "UTF-8" no "UTF-8 con BOM".

## 💡 Consejos

### Para Mejores Resultados

1. **Calidad del audio:**
   - Usa audio limpio sin ruido de fondo
   - Frecuencia de muestreo: 22050 Hz (recomendado) o 44100 Hz
   - Formato mono (no estéreo)
   - Duración ideal: 2-10 segundos por archivo

2. **Dataset:**
   - Mínimo: 30 minutos de audio (transfer learning)
   - Recomendado: 2-4 horas
   - Óptimo: 10+ horas
   - La calidad es más importante que la cantidad

3. **Transcripciones:**
   - Deben ser exactas (incluyendo puntuación)
   - Usa tildes y caracteres especiales correctos
   - Incluye signos de puntuación apropiados

4. **Entrenamiento:**
   - Usa transfer learning con el modelo base en español
   - Monitorea el progreso regularmente
   - Guarda checkpoints frecuentemente
   - Para en cuando la pérdida (loss) deje de mejorar

### Monitorear el Entrenamiento

Durante el entrenamiento, puedes monitorear el progreso:

```powershell
# Ver el log en tiempo real
Get-Content checkpoints\training.log -Wait -Tail 20

# Ver estado de GPU (NVIDIA)
nvidia-smi

# O usar el monitor automático
python checkpoints\monitor.py
```

## 📚 Recursos Adicionales

- [Guía completa de entrenamiento](GUIA_ENTRENAMIENTO.md)
- [Documentación de Piper](https://github.com/rhasspy/piper)
- [Solución de problemas](TROUBLESHOOTING.md)
- [Modelos pre-entrenados](https://huggingface.co/rhasspy/piper-voices)

## 🆘 Obtener Ayuda

Si encuentras problemas:

1. Revisa esta guía y [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Busca en los [Issues de GitHub](https://github.com/choruzo/entrenador-de-voz/issues)
3. Abre un nuevo Issue con:
   - Tu versión de Windows
   - Versión de Python
   - Mensaje de error completo
   - Pasos para reproducir el problema

---

¡Feliz entrenamiento! 🎙️
