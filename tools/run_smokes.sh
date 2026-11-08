#!/bin/bash
# Regressão: roda todos os smoke_*.gd (ou só os nomes passados) e imprime uma linha por teste.
# Uso: bash tools/run_smokes.sh [nome ...]   (ex.: bash tools/run_smokes.sh stats menu)
cd "$(dirname "$0")/.." || exit 1
names=("$@")
[ ${#names[@]} -eq 0 ] && names=($(ls tools/smoke_*.gd | sed 's#.*/smoke_##; s#\.gd$##'))
fail=0
for n in "${names[@]}"; do
  out=$(/d/Tools/godot/godot_console.exe --headless --path . -s "res://tools/smoke_$n.gd" 2>&1 | grep -E "^(OK|FALHOU)|SCRIPT ERROR|Parse Error" | head -3 | tr '\n' ' ')
  case "$out" in OK*) echo "OK     $n" ;; *) echo "FALHOU $n: $out"; fail=1 ;; esac
done
exit $fail
