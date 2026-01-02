# Guía de Solución de Problemas

Esta guía cubre los problemas más comunes al entrenar voces con Piper y sus soluciones.

## Índice

- [Problemas de Instalación](#problemas-de-instalación)
- [Problemas de GPU/ROCm](#problemas-de-gpurocm)
- [Problemas con el Dataset](#problemas-con-el-dataset)
- [Problemas Durante el Entrenamiento](#problemas-durante-el-entrenamiento)
- [Problemas de Calidad de Audio](#problemas-de-calidad-de-audio)

---

## Problemas de Instalación

### Error: `rocm-smi: command not found`

**Causa**: ROCm no está instalado o no está en el PATH.

**Solución**:
```bash
# Verificar si ROCm está instalado
ls /opt/rocm

# Si existe pero no está en PATH, agregar:
export PATH=$PATH:/opt/rocm/bin

# Si no existe, instalar ROCm:
# Ubuntu 22.04:
wget https://repo.radeon.com/amdgpu-install/latest/ubuntu/jammy/amdgpu-install_latest_all.deb
sudo apt install ./amdgpu-install_latest_all.deb
sudo amdgpu-install --usecase=graphics,rocm

# Agregar usuario a grupos
sudo usermod -a -G render,video $USER

# Reiniciar
sudo reboot
```

### Error: `espeak-ng: command not found`

**Causa**: espeak-ng no está instalado.

**Solución**:
```bash
sudo apt-get update
sudo apt-get install espeak-ng

# Verificar instalación
espeak-ng --version
```

### Error al importar `torch`

**Causa**: PyTorch no está instalado o no está compilado para ROCm.

**Solución**:
```bash
# Desinstalar versión actual
pip uninstall torch torchvision torchaudio

# Reinstalar con soporte ROCm
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0

# Verificar
python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"
```

---

## Problemas de GPU/ROCm

### GPU no detectada por PyTorch

**Síntoma**: `torch.cuda.is_available()` retorna `False`

**Diagnóstico**:
```bash
# 1. Verificar que ROCm ve la GPU
rocm-smi

# 2. Verificar que PyTorch está compilado con ROCm
python3 -c "import torch; print(torch.__version__)"
# Debe contener "+rocm" en la versión

# 3. Verificar variables de entorno
echo $HSA_OVERRIDE_GFX_VERSION
```

**Solución**:
```bash
# Para AMD Radeon RX 6600 (RDNA2):
export HSA_OVERRIDE_GFX_VERSION=10.3.0

# Para RX 6700/6800/6900:
export HSA_OVERRIDE_GFX_VERSION=10.3.0

# Para RX 7000 series:
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# Hacer permanente (añadir a ~/.bashrc):
echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' >> ~/.bashrc
```

### Error: `HIP error: invalid device ordinal`

**Causa**: Configuración incorrecta de dispositivos.

**Solución**:
```bash
# Listar dispositivos disponibles
rocm-smi

# Establecer dispositivo específico
export CUDA_VISIBLE_DEVICES=0

# En el script de entrenamiento, asegúrate de usar --devices 1
```

### Out of Memory (OOM) durante entrenamiento

**Síntoma**: Error con código 137 o `CUDA out of memory`

**Soluciones**:

1. **Reducir batch size**:
   ```bash
   BATCH_SIZE=4 ./scripts/train.sh dataset_procesado checkpoint.ckpt
   ```

2. **Usar gradient accumulation**:
   ```bash
   # Editar train.sh para agregar:
   --accumulate-grad-batches 2
   ```

3. **Liberar memoria antes de entrenar**:
   ```bash
   # Cerrar otras aplicaciones que usen GPU
   # Ver qué está usando la GPU:
   rocm-smi
   
   # Matar procesos específicos si es necesario
   kill <PID>
   ```

4. **Reducir calidad del modelo**:
   ```bash
   QUALITY=low ./scripts/train.sh dataset_procesado checkpoint.ckpt
   ```

---

## Problemas con el Dataset

### Error: `metadata.csv not found`

**Causa**: Estructura de directorio incorrecta.

**Solución**:
```bash
# Estructura correcta:
mi_dataset/
├── wavs/
│   ├── audio001.wav
│   └── ...
└── metadata.csv

# Verificar:
ls mi_dataset/
ls mi_dataset/wavs/
cat mi_dataset/metadata.csv | head -3
```

### Error: Líneas mal formateadas en metadata.csv

**Síntoma**: `Error parsing metadata.csv`

**Problemas comunes**:
1. Encabezados en el archivo
2. Separador incorrecto (debe ser `|`)
3. Número incorrecto de campos

**Solución**:
```bash
# Verificar formato
head metadata.csv

# Formato correcto (sin encabezados):
audio001|Texto del audio uno.
audio002|Texto del audio dos.

# NO así (con encabezado):
file|text
audio001|Texto...

# Corregir si es necesario
# Eliminar primera línea si es encabezado:
tail -n +2 metadata.csv > metadata_temp.csv
mv metadata_temp.csv metadata.csv
```

### Archivos de audio no encontrados

**Síntoma**: `File not found: audioXXX.wav`

**Solución**:
```bash
# Verificar que los nombres coinciden
cd mi_dataset
for audio in $(cut -d'|' -f1 metadata.csv); do
    if [ ! -f "wavs/${audio}.wav" ]; then
        echo "Falta: wavs/${audio}.wav"
    fi
done

# Caso común: extensión en mayúsculas
# Renombrar si es necesario:
cd wavs
for f in *.WAV; do mv "$f" "${f%.WAV}.wav"; done
```

### Advertencia: Sample rates diferentes

**Síntoma**: `Multiple sample rates detected`

**Solución**:
```bash
# Normalizar todos los audios a 22050 Hz
python3 scripts/limpiar_audio.py mi_dataset/wavs mi_dataset/wavs_normalized

# Reemplazar
rm -rf mi_dataset/wavs_old
mv mi_dataset/wavs mi_dataset/wavs_old
mv mi_dataset/wavs_normalized mi_dataset/wavs
```

---

## Problemas Durante el Entrenamiento

### Entrenamiento muy lento

**Posibles causas**:
1. No está usando GPU
2. Batch size muy pequeño
3. CPU mode

**Diagnóstico**:
```bash
# Verificar uso de GPU durante entrenamiento
watch -n 1 rocm-smi

# Si GPU no se usa, verificar PyTorch
python3 -c "import torch; print(torch.cuda.is_available())"
```

**Solución**:
```bash
# Asegurar que usa GPU
export CUDA_VISIBLE_DEVICES=0
./scripts/train.sh dataset_procesado checkpoint.ckpt

# Aumentar batch size si hay VRAM disponible
BATCH_SIZE=12 ./scripts/train.sh dataset_procesado checkpoint.ckpt
```

### Loss no disminuye o salta a NaN

**Causas**:
1. Learning rate muy alto
2. Batch size muy pequeño
3. Datos corruptos

**Solución**:
```bash
# Reducir learning rate
LEARNING_RATE=5e-5 ./scripts/train.sh dataset_procesado checkpoint.ckpt

# Verificar dataset
python3 scripts/validar_dataset.py mi_dataset

# Empezar desde checkpoint más antiguo
./scripts/train.sh dataset_procesado checkpoints/modelo-epoch-2000.ckpt
```

### Entrenamiento se detiene inesperadamente

**Verificar**:
```bash
# Ver últimas líneas del log
tail -50 checkpoints/training.log

# Verificar espacio en disco
df -h

# Verificar si hubo OOM
dmesg | grep -i "out of memory"
```

---

## Problemas de Calidad de Audio

### Modelo suena robótico

**Causas comunes**:
1. Poco tiempo de entrenamiento
2. Dataset de baja calidad
3. Dataset muy pequeño
4. Transcripciones incorrectas

**Soluciones**:

1. **Entrenar más tiempo**:
   ```bash
   # Continuar desde último checkpoint
   MAX_EPOCHS=15000 ./scripts/train.sh dataset_procesado checkpoints/last.ckpt
   ```

2. **Mejorar dataset**:
   - Graba con mejor calidad
   - Elimina clips con ruido
   - Verifica transcripciones
   - Añade más variedad

3. **Ajustar parámetros de inferencia**:
   ```bash
   echo "Texto de prueba" | piper \
       --model mi_voz.onnx \
       --noise_scale 0.8 \
       --length_scale 1.0 \
       --noise_w 0.8 \
       --output_file test.wav
   ```

### Audio generado tiene artefactos

**Soluciones**:
1. Probar checkpoints diferentes (a veces uno intermedio es mejor)
2. Re-exportar el modelo
3. Reducir noise_scale en inferencia

### Pronunciación incorrecta

**Causas**:
1. Transcripciones incorrectas en el dataset
2. Palabras muy raras no vistas en entrenamiento

**Soluciones**:
1. Verificar transcripciones del dataset
2. Añadir más ejemplos de esas palabras
3. Re-entrenar con dataset corregido

---

## Obtener Ayuda

Si ninguna de estas soluciones funciona:

1. **Revisa los logs completos**:
   ```bash
   cat checkpoints/training.log
   ```

2. **Genera un reporte del sistema**:
   ```bash
   echo "=== Sistema ===" > debug_info.txt
   uname -a >> debug_info.txt
   
   echo -e "\n=== ROCm ===" >> debug_info.txt
   rocm-smi >> debug_info.txt
   
   echo -e "\n=== PyTorch ===" >> debug_info.txt
   python3 -c "import torch; print(f'Version: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')" >> debug_info.txt
   
   echo -e "\n=== GPU Info ===" >> debug_info.txt
   lspci | grep -i vga >> debug_info.txt
   ```

3. **Abre un Issue** en GitHub con:
   - Descripción del problema
   - Logs relevantes
   - Información del sistema
   - Pasos para reproducir

4. **Únete a la comunidad**:
   - [Discord de Rhasspy](https://discord.gg/rhasspy)
   - [Foro de Home Assistant](https://community.home-assistant.io/)

---

**¿Tu problema no está aquí?** Abre un Issue en GitHub con los detalles.
