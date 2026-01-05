
import json
import os

notebook_path = r"d:\Archivos\Javier\Scritp_python\Training_voice\entrenador-de-voz\Fix_de_colab_piper_training.ipynb"

def fix_notebook():
    if not os.path.exists(notebook_path):
        print(f"Error: Notebook not found at {notebook_path}")
        return

    with open(notebook_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    cells = data.get('cells', [])
    
    for cell in cells:
        if cell.get('cell_type') == 'code':
            source = cell.get('source', [])
            source_text = ''.join(source) if isinstance(source, list) else source
            
            # Find and replace the Google Drive mount cell
            if "google.colab" in source_text and "drive.mount" in source_text:
                print("Found Google Drive mount cell. Replacing...")
                cell['source'] = [
                    "# Crear directorio de trabajo (sin Google Drive)\n",
                    "import os\n",
                    "\n",
                    "# Crear directorio de trabajo local\n",
                    "!mkdir -p /content/piper-training\n",
                    "%cd /content/piper-training\n",
                    "\n",
                    "print(\"✅ Directorio de trabajo creado: /content/piper-training\")\n",
                    "print(\"\\n📝 NOTA: Los archivos se guardarán localmente.\")\n",
                    "print(\"   Para guardar en Drive, usa '!cp -r /content/piper-training /content/drive/MyDrive/' al final.\")"
                ]
                cell['outputs'] = []
                break
    
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print("Notebook updated: Google Drive mount replaced with local directory")

if __name__ == "__main__":
    fix_notebook()
