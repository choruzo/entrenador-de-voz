# Respuesta: ¿Se puede entrenar Piper-voices en español?

## Respuesta Corta: ¡SÍ! ✅

Es completamente posible entrenar un modelo Piper en español para que suene más fluido y menos robótico, partiendo desde `es_ES-sharvard-medium`.

## Tu Hardware es Adecuado ✅

Tu equipo es **perfecto** para este proyecto:
- **AMD Radeon RX 6600**: Compatible con ROCm, suficiente VRAM (8GB)
- **AMD Ryzen 5 5600G**: Buen procesador
- **32GB RAM**: Excelente, más que suficiente

## Pasos Resumidos

### 1. Configuración del Entorno
```bash
# Ejecutar script de configuración (todo automatizado)
./scripts/setup.sh
```
Esto instala: ROCm, PyTorch, Piper y dependencias.

### 2. Preparar tu Dataset
- **Opción A**: Graba tu propia voz (30 min mínimo, 2-5 horas ideal)
- **Opción B**: Usa datasets públicos (Common Voice, M-AILABS)

Formato requerido:
```
mi_dataset/
├── wavs/
│   ├── audio001.wav
│   └── ...
└── metadata.csv  # audio001|Transcripción exacta del audio.
```

### 3. Preprocesar
```bash
./scripts/preprocess.sh mi_dataset dataset_procesado es-es
```

### 4. Entrenar con Transfer Learning
```bash
./scripts/train.sh dataset_procesado modelos_base/es_ES-sharvard-medium.ckpt
```

**Tiempo estimado con tu GPU**:
- Dataset pequeño (30-60 min): 2-4 horas
- Dataset mediano (2-5 horas): 8-16 horas

### 5. Exportar y Probar
```bash
./scripts/export.sh checkpoints/modelo-final.ckpt mi_voz.onnx
echo "Prueba de voz" | piper --model mi_voz.onnx --output_file test.wav
```

## Ventajas del Transfer Learning

Partir desde `es_ES-sharvard-medium`:
- ✅ **Más rápido**: Converge en 5,000-8,000 épocas vs 20,000+ desde cero
- ✅ **Mejor calidad**: Incluso con datasets pequeños
- ✅ **Ya conoce español**: Fonética, prosodia y entonación

## Para Que Suene Más Fluido y Menos Robótico

### 1. Calidad del Dataset (LO MÁS IMPORTANTE)
- ✅ Audio limpio, sin ruido
- ✅ Grabación natural (no leer como robot)
- ✅ Variedad: preguntas, exclamaciones, emociones
- ✅ Transcripciones perfectas con puntuación correcta

### 2. Transfer Learning
- ✅ Usa el modelo base español (ya implementado en los scripts)

### 3. Tiempo de Entrenamiento
- ✅ Mínimo 5,000 épocas con transfer learning
- ✅ Monitorea validación loss y para cuando deje de mejorar

### 4. Ajustes de Inferencia
```bash
# Prueba diferentes valores de noise_scale para más naturalidad
echo "Texto" | piper --model modelo.onnx --noise_scale 0.8 --output_file out.wav
```

## Recursos Incluidos en Este Repositorio

📁 **Guías**:
- `GUIA_ENTRENAMIENTO.md` - Guía completa paso a paso
- `INICIO_RAPIDO.md` - Empezar en 30 minutos
- `TROUBLESHOOTING.md` - Solución de problemas

🔧 **Scripts automatizados**:
- `setup.sh` - Configuración completa del entorno
- `preprocess.sh` - Preprocesamiento de datos
- `train.sh` - Entrenamiento optimizado para RX 6600
- `export.sh` - Exportación a ONNX
- `limpiar_audio.py` - Normalización de audio
- `validar_dataset.py` - Validación de datos

📋 **Configuraciones**:
- `requirements.txt` - Dependencias Python
- `config.example.yaml` - Configuración de ejemplo

## Optimizaciones para tu RX 6600

Los scripts ya incluyen:
```bash
export HSA_OVERRIDE_GFX_VERSION=10.3.0  # Para RX 6600 (RDNA2)
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:512
--batch-size 8          # Optimizado para 8GB VRAM
--precision 16-mixed    # Ahorra memoria
```

## Resultado Esperado

Con un buen dataset de 2-5 horas:
- ✅ Voz natural y fluida
- ✅ Buena prosodia y entonación
- ✅ Pronunciación clara
- ✅ Menos robótica que el modelo base

## Próximos Pasos

1. **Lee**: `INICIO_RAPIDO.md` para empezar ahora
2. **Ejecuta**: `./scripts/setup.sh` para configurar todo
3. **Prepara**: Tu dataset de audio + transcripciones
4. **Entrena**: Siguiendo los scripts automatizados
5. **Consulta**: `GUIA_ENTRENAMIENTO.md` para detalles avanzados

## ¿Preguntas?

Toda la información detallada está en:
- `GUIA_ENTRENAMIENTO.md` - Guía completa
- `TROUBLESHOOTING.md` - Problemas comunes
- GitHub Issues - Para ayuda específica

---

**¡Sí, definitivamente puedes hacerlo con tu equipo!** 🚀

Los scripts están listos para usar y optimizados específicamente para tu hardware AMD.
