#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo/steam-deck/isaac-cpu-fix.sh"
# Tests mutate only their temporary fixtures, including on a host playing Isaac.
game_closed() { :; }
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
target="$test_dir/isaac-ng.exe"
# Minimal PE32 fixture: one raw-backed section containing both patch addresses.
truncate -s 16384 "$target"
printf '\x4d\x5a' | dd of="$target" conv=notrunc status=none
printf '\x80\x00\x00\x00' | dd of="$target" bs=1 seek=60 conv=notrunc status=none
printf '\x50\x45\x00\x00\x4c\x01\x01\x00' | dd of="$target" bs=1 seek=128 conv=notrunc status=none
printf '\xe0\x00' | dd of="$target" bs=1 seek=148 conv=notrunc status=none
printf '\x0b\x01' | dd of="$target" bs=1 seek=152 conv=notrunc status=none
printf '\x00\x00\x40\x00' | dd of="$target" bs=1 seek=180 conv=notrunc status=none
printf '\x00\xe0\x69\x00\x00\x30\x00\x00\x00\x02\x00\x00' | dd of="$target" bs=1 seek=388 conv=notrunc status=none
mutate "$target" original
production_hash=$ORIGINAL_HASH
[[ $(patch_state "$target") == unsupported ]]
# Tests inject only the synthetic fixture hash into the sourced library.
ORIGINAL_HASH=$(hash_file "$target")
[[ $(patch_state "$target") == original ]]
set_patch "$target" patched
[[ $(patch_state "$target") == patched ]]
set_patch "$target" patched
set_patch "$target" original
[[ $(hash_file "$target") == "$ORIGINAL_HASH" ]]
set_patch "$target" patched
printf '\x01' | dd of="$target" bs=1 seek=1024 conv=notrunc status=none
[[ $(patch_state "$target") == unsupported ]]
if set_patch "$target" original; then fail 'Tampered patch accepted'; exit 1; fi
printf 'not PE' > "$test_dir/invalid.exe"
[[ $(patch_state "$test_dir/invalid.exe") == unsupported ]]
# Mock Steam completion and exercise the real downgrade copy and verification.
mkdir -p "$test_dir/steam/steamapps" "$test_dir/steam/logs" "$test_dir/depot/assets" "$test_dir/game/mods"
printf 'old build fixture' > "$test_dir/depot/isaac-ng.exe"
printf 'asset' > "$test_dir/depot/assets/a"
printf 'keep mod' > "$test_dir/game/mods/test"
printf 'new build fixture' > "$test_dir/game/isaac-ng.exe"
OLD_HASH=$(hash_file "$test_dir/depot/isaac-ng.exe")
export STEAM_ROOT="$test_dir/steam"
pgrep() { [[ $* == '-x steam' ]]; }
steam() { printf 'Depot download complete : "%s" (manifest %s)\n' "$test_dir/depot" "$MANIFEST" >> "$STEAM_ROOT/logs/console_log.txt"; }
downgrade "$test_dir/game/isaac-ng.exe"
[[ $(hash_file "$test_dir/game/isaac-ng.exe") == "$OLD_HASH" && $(< "$test_dir/game/mods/test") == 'keep mod' ]]
unset -f pgrep steam
if [[ $# -gt 0 ]]; then
    ORIGINAL_HASH=$production_hash
    cp -- "$1" "$test_dir/real.exe"
    [[ $(patch_state "$test_dir/real.exe") == original ]]
    set_patch "$test_dir/real.exe" patched
    [[ $(patch_state "$test_dir/real.exe") == patched ]]
    set_patch "$test_dir/real.exe" original
    [[ $(hash_file "$test_dir/real.exe") == "$production_hash" ]]
    printf 'Real EXE temporary-copy round trip passed.\n'
fi
printf 'Linux tests passed (synthetic PE, tamper rejection, mocked downgrade).\n'
