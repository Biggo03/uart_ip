#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN="${ROOT}/tools/Peripheral-Register-File-Generator/peripheral_regblk_gen.py"
CFG="./reg_generation_config.yml"

python3 "${GEN}" "${CFG}"
