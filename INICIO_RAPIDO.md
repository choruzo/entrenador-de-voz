# Guía de Inicio Rápido - Entrenador de Voz Piper

Esta guía te permitirá entrenar tu primer modelo de voz en ~30 minutos (sin contar el tiempo de entrenamiento).

## ⚡ Pasos Rápidos

### 1. Configuración Inicial (5-10 min)

```bash
# Clonar repositorio
git clone https://github.com/choruzo/entrenador-de-voz.git
cd entrenador-de-voz

# Hacer scripts ejecutables
chmod +x scripts/*.sh

# Ejecutar configuración (instalará dependencias)
./scripts/setup.sh
```

**Nota**: La configuración descargará e instalará ~5GB de software (ROCm, PyTorch, Piper).

### 2. Preparar Dataset Mínimo (15-20 min)

Para probar el sistema, necesitas al menos **30 minutos de audio** de una sola voz.

#### Opción A: Descargar Dataset de Prueba

```bash
# Descargar Common Voice español (fragmento pequeño)
mkdir -p datasets/cv-es-test
cd datasets/cv-es-test

# Aquí deberías descargar y extraer un subset pequeño de Common Voice
# Visita: https://commonvoice.mozilla.org/es/datasets
```

#### Opción B: Grabar Tu Propia Voz

1. **Prepara un texto** (30-50 frases variadas)
   - Incluye preguntas, exclamaciones, afirmaciones
   - Usa puntuación correcta
   - Cada frase: 3-10 segundos de audio

2. **Graba con Audacity o similar**:
   - Formato: WAV
   - Frecuencia: 22050 Hz (o será convertido después)
   - Mono (un canal)
   - Sin ruido de fondo
   - Nombra archivos: audio001.wav, audio002.wav, etc.

3. **Crea la estructura**:
   ```bash
   mkdir -p mi_dataset/wavs
   # Copia tus archivos WAV a mi_dataset/wavs/
   ```

4. **Crea metadata.csv**:
   ```bash
   cat > mi_dataset/metadata.csv << 'EOF'
   audio001|Este es el texto exacto que dijiste en el primer audio.
   audio002|Y este es el texto del segundo audio.
   audio003|Asegúrate de que coincida exactamente con lo grabado.
   EOF
   ```

### 3. Limpiar Audio (2 min)

```bash
# Opcional pero recomendado: normalizar y limpiar audio
python3 scripts/limpiar_audio.py mi_dataset/wavs mi_dataset/wavs_limpios

# Si lo hiciste, actualiza la ruta:
mv mi_dataset/wavs mi_dataset/wavs_original
mv mi_dataset/wavs_limpios mi_dataset/wavs
```

### 4. Validar Dataset (1 min)

```bash
# Verificar que todo está correcto
python3 scripts/validar_dataset.py mi_dataset
```

Debe mostrar: ✓ Dataset válido

### 5. Preprocesar (2-3 min)

```bash
./scripts/preprocess.sh mi_dataset dataset_procesado es-es
```

### 6. Entrenar (2-24 horas dependiendo del dataset)

```bash
# Activar entorno
cd ~/piper-training
source env_setup.sh

# Entrenar con transfer learning desde modelo español
cd -
./scripts/train.sh dataset_procesado ~/piper-training/models_base/es_ES-sharvard-medium.ckpt
```

**Tiempos estimados con RX 6600**:
- Dataset pequeño (30 min audio): ~2-4 horas
- Dataset mediano (2 horas audio): ~8-16 horas

**Monitoreo**:
```bash
# En otra terminal
watch -n 2 rocm-smi

# Ver progreso del entrenamiento
tail -f checkpoints/training.log
```

**Cuándo parar**:
- La validación loss deja de mejorar
- Alcanza ~5000-8000 épocas (con transfer learning)
- Puedes parar en cualquier momento con Ctrl+C

### 7. Exportar Modelo (1 min)

```bash
# Encuentra el mejor checkpoint
ls -lht checkpoints/*.ckpt | head -5

# Exportar (usa el checkpoint que prefieras)
./scripts/export.sh checkpoints/modelo-epoch-5000.ckpt mi_voz.onnx
```

### 8. Probar (30 seg)

```bash
# Instalar Piper si no lo tienes
pip install piper-tts

# Generar audio de prueba
echo "Hola, soy una voz sintética entrenada con Piper. ¿Cómo sueno?" | \
    piper --model mi_voz.onnx --output_file test.wav

# Escuchar
aplay test.wav
```

## 📊 Resultados Esperados

### Con Dataset Pequeño (30-60 min)
- ✅ Voz reconocible
- ✅ Español claro
- ⚠️ Puede sonar algo robótico aún
- ⚠️ Puede tener problemas con palabras no vistas

### Con Dataset Mediano (2-5 horas)
- ✅ Voz natural y fluida
- ✅ Buena prosodia
- ✅ Maneja bien palabras nuevas
- ✅ Entonación apropiada

## 🔧 Ajustes Rápidos

### Si te quedas sin memoria durante entrenamiento:

```bash
# Reduce batch size
BATCH_SIZE=4 ./scripts/train.sh dataset_procesado [checkpoint]
```

### Si el modelo suena robótico:

1. **Entrena más tiempo** (más épocas)
2. **Mejora el dataset**:
   - Graba con mejor calidad
   - Añade más variedad de frases
   - Asegura transcripciones exactas
3. **Ajusta inferencia**:
   ```bash
   echo "Texto de prueba" | \
       piper --model mi_voz.onnx \
       --noise_scale 0.8 \
       --length_scale 1.0 \
       --output_file test.wav
   ```

### Si quieres mejor calidad (modelo más pesado):

```bash
QUALITY=high ./scripts/train.sh dataset_procesado [checkpoint]
```

**Nota**: Modelos "high" requieren más VRAM y tiempo de entrenamiento.

## 📈 Próximos Pasos

Una vez que tengas un modelo básico funcionando:

1. **Expande tu dataset**: Graba más audio variado
2. **Afina hiperparámetros**: Experimenta con learning rate, batch size
3. **Prueba diferentes checkpoints**: A veces épocas intermedias suenan mejor
4. **Lee la guía completa**: [GUIA_ENTRENAMIENTO.md](GUIA_ENTRENAMIENTO.md) tiene optimizaciones avanzadas

## ❓ Problemas Comunes

### ROCm no detecta mi GPU
```bash
# Verificar
rocm-smi

# Si falla, verifica drivers AMD
sudo amdgpu-install --usecase=graphics,rocm
sudo usermod -a -G render,video $USER
sudo reboot
```

### PyTorch no ve la GPU
```bash
python3 -c "import torch; print(torch.cuda.is_available())"

# Si retorna False, reinstala PyTorch con ROCm
pip uninstall torch
pip install torch --index-url https://download.pytorch.org/whl/rocm6.0
```

### Preprocesamiento falla
- Verifica que espeak-ng esté instalado: `espeak-ng --version`
- Verifica formato de metadata.csv (sin encabezados, separador `|`)
- Verifica que todos los archivos WAV existen

## 🎯 Meta: Sonido Natural

Para lograr una voz que suene **fluida y menos robótica**:

1. ✅ **Transfer learning** desde modelo español (es_ES-sharvard-medium)
2. ✅ **Dataset de calidad** > cantidad
3. ✅ **Variedad** en el contenido (no leer en tono monótono)
4. ✅ **Transcripciones precisas** con puntuación correcta
5. ✅ **Entrena suficiente** tiempo (5000-10000 épocas mínimo)
6. ✅ **Audio limpio** sin ruido ni artefactos

---

**¿Listo para empezar?** Ejecuta el primer comando y estarás entrenando tu voz en minutos. 🚀

Para más detalles, consulta la [Guía Completa de Entrenamiento](GUIA_ENTRENAMIENTO.md).
