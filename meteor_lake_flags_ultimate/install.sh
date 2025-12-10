#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FLAGS_SRC="${ROOT_DIR}/METEOR_TRUE_FLAGS.sh"
TARGET="${HOME}/.meteor_lake_flags.sh"

if [ ! -f "${FLAGS_SRC}" ]; then
    echo "✗ METEOR_TRUE_FLAGS.sh not found at ${FLAGS_SRC}"
    echo "  Run from repository root or ensure the flags file exists."
    exit 1
fi

cp "${FLAGS_SRC}" "${TARGET}"

if ! grep -qx 'source ~/.meteor_lake_flags.sh' "${HOME}/.bashrc"; then
    echo "source ~/.meteor_lake_flags.sh" >> "${HOME}/.bashrc"
fi

echo "✓ Installed METEOR TRUE max-performance + security flags to ${TARGET}"
echo "Restart shell or run: source ~/.meteor_lake_flags.sh"
