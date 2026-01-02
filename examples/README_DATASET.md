# Ejemplo de Dataset para Entrenamiento

Este directorio muestra la estructura y formato correctos para un dataset de Piper.

## Estructura de Archivos

```
ejemplo_dataset/
├── wavs/
│   ├── audio_001.wav
│   ├── audio_002.wav
│   ├── audio_003.wav
│   └── ...
└── metadata.csv
```

## Formato de metadata.csv

El archivo `metadata.csv` debe seguir este formato EXACTAMENTE:

### Para Single-Speaker (una sola voz)

```csv
audio_001|Buenos días, este es un ejemplo de transcripción.
audio_002|¿Cómo estás? Espero que tengas un excelente día.
audio_003|La puntuación es importante para la entonación correcta.
audio_004|Los números como 123 y las fechas como 2026 deben escribirse como se pronuncian.
audio_005|¡Este es un ejemplo de exclamación! ¿Y esta es una pregunta?
```

### Para Multi-Speaker (múltiples voces)

```csv
audio_001|maria|Hola, mi nombre es María.
audio_002|juan|Yo soy Juan, encantado de conocerte.
audio_003|maria|¿Cómo ha sido tu día?
audio_004|juan|Muy bien, gracias por preguntar.
```

## Reglas Importantes

### ❌ NO hacer esto:

```csv
# ❌ NO incluir encabezados
file|text
audio_001|Texto aquí

# ❌ NO usar otros separadores
audio_001,Texto aquí
audio_001;Texto aquí
audio_001	Texto aquí

# ❌ NO incluir extensión .wav en el nombre
audio_001.wav|Texto aquí

# ❌ NO transcripciones vacías
audio_001|

# ❌ NO usar comillas alrededor del texto
audio_001|"Texto aquí"
```

### ✅ SÍ hacer esto:

```csv
# ✅ Sin encabezados, separador pipe |
audio_001|Texto con puntuación correcta.

# ✅ Sin extensión .wav
audio_002|Más texto de ejemplo.

# ✅ Incluir toda la puntuación
audio_003|¿Preguntas? ¡Exclamaciones! Y puntos finales.

# ✅ Números escritos como se pronuncian
audio_004|Tengo veintitrés años y vivo en el número cien.
```

## Especificaciones de Audio

### Formato Recomendado

- **Formato**: WAV (sin comprimir)
- **Frecuencia de muestreo**: 22050 Hz (para modelos medium)
- **Canales**: Mono (1 canal)
- **Bits**: 16-bit
- **Duración por clip**: 3-10 segundos ideal
- **Duración total**: Mínimo 30 minutos, ideal 2-5 horas

### Calidad del Audio

✅ **Bueno**:
- Sin ruido de fondo
- Volumen consistente
- Sin clipping (saturación)
- Sin eco o reverberación
- Distancia constante del micrófono

❌ **Evitar**:
- Ruido de ventilador, tráfico, etc.
- Cambios bruscos de volumen
- Audio distorsionado
- Cambios en el ambiente de grabación
- Respiraciones fuertes o sonidos de boca

## Ejemplo de Transcripciones

### Buenos Ejemplos

```csv
frase_001|Buenos días, ¿cómo está usted?
frase_002|El restaurante abre de nueve a veintidós horas.
frase_003|Por favor, llame al teléfono cinco, cinco, cinco, cero, uno, dos, tres.
frase_004|La reunión es el lunes catorce de febrero de dos mil veintiséis.
frase_005|¡Qué maravilloso día hace hoy!
frase_006|Necesito comprar pan, leche, huevos y mantequilla.
frase_007|¿Podría repetir eso, por favor?
frase_008|La temperatura es de veinticinco grados centígrados.
```

### Variedad de Contenido

Incluye diferentes tipos de frases:

**Afirmativas**:
```csv
afirm_001|El cielo está despejado y hace sol.
afirm_002|Me gusta mucho leer libros de ciencia ficción.
```

**Interrogativas**:
```csv
pregunta_001|¿Dónde está la estación de tren más cercana?
pregunta_002|¿A qué hora empieza la película?
```

**Exclamativas**:
```csv
exclam_001|¡Qué sorpresa tan agradable!
exclam_002|¡Felicidades por tu cumpleaños!
```

**Números y fechas**:
```csv
numeros_001|El precio es de cincuenta euros con noventa céntimos.
numeros_002|Nací el quince de agosto de mil novecientos noventa.
```

**Comandos**:
```csv
comando_001|Abre la puerta principal.
comando_002|Por favor, enciende las luces del salón.
```

## Convertir Audio al Formato Correcto

Si tus archivos no están en el formato correcto, puedes usar este script:

### Con FFmpeg

```bash
# Convertir un archivo
ffmpeg -i entrada.mp3 -ar 22050 -ac 1 -sample_fmt s16 salida.wav

# Convertir todos los MP3 en un directorio
for f in *.mp3; do
    ffmpeg -i "$f" -ar 22050 -ac 1 -sample_fmt s16 "${f%.mp3}.wav"
done
```

### Con el Script Incluido

```bash
# Usar el script de limpieza que normaliza automáticamente
python3 scripts/limpiar_audio.py audio_original/ wavs/
```

## Crear metadata.csv desde Nombres de Archivo

Si tienes los nombres de archivo como texto:

```bash
# Listar archivos y crear estructura básica
cd wavs
for f in *.wav; do
    basename="${f%.wav}"
    echo "$basename|TRANSCRIPCIÓN_AQUÍ"
done > ../metadata.csv
```

Luego edita `metadata.csv` y reemplaza "TRANSCRIPCIÓN_AQUÍ" con el texto real.

## Validar tu Dataset

Antes de entrenar, valida tu dataset:

```bash
python3 scripts/validar_dataset.py mi_dataset/
```

Esto verificará:
- ✅ Estructura de directorios correcta
- ✅ Formato de metadata.csv
- ✅ Existencia de archivos de audio
- ✅ Calidad de audio (sample rate, duración)
- ✅ Consistencia entre metadata y archivos

## Consejos Finales

1. **Empieza pequeño**: Prueba con 30-60 minutos antes de grabar horas
2. **Calidad > Cantidad**: 1 hora perfecta > 5 horas con ruido
3. **Consistencia**: Misma voz, mismo micrófono, mismo ambiente
4. **Variedad**: Diferentes tipos de frases y emociones
5. **Precisión**: Transcripciones exactas = mejor modelo
6. **Puntuación**: Afecta la prosodia y entonación

## Recursos Adicionales

- Ver `GUIA_ENTRENAMIENTO.md` para detalles completos
- Usar `scripts/validar_dataset.py` para verificar formato
- Usar `scripts/limpiar_audio.py` para normalizar audio

---

**¿Listo para crear tu dataset?** Sigue este formato y tendrás éxito en el entrenamiento.
