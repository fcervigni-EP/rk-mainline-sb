#!/bin/bash
set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec make -C "${THIS_SCRIPT_DIR}" "$@"
