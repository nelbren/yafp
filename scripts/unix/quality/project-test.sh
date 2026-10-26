#!/usr/bin/env bash
# Ejecución de las pruebas existentes; el análisis estático usa quality/check.bash.
set -euo pipefail
export YAFP_METRICS_DISABLED=1
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"
for test_file in osc133_test.bash theme_loading_test.bash remote_status_test.bash origin_device_hook_test.bash psscriptanalyzer_setup_test.bash; do
    bash "tests/$test_file"
done
bash scripts/unix/quality/zsh.bash
