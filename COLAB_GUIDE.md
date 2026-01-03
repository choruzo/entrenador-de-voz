# 🚀 Entrenamiento en Google Colab

Este documento explica cómo entrenar tu modelo de voz Piper TTS en Google Colab para aprovechar las GPUs gratuitas.

## 📋 Requisitos Previos

1. **Cuenta de Google** (Gmail)
2. **Dataset preprocesado** o dataset crudo con:
   - `metadata.csv` (formato: `wavs/archivo.wav|Texto transcrito`)
   - `wavs/` (archivos de audio WAV)
   - `config.json` (configuración del dataset)

## 🎯 Ventajas de Entrenar en Colab

| Característica | CPU Local | Colab GPU (T4) | Colab GPU (A100) |
|---------------|-----------|----------------|------------------|
| **Tiempo por época** | 30-60 min | 10-30 min | 3-10 min |
| **Costo** | Hardware propio | **Gratis*** | Colab Pro |
| **Configuración** | Manual compleja | Automática | Automática |
| **VRAM disponible** | Variable | 15 GB | 40 GB |
| **Batch size** | 2-4 | 8-16 | 16-32 |

*Límites: ~12 horas de sesión continua, reconectar para seguir

## 📤 Preparar Dataset para Colab

### Opción 1: Dataset Ya Preprocesado

Si ya ejecutaste `preprocess_dataset.sh` localmente:

```bash
# 1. Comprimir dataset preprocesado
cd ~/piper-training/datasets
zip -r sig_preprocessed.zip sig/

# 2. Subir a Google Drive
#    - Ir a https://drive.google.com
#    - Crear carpeta: piper-datasets/
#    - Subir sig_preprocessed.zip
#    - Extraer en Drive (click derecho → Extraer)
```

### Opción 2: Dataset Crudo (se preprocesa en Colab)

```bash
# 1. Comprimir solo lo esencial
cd ~/piper-training/datasets
zip -r sig_raw.zip sig/metadata.csv sig/config.json sig/wavs/

# 2. Subir a Google Drive o subirlo directamente en Colab
```

## 🚀 Usar el Notebook de Colab

### Paso 1: Abrir en Colab

1. Subir `colab_piper_training.ipynb` a tu Google Drive
2. Hacer doble click en el archivo
3. Se abrirá en Google Colaboratory

**O desde GitHub:**
1. Ir a: `https://colab.research.google.com`
2. File → Upload notebook → Seleccionar `colab_piper_training.ipynb`

### Paso 2: Configurar GPU

1. Runtime → Change runtime type
2. Hardware accelerator: **GPU**
3. GPU type: **T4** (gratis) o **A100/V100** (Colab Pro)
4. Save

### Paso 3: Ejecutar Celdas

**Ejecutar en orden:**

```python
# 1️⃣ Verificar GPU
!nvidia-smi  # Debe mostrar una GPU NVIDIA

# 2️⃣ Instalar dependencias (5-10 min)
# Ejecutar todas las celdas de instalación

# 3️⃣ Descargar modelo base (2-3 min)
# Se descarga en_US-lessac-high.ckpt (952 MB)

# 4️⃣ Configurar dataset
# AJUSTAR estas líneas según tu caso:
DRIVE_PATH = "/content/drive/MyDrive/piper-datasets/sig"  # ⬅️ Tu ruta en Drive
DATASET_DIR = "datasets/sig"  # ⬅️ Nombre del dataset

# 5️⃣ Entrenar
MAX_EPOCHS = 100      # ⬅️ Ajustar según necesites
BATCH_SIZE = 16       # ⬅️ Más VRAM = más batch size
CHECKPOINT_EPOCHS = 5 # Guardar cada 5 épocas

# 6️⃣ Monitorear
# Ver gráficas de pérdidas en tiempo real

# 7️⃣ Exportar modelo
# Convierte checkpoint a ONNX

# 8️⃣ Descargar
# Guardar en Drive o descargar ZIP
```

## ⚙️ Configuraciones Recomendadas

### GPU T4 (Gratis)
```python
BATCH_SIZE = 8-16
MAX_EPOCHS = 50-100
# Tiempo: ~10-30 min/época
```

### GPU A100 (Colab Pro)
```python
BATCH_SIZE = 16-32
MAX_EPOCHS = 100-200
# Tiempo: ~3-10 min/época
```

### Para datasets grandes (>1000 muestras)
```python
BATCH_SIZE = 16
VALIDATION_SPLIT = 0.1
CHECKPOINT_EPOCHS = 10  # Guardar menos frecuente
```

### Para datasets pequeños (<500 muestras)
```python
BATCH_SIZE = 4-8
VALIDATION_SPLIT = 0.05
MAX_EPOCHS = 200+  # Necesita más épocas
```

## 💾 Guardar Progreso

El notebook automáticamente guarda:
- ✅ Checkpoints cada N épocas en Drive
- ✅ Métricas de entrenamiento (CSV)
- ✅ Gráficas de pérdidas
- ✅ Modelo ONNX exportado

**Para sesiones largas:**
```python
# Ejecutar en una celda para guardar checkpoints en Drive
import shutil
from datetime import datetime

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
backup_dir = f"/content/drive/MyDrive/piper-checkpoints/backup_{timestamp}"
!mkdir -p "{backup_dir}"
!cp -r {DATASET_DIR}/lightning_logs "{backup_dir}/"
print(f"✅ Backup guardado: {backup_dir}")
```

## 🔄 Continuar Entrenamiento Interrumpido

Si Colab se desconecta, puedes continuar:

```python
# En la celda de entrenamiento, cambiar:
--resume_from_checkpoint models_base/en_US-lessac-high.ckpt

# Por tu último checkpoint:
LAST_CHECKPOINT = "/content/drive/MyDrive/piper-checkpoints/backup_XXXXX/lightning_logs/version_0/checkpoints/epoch=49.ckpt"
!python -m piper_train \
  --resume_from_checkpoint "{LAST_CHECKPOINT}" \
  # ... resto de parámetros
```

## 📊 Interpretar Métricas

Durante el entrenamiento verás:

```
Epoch 10: loss_gen_all=145.3, loss_disc_all=2.1
Epoch 20: loss_gen_all=98.7, loss_disc_all=1.8
Epoch 30: loss_gen_all=67.2, loss_disc_all=1.5
```

**Buenas señales:**
- ✅ `loss_gen_all` disminuye gradualmente
- ✅ `loss_disc_all` se mantiene estable (1.0-3.0)
- ✅ Sin mensajes de error o NaN

**Problemas:**
- ❌ Pérdidas aumentan → learning rate muy alto
- ❌ NaN o Inf → normalización incorrecta del dataset
- ❌ Pérdidas estancadas → learning rate muy bajo o dataset muy pequeño

## 🎵 Probar Modelo Entrenado

Después de exportar:

```python
# En Colab
!pip install piper-tts
!echo "Hola, este es mi modelo entrenado" | piper \
    --model outputs/model.onnx \
    --config outputs/model.onnx.json \
    --output_file test.wav

from IPython.display import Audio
Audio('test.wav')
```

## 📥 Descargar Resultados

El notebook genera:
```
model_trained.zip
├── model.onnx              # Modelo para usar con Piper
├── model.onnx.json         # Configuración del modelo
└── checkpoint/
    └── epoch=99.ckpt       # Checkpoint para continuar entrenamiento
```

**Usar el modelo descargado:**
```bash
# En tu computadora local
cd ~/Downloads
unzip model_trained.zip
echo "Prueba de voz" | piper --model model.onnx --output_file test.wav
```

## 🐛 Solución de Problemas

### Error: "Runtime disconnected"
**Causa:** Sesión inactiva >30 min  
**Solución:** Ejecutar una celda cada 10-15 min, o usar Colab Pro

### Error: "CUDA out of memory"
**Solución:** Reducir `BATCH_SIZE` (probar 8 → 4 → 2)

### Error: "Dataset not found"
**Solución:** Verificar que `DRIVE_PATH` apunta a la ruta correcta en tu Drive

### Entrenamiento muy lento
**Verificar:**
```python
!nvidia-smi  # Debe mostrar GPU en uso
import torch
print(torch.cuda.is_available())  # Debe ser True
```

### Pérdidas en NaN
**Causa:** Dataset mal preprocesado  
**Solución:** Re-ejecutar preprocesamiento o verificar audio corrupto

## 💡 Consejos y Trucos

1. **Usa Colab Pro** si entrenarás frecuentemente (GPU A100, sin límites)
2. **Guarda en Drive regularmente** - Colab puede desconectar sin aviso
3. **Monitorea uso de RAM/VRAM** con `!nvidia-smi` cada 10-15 min
4. **Batch size óptimo:** Usa el máximo que quepa en VRAM sin OOM
5. **No cierres la pestaña** - mantenla abierta aunque minimizada
6. **Activa notificaciones** para saber cuando termine el entrenamiento

## 📚 Recursos Adicionales

- **Documentación Piper:** https://github.com/rhasspy/piper/blob/master/TRAINING.md
- **Colab Tips:** https://colab.research.google.com/notebooks/pro.ipynb
- **Modelos pre-entrenados:** https://huggingface.co/rhasspy/piper-voices

---

## ⏱️ Tiempos Estimados

**Dataset de 700 muestras:**
- Setup inicial: 5-10 min
- Por época (T4): ~15 min
- Por época (A100): ~5 min
- 100 épocas (T4): ~25 horas
- 100 épocas (A100): ~8 horas

**Estrategia recomendada:**
1. Entrenar 20-30 épocas en Colab
2. Probar calidad del modelo
3. Si es bueno, continuar 50-70 épocas más
4. Exportar y descargar

---

¿Necesitas ayuda? Revisa TROUBLESHOOTING.md o abre un issue en GitHub.
