# Solución para Error de CUDA con RTX 5060 Ti

## Problema

El error "CUDA error: no kernel image is available for execution on the device" ocurre porque:

1. **Python 3.12 es demasiado reciente** - Muchas librerías de ML aún no están optimizadas
2. **PyTorch antiguo sin soporte Ada Lovelace** - La RTX 5060 Ti usa arquitectura Ada Lovelace (compute capability 8.9) que requiere PyTorch 2.4+

## Solución Aplicada

He actualizado los scripts de instalación para:

1. ✅ **Recomendar Python 3.10** - Versión más estable para ML
2. ✅ **Instalar PyTorch 2.4.0** - Soporta Ada Lovelace completamente
3. ✅ **Actualizar PyTorch Lightning 2.0** - Compatible con PyTorch 2.4

## Pasos para Reinstalar

### Opción A: Instalación Limpia (Recomendado)

```bash
# 1. Eliminar entorno anterior
rm -rf ~/piper-training

# 2. Instalar Python 3.10 si no lo tienes
sudo apt update
sudo apt install python3.10 python3.10-venv python3.10-dev

# 3. Ejecutar instalación completa
cd ~/Documentos/entrenador-de-voz/scripts
./install_all.sh
```

### Opción B: Actualizar Entorno Existente

```bash
# 1. Eliminar solo el entorno virtual
rm -rf ~/piper-training/venv

# 2. Ejecutar solo la instalación de Piper
cd ~/Documentos/entrenador-de-voz/scripts
./02_install_piper.sh
```

## Verificación

Después de la instalación, verifica:

```bash
source ~/piper-training/venv/bin/activate
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
```

Deberías ver:
- PyTorch: 2.4.0
- CUDA: True

## Notas Importantes

### Sobre Python 3.12

Si insistes en usar Python 3.12, es posible pero:
- ⚠️ Algunas dependencias pueden fallar
- ⚠️ Rendimiento puede ser subóptimo
- ⚠️ Errores inesperados pueden ocurrir

**Recomendación fuerte: Usa Python 3.10**

### Sobre la GPU

Tu RTX 5060 Ti es una GPU excelente para entrenamiento, pero requiere:
- ✅ Drivers NVIDIA >= 525
- ✅ PyTorch >= 2.4.0 con CUDA 12.1
- ✅ Compute capability 8.9 (Ada Lovelace)

### Tiempo de Entrenamiento

Con RTX 5060 Ti y 3000 epochs:
- **Con GPU**: ~2-4 horas
- **Sin GPU (CPU)**: ~24-48 horas

## Troubleshooting

### Error: "python3.10: command not found"

```bash
sudo apt update
sudo apt install python3.10 python3.10-venv python3.10-dev
```

### Error: "CUDA out of memory"

Reduce el batch size:
```bash
./05_train.sh ~/piper-training/datasets/mi_voz 3000 4  # Usar 4 en lugar de 8
```

### Error persiste después de reinstalar

1. Verifica drivers NVIDIA:
```bash
nvidia-smi
```

2. Si los drivers son antiguos (<525):
```bash
sudo apt install nvidia-driver-545
sudo reboot
```

3. Limpia cache de PyTorch:
```bash
rm -rf ~/.cache/torch
```

## Resumen de Cambios en Scripts

### `02_install_piper.sh`

- ✅ Detecta y recomienda Python 3.10
- ✅ Instala PyTorch 2.4.0 (antes: última versión)
- ✅ Instala PyTorch Lightning 2.0.0 (antes: 1.7.7)
- ✅ Actualiza parches de compatibilidad

### Versiones Utilizadas

| Paquete | Versión Anterior | Versión Nueva |
|---------|------------------|---------------|
| Python | 3.12 (tu sistema) | 3.10 (recomendado) |
| PyTorch | Última | 2.4.0 |
| PyTorch Lightning | 1.7.7 | 2.0.0 |
| TorchMetrics | 0.11.4 | 1.0.0 |
| CUDA | 12.1 | 12.1 (sin cambios) |

## Siguiente Paso

Después de reinstalar exitosamente:

```bash
# Entrenar tu modelo
cd ~/Documentos/entrenador-de-voz/scripts
./05_train.sh ~/piper-training/datasets/mi_voz 3000 8
```

Si el error persiste, abre un issue con:
- Output completo del error
- `nvidia-smi` output
- `python --version`
- `pip list | grep torch`
