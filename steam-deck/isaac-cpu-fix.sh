#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

command_name="${1:-status}"
if [[ $# -gt 0 ]]; then
  shift
fi

exec python3 "${repo_root}/patcher.py" "${command_name}" "$@"
