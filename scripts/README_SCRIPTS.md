# Scripts de Bash para Piper Training en Ubuntu

Este conjunto de scripts convierte el notebook de Google Colab en scripts bash modulares para entrenar modelos de voz Piper TTS en Ubuntu.

## 📋 Requisitos

- **Sistema Operativo**: Ubuntu 20.04+ (o derivados como Linux Mint, Pop!_OS)
- **GPU**: NVIDIA con CUDA (opcional pero muy recomendado)
- **RAM**: Mínimo 8 GB, recomendado 16 GB
- **Espacio en disco**: ~5-10 GB libres
- **Python**: 3.8 o superior

## 🚀 Inicio Rápido

### Instalación Completa Automática

```bash
cd scripts/
chmod +x install_all.sh
./install_all.sh
```

Este script ejecutará automáticamente:
1. Configuración del sistema
2. Instalación de Piper y dependencias
3. Descarga del modelo base

### Instalación Manual (Paso a Paso)

Si prefieres más control, ejecuta los scripts individualmente:

```bash
cd scripts/

# 1. Configurar sistema
chmod +x 01_setup_system.sh
./01_setup_system.sh

# 2. Instalar Piper
chmod +x 02_install_piper.sh
./02_install_piper.sh

# 3. Descargar modelo base
chmod +x 03_download_base_model.sh
./03_download_base_model.sh
```

## 📂 Estructura de Scripts

| Script | Descripción |
|--------|-------------|
| `install_all.sh` | Instalación completa automatizada |
| `01_setup_system.sh` | Instala dependencias del sistema (espeak-ng, ffmpeg, etc.) |
| `02_install_piper.sh` | Instala Piper, crea entorno virtual, instala dependencias Python |
| `03_download_base_model.sh` | Descarga el checkpoint base (952 MB) |
| `04_clean_dataset.sh` | Limpia y valida el dataset, filtra audios cortos |
| `05_train.sh` | Entrena el modelo de voz |
| `06_export.sh` | Exporta el modelo entrenado a formato ONNX |

## 🎯 Uso después de la Instalación

### 1. Preparar tu Dataset

Tu dataset debe tener esta estructura:

```
mi_voz/
├── config.json          # Configuración de audio e idioma
├── dataset.jsonl        # Lista de audios y transcripciones
└── wavs/                # Directorio con archivos de audio
    ├── audio001.wav
    ├── audio002.wav
    └── ...
```

Coloca tu dataset en `~/piper-training/datasets/`

### 2. Limpiar y Validar Dataset

```bash
cd scripts/
chmod +x 04_clean_dataset.sh
./04_clean_dataset.sh ~/piper-training/datasets/mi_voz
```

Este script:
- Verifica la estructura del dataset
- Filtra audios muy cortos (< 1.0s) que causan errores
- Crea un backup automático
- Muestra estadísticas del dataset

### 3. Entrenar el Modelo

```bash
chmod +x 05_train.sh
./05_train.sh ~/piper-training/datasets/mi_voz 3000 8
```

Parámetros:
- `3000`: Número máximo de épocas (ajustar según necesites)
- `8`: Batch size (reducir si tienes errores de memoria)

**Ajustar batch size según tu GPU:**
- GPU con 16GB (T4, RTX 4060): `8-16`
- GPU con 8GB: `4-8`
- GPU con 4GB: `2-4`
- CPU: `1-2` (muy lento)

### 4. Exportar el Modelo

```bash
chmod +x 06_export.sh
./06_export.sh
```

Este script busca automáticamente el último checkpoint y lo exporta a ONNX. También puedes especificar un checkpoint específico:

```bash
./06_export.sh ~/piper-training/datasets/mi_voz/lightning_logs/version_0/checkpoints/epoch=100.ckpt
```

### 5. Probar el Modelo

```bash
# Activar entorno virtual
source ~/piper-training/venv/bin/activate

# Instalar piper-tts
pip install piper-tts

# Generar audio
echo "Hola, esta es una prueba de mi voz" | piper \
  --model ~/piper-training/outputs/model.onnx \
  --output_file prueba.wav

# Reproducir (requiere aplay o similar)
aplay prueba.wav
```

## ⚙️ Configuración Avanzada

### Variables de Entorno

Los scripts usan `$HOME/piper-training` como directorio de trabajo. Para cambiar esto, edita la variable `WORK_DIR` en cada script.

### Reactivar Entorno Virtual

Después de cerrar la terminal, reactiva el entorno:

```bash
source ~/piper-training/venv/bin/activate
```

### Monitorear Entrenamiento

Durante el entrenamiento, puedes ver el progreso en tiempo real:

```bash
# Ver logs en vivo
tail -f ~/piper-training/datasets/mi_voz/lightning_logs/version_0/train.log

# Ver métricas (requiere Python)
cd ~/piper-training/datasets/mi_voz/lightning_logs/version_0/
cat metrics.csv
```

## 🔧 Solución de Problemas

### Error: "CUDA out of memory"

Reduce el batch size:
```bash
./05_train.sh ~/piper-training/datasets/mi_voz 3000 4
```

### Error: "No module named 'piper_train'"

Reactiva el entorno virtual:
```bash
source ~/piper-training/venv/bin/activate
```

### GPU no detectada

Verifica drivers NVIDIA:
```bash
nvidia-smi
```

Si no funciona, instala los drivers NVIDIA y CUDA toolkit.

### Dataset vacío después de limpieza

Los audios son muy cortos (< 1.0s). Necesitas audios más largos o ajusta `MIN_DURATION` en `04_clean_dataset.sh`.

## 📊 Diferencias con el Notebook de Colab

| Aspecto | Colab Notebook | Scripts Bash |
|---------|----------------|--------------|
| Entorno | Temporal (se borra) | Persistente en tu máquina |
| GPU | T4 limitada | Tu propia GPU NVIDIA |
| Dependencias | Se instalan cada vez | Se instalan una vez |
| Datos | Requiere Google Drive | Almacenamiento local |
| Automatización | Manual por celdas | Scripts reutilizables |

## 📝 Notas

- Los scripts crean backups automáticos antes de modificar archivos
- Todos los scripts usan `set -e` para detenerse ante errores
- Los colores en la terminal ayudan a identificar éxitos/errores
- Los checkpoints se guardan cada 5 épocas por defecto

## 🆘 Soporte

Para más información, consulta:
- [GUIA_ENTRENAMIENTO.md](../GUIA_ENTRENAMIENTO.md)
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- [Documentación oficial de Piper](https://github.com/rhasspy/piper)

## 📜 Licencia

Estos scripts se distribuyen bajo la misma licencia que el proyecto Piper TTS.
