#!/usr/bin/env python3
"""
Script para generar el notebook de Google Colab para entrenamiento de Piper TTS
"""

import json
import sys
from pathlib import Path

# Definir el notebook
notebook = {
    "cells": [],
    "metadata": {
        "accelerator": "GPU",
        "colab": {
            "gpuType": "T4",
            "provenance": []
        },
        "kernelspec": {
            "display_name": "Python 3",
            "name": "python3"
        }
    },
    "nbformat": 4,
    "nbformat_minor": 0
}

# Funciones auxiliares
def add_markdown(text):
    notebook["cells"].append({
        "cell_type": "markdown",
        "metadata": {},
        "source": text.split('\n')
    })

def add_code(code):
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": code.split('\n')
    })

# Contenido del notebook
add_markdown("""# 🎙️ Entrenamiento de Voz Piper TTS en Google Colab

Este notebook permite entrenar modelos de voz Piper TTS con GPU gratuita de Google Colab.

**GPU recomendada:** T4 o superior  
**Tiempo por época:** ~10-30 minutos con GPU (vs 30-60 min en CPU)

---""")

add_markdown("""## 1️⃣ Configuración Inicial

Verificar GPU y montar Google Drive""")

add_code("""# Verificar GPU disponible
!nvidia-smi

import torch
print(f"\\n✅ PyTorch version: {torch.__version__}")
print(f"✅ CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"✅ GPU: {torch.cuda.get_device_name(0)}")
    print(f"✅ VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")""")

add_code("""# Montar Google Drive
from google.colab import drive
drive.mount('/content/drive')

# Crear directorio de trabajo
!mkdir -p /content/piper-training
%cd /content/piper-training""")

add_markdown("""## 2️⃣ Instalación de Dependencias

Instalar Piper y todas las dependencias""")

add_code("""%%bash
set -e
echo "📦 Instalando dependencias del sistema..."
apt-get update -qq
apt-get install -y -qq espeak-ng wget git > /dev/null 2>&1
echo "✅ espeak-ng instalado"
espeak-ng --version""")

add_code("""%%bash
set -e
echo "📦 Instalando piper-phonemize..."
if [ ! -d "piper_phonemize" ]; then
    wget -q https://github.com/rhasspy/piper-phonemize/releases/download/v1.2.0/piper_phonemize-amd64.tar.gz
    tar -xzf piper_phonemize-amd64.tar.gz
    rm piper_phonemize-amd64.tar.gz
    echo "✅ piper-phonemize instalado"
else
    echo "✅ piper-phonemize ya existe"
fi""")

add_code("""%%bash
set -e
echo "📦 Clonando Piper..."
if [ ! -d "piper" ]; then
    git clone -q https://github.com/rhasspy/piper.git
    echo "✅ Piper clonado"
else
    echo "✅ Piper ya existe"
fi""")

add_code("""# Instalar dependencias Python
print("📦 Instalando PyTorch y dependencias...")
!pip install -q torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 --index-url https://download.pytorch.org/whl/cu121
!pip install -q "numpy>=1.26,<2.0"
!pip install -q "pytorch-lightning>=1.9.0,<2.0.0"
!pip install -q librosa onnxruntime scipy cython

%cd piper/src/python
!pip install -q -e . --no-deps
%cd /content/piper-training

print("✅ Dependencias instaladas")""")

add_markdown("""## 3️⃣ Descargar Modelo Base""")

add_code("""%%bash
set -e
mkdir -p models_base && cd models_base
if [ ! -f "en_US-lessac-high.ckpt" ]; then
    echo "📥 Descargando checkpoint (952 MB)..."
    wget -q --show-progress \\
        "https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/7bf647cb000d8c8319c6cdd4289dd6b7d0d3eeb8/en/en_US/lessac/high/epoch=2218-step=838782.ckpt" \\
        -O en_US-lessac-high.ckpt
    echo "✅ Checkpoint descargado"
else
    echo "✅ Checkpoint ya existe"
fi""")

add_markdown("""## 4️⃣ Configurar Dataset

Sube tu dataset preprocesado o procesa uno nuevo""")

add_code("""# OPCIÓN A: Copiar desde Google Drive
DRIVE_PATH = "/content/drive/MyDrive/piper-datasets/sig"  # ⬅️ AJUSTAR

!mkdir -p datasets
!cp -r "{DRIVE_PATH}" datasets/
import os
DATASET_NAME = os.path.basename(DRIVE_PATH)
DATASET_DIR = f"datasets/{DATASET_NAME}"
print(f"✅ Dataset copiado: {DATASET_DIR}")""")

add_code("""# OPCIÓN B: Subir ZIP y preprocesar
from google.colab import files
uploaded = files.upload()  # Sube tu dataset.zip aquí""")

add_markdown("""## 5️⃣ Entrenar Modelo""")

add_code("""# Configuración de entrenamiento
DATASET_DIR = "datasets/sig"  # ⬅️ AJUSTAR
MAX_EPOCHS = 100
BATCH_SIZE = 16  # Ajustar según VRAM
CHECKPOINT_EPOCHS = 5

!python -m piper_train \\
  --dataset-dir {DATASET_DIR} \\
  --accelerator gpu \\
  --devices 1 \\
  --batch-size {BATCH_SIZE} \\
  --validation-split 0.05 \\
  --num-test-examples 0 \\
  --max_epochs {MAX_EPOCHS} \\
  --quality high \\
  --resume_from_checkpoint models_base/en_US-lessac-high.ckpt \\
  --checkpoint-epochs {CHECKPOINT_EPOCHS} \\
  --precision 32""")

add_markdown("""## 6️⃣ Monitorear Progreso""")

add_code("""# Ver métricas
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

logs_dir = Path(DATASET_DIR) / "lightning_logs"
versions = sorted(logs_dir.glob("version_*"))
if versions:
    metrics = versions[-1] / "metrics.csv"
    if metrics.exists():
        df = pd.read_csv(metrics)
        print(df.tail())
        
        plt.figure(figsize=(12, 4))
        plt.subplot(1, 2, 1)
        plt.plot(df['epoch'], df['loss_gen_all'])
        plt.title('Generator Loss')
        plt.subplot(1, 2, 2)
        plt.plot(df['epoch'], df['loss_disc_all'])
        plt.title('Discriminator Loss')
        plt.tight_layout()
        plt.show()""")

add_markdown("""## 7️⃣ Exportar Modelo""")

add_code("""# Exportar a ONNX
from pathlib import Path
logs_dir = Path(DATASET_DIR) / "lightning_logs"
versions = sorted(logs_dir.glob("version_*"))
checkpoints = sorted(versions[-1].glob("checkpoints/*.ckpt"))
CHECKPOINT = str(checkpoints[-1])

!mkdir -p outputs
!cd piper/src/python && python3 -m piper_train.export_onnx \\
    "{CHECKPOINT}" \\
    "/content/piper-training/outputs/model.onnx"

!cp {DATASET_DIR}/config.json outputs/model.onnx.json
print("✅ Modelo exportado a outputs/")""")

add_markdown("""## 8️⃣ Descargar Resultados""")

add_code("""# Guardar en Google Drive
!mkdir -p "/content/drive/MyDrive/piper-models/trained_model"
!cp -r outputs/* "/content/drive/MyDrive/piper-models/trained_model/"
print("✅ Guardado en Drive")""")

add_code("""# O descargar directamente
from google.colab import files
!zip -r model_trained.zip outputs/
files.download("model_trained.zip")""")

# Guardar notebook
output_path = Path(__file__).parent.parent / "colab_piper_training.ipynb"
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(notebook, f, indent=2, ensure_ascii=False)

print(f"✅ Notebook creado: {output_path}")
print(f"   Tamaño: {output_path.stat().st_size} bytes")
print(f"   Celdas: {len(notebook['cells'])}")
