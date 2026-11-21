#!/bin/bash
# Passo 153 (DD-192): roda N partidas só de bots (P ao mesmo tempo) e mostra a média de território, vitórias e usos por habilidade de bioma.
# Uso: bash tools/sim_balance.sh [N=12] [P=2]      Variáveis: SIM_SECONDS (padrão 240), SIM_BOTS (padrão 5)
# Cada partida de 240 s leva ~90 s de relógio; o resultado cru fica em $SIM_OUT (padrão /d/Terraforge_Godotrt/sim_balance.txt).
N=${1:-12}
P=${2:-2}
OUT=${SIM_OUT:-/d/Terraforge_Godotrt/sim_balance.txt}
cd "$(dirname "$0")/.." || exit 1
: > "$OUT"
seq "$N" | xargs -P "$P" -I{} sh -c '/d/Tools/godot/godot_console.exe --headless --path . --fixed-fps 60 -s res://tools/sim_balance.gd 2>&1 | grep "^SIM\|^WIN\|FALHOU" >> "$0"' "$OUT"
awk '
/^SIM/ { split($2,a,"="); split($4,p,"="); split($5,s,"="); split($6,u,"=")
         k=a[2]; n[k]++; pct[k]+=p[2]; spr[k]+=s[2]; abi[k]+=u[2] }
/^WIN/ { split($2,a,"="); win[a[2]]++; total++ }
/FALHOU/ { fail++ }
END { printf "%-8s %8s %8s %8s %10s %10s\n", "bioma", "partidas", "% médio", "vitórias", "sprints", "habilidades"
       for (k in n) printf "%-8s %8d %8.1f %8d %10.1f %10.1f\n", k, n[k], pct[k]/n[k], win[k], spr[k]/n[k], abi[k]/n[k]
       printf "partidas: %d, falhas: %d\n", total, fail }' "$OUT"
