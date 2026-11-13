"""Passo 87: texturas dos modelos em VRAM comprimida e no máximo 2048 px (as de 4096 px em WebP sem perdas ocupavam ~7 GB).
Reescreve só os .import de art/models (idempotente); depois rode: godot_console --headless --path . --import
Uso: python -X utf8 tools/optimize_textures.py   (na raiz do projeto)"""
import re
from pathlib import Path

LIMIT = 2048
changed = 0
for imp in Path("art/models").rglob("*.import"):
    text = imp.read_text(encoding="utf-8")
    if 'importer="texture"' not in text:
        continue
    new = text
    for key, value in (("compress/mode", 2), ("process/size_limit", LIMIT)):
        new = re.sub(rf"^{key}=.*$", f"{key}={value}", new, flags=re.M)
    if "_normal" in imp.name:
        new = re.sub(r"^compress/normal_map=.*$", "compress/normal_map=1", new, flags=re.M)   # relevo: formato próprio (RGTC), não "detectar"
    if new != text:
        imp.write_text(new, encoding="utf-8", newline="\n")
        changed += 1
print(changed, "arquivos .import atualizados")
