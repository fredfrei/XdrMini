#!/usr/bin/env bash
set -euo pipefail

xdrmini_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
xdrmini_build_dir="$xdrmini_dir/build"

xdrmini_generator=()
if command -v ninja >/dev/null 2>&1; then
    xdrmini_generator=(-G Ninja)
fi

cmake -S "$xdrmini_dir" \
      -B "$xdrmini_build_dir" \
      "${xdrmini_generator[@]}" \
      -DCMAKE_BUILD_TYPE=Release

cmake --build "$xdrmini_build_dir" -j"$(nproc)"

echo
echo "FERTIG – XdrMini wurde gebaut."
echo "Starten mit:"
echo "  $xdrmini_build_dir/bin/xdrmini"
