# Entrenador de Voz - Piper TTS

🎙️ Scripts y guías para entrenar modelos de voz personalizados usando Piper TTS en español.

## 📋 Descripción

Este repositorio contiene herramientas, scripts y documentación completa para entrenar tu propio modelo de síntesis de voz (TTS) en español usando [Piper](https://github.com/rhasspy/piper). Los scripts están optimizados para hardware con GPU AMD (ROCm), específicamente para AMD Radeon RX 6600.

## ✨ Características

- 📖 **Guía completa en español** con instrucciones paso a paso
- 🚀 **Scripts automatizados** para configuración, preprocesamiento, entrenamiento y exportación
- 🔧 **Optimizado para AMD GPU** con ROCm
- 🎯 **Transfer learning** desde modelos base en español (es_ES-sharvard-medium)
- 🛠️ **Herramientas de validación** de datasets
- 🎵 **Utilidades de limpieza de audio**

## 🎯 Objetivo

Entrenar modelos de voz que suenen **más fluidos y menos robóticos** que los modelos base, personalizados con tu propia voz o dataset en español.

## 🚀 Inicio Rápido

### 1. Clonar el repositorio

```bash
git clone https://github.com/choruzo/entrenador-de-voz.git
cd entrenador-de-voz
```

### 2. Ejecutar configuración inicial

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

Este script instalará:
- ROCm (si es necesario)
- PyTorch con soporte ROCm
- Piper training
- Dependencias necesarias

### 3. Preparar tu dataset

Crea un dataset en formato LJSpeech:

```
mi_dataset/
├── wavs/
│   ├── audio001.wav
│   ├── audio002.wav
│   └── ...
└── metadata.csv
```

**Formato de metadata.csv:**
```
audio001|Este es el texto del primer audio.
audio002|Texto del segundo audio con puntuación correcta.
```

### 4. Validar el dataset

```bash
python3 scripts/validar_dataset.py mi_dataset
```

### 5. Preprocesar los datos

```bash
./scripts/preprocess.sh mi_dataset dataset_procesado es-es
```

### 6. Entrenar el modelo

```bash
./scripts/train.sh dataset_procesado modelos_base/es_ES-sharvard-medium.ckpt
```

### 7. Exportar el modelo

```bash
./scripts/export.sh checkpoints/modelo-final.ckpt mi_voz_es.onnx
```

### 8. Probar tu voz

```bash
echo "Hola, esta es mi voz personalizada" | piper --model mi_voz_es.onnx --output_file prueba.wav
aplay prueba.wav
```

## 📚 Documentación

### Guías Principales

- **[GUIA_ENTRENAMIENTO.md](GUIA_ENTRENAMIENTO.md)** - Guía completa y detallada
  - Requisitos del sistema
  - Instalación paso a paso
  - Preparación de datasets
  - Proceso de entrenamiento
  - Optimizaciones para tu hardware
  - Consejos para mejorar la fluidez
  - Solución de problemas

### Scripts Disponibles

| Script | Descripción |
|--------|-------------|
| `setup.sh` | Configuración inicial del entorno |
| `preprocess.sh` | Preprocesamiento de datos |
| `train.sh` | Entrenamiento del modelo |
| `export.sh` | Exportación a ONNX |
| `limpiar_audio.py` | Limpieza y normalización de audio |
| `validar_dataset.py` | Validación de datasets |

## 💻 Requisitos del Sistema

### Hardware Recomendado

- **GPU**: AMD Radeon RX 6000/7000 series o superior
- **RAM**: 16GB mínimo, 32GB recomendado
- **Almacenamiento**: 50GB+ de espacio libre
- **CPU**: Cualquier CPU moderna de 4+ núcleos

### Software

- **SO**: Ubuntu 20.04/22.04 LTS (recomendado)
- **ROCm**: 6.0+
- **Python**: 3.9+
- **Git**: Para clonar repositorios

## 🎓 Recursos de Aprendizaje

### Datasets Públicos en Español

- [Common Voice (Mozilla)](https://commonvoice.mozilla.org/es) - Dataset colaborativo
- [M-AILABS](https://www.caito.de/2019/01/the-m-ailabs-speech-dataset/) - Audiolibros
- [CSS10](https://github.com/Kyubyong/css10) - 10 idiomas incluyendo español

### Enlaces Útiles

- [Piper GitHub](https://github.com/rhasspy/piper) - Repositorio oficial
- [Piper Voices](https://huggingface.co/rhasspy/piper-voices) - Modelos pre-entrenados
- [ROCm Documentation](https://rocm.docs.amd.com/) - Documentación de AMD

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Haz fork del repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la licencia MIT. Ver `LICENSE` para más detalles.

## 🙏 Agradecimientos

- [Rhasspy](https://github.com/rhasspy) - Por crear Piper TTS
- [AMD](https://www.amd.com/) - Por ROCm y soporte de GPU
- Comunidad de código abierto

## 💬 Soporte

Si tienes preguntas o problemas:

1. Revisa la [GUIA_ENTRENAMIENTO.md](GUIA_ENTRENAMIENTO.md)
2. Busca en los [Issues](https://github.com/choruzo/entrenador-de-voz/issues)
3. Abre un nuevo Issue si no encuentras solución
4. Únete al [Discord de Rhasspy](https://discord.gg/rhasspy)

## 📊 Estado del Proyecto

🚧 Proyecto en desarrollo activo - Nuevas características y mejoras en camino

---

Hecho con ❤️ para la comunidad hispanohablante
