#!/usr/bin/env bash
set -euo pipefail

# Standalone Linux/Steam Deck entry point; Bash + GNU coreutils, no Python.
ORIGINAL_HASH=3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b
OLD_HASH=f1c4a0e7448b8a05b653dd4535614a368fe0fcb24394cce3d4d587f10fd2c888
MANIFEST=4926516310915821720
fail() { printf 'Error: %s\n' "$*" >&2; return 1; }
hash_file() { sha256sum -- "$1" | cut -d ' ' -f 1; }
hex_at() { od -An -v -tx1 -j "$2" -N "$3" -- "$1" | tr -d ' \n'; }
uint_at() {
    local file=$1 offset=$2 count=$3 value=0 shift_bits=0 byte
    local -a bytes
    read -r -a bytes <<< "$(od -An -v -tu1 -j "$offset" -N "$count" -- "$file")"
    [[ ${#bytes[@]} == "$count" ]] || { fail 'Truncated PE header'; return 1; }
    for byte in "${bytes[@]}"; do value=$((value + (byte << shift_bits))); shift_bits=$((shift_bits + 8)); done
    printf '%s\n' "$value"
}
patch_offsets() {
    local file=$1 size pe count opt_size opt base target rva section start raw_size raw offset found i length
    size=$(stat -c %s -- "$file")
    [[ $size -ge 64 && $(hex_at "$file" 0 2) == 4d5a ]] || { fail 'Invalid MZ header'; return 1; }
    pe=$(uint_at "$file" 60 4)
    [[ $((pe+24)) -le $size && $(hex_at "$file" "$pe" 4) == 50450000 ]] || { fail 'Invalid PE header'; return 1; }
    [[ $(uint_at "$file" $((pe+4)) 2) == 332 ]] || { fail 'Expected x86 PE'; return 1; }
    count=$(uint_at "$file" $((pe+6)) 2); opt_size=$(uint_at "$file" $((pe+20)) 2); opt=$((pe+24))
    [[ $opt_size -ge 32 && $((opt+opt_size+40*count)) -le $size ]] || { fail 'Truncated PE sections'; return 1; }
    [[ $(uint_at "$file" "$opt" 2) == 267 ]] || { fail 'Expected PE32'; return 1; }
    base=$(uint_at "$file" $((opt+28)) 4)
    for target in $((0xa9e9c6)) $((0xa9ff64)); do
        length=5; [[ $target != $((0xa9ff64)) ]] || length=20
        rva=$((target-base)); found=0
        for ((i=0;i<count;i++)); do
            section=$((opt+opt_size+40*i)); start=$(uint_at "$file" $((section+12)) 4)
            raw_size=$(uint_at "$file" $((section+16)) 4); raw=$(uint_at "$file" $((section+20)) 4)
            if ((rva>=start && rva+length<=start+raw_size)); then
                offset=$((raw+rva-start))
                ((offset>=0 && offset+length<=size)) || { fail 'Invalid section bounds'; return 1; }
                printf '%s\n' "$offset"; found=1; break
            fi
        done
        [[ $found == 1 ]] || { fail 'Patch address is not backed by file data'; return 1; }
    done
}
mutate() {
    local file=$1 mode=$2 offsets branch cave
    offsets=$(patch_offsets "$file") || return 1
    read -r branch cave <<< "${offsets//$'\n'/ }"
    if [[ $mode == patched ]]; then
        printf '\xe9\x99\x15\x00\x00' | dd of="$file" bs=1 seek="$branch" conv=notrunc status=none
        printf '\xe8\x00\x00\x00\x00\x58\x05\x6f\x83\x07\x00\x6a\x01\xff\x10\xe9\x26\xeb\xff\xff' | dd of="$file" bs=1 seek="$cave" conv=notrunc status=none
    else
        printf '\xe9\xd3\x00\x00\x00' | dd of="$file" bs=1 seek="$branch" conv=notrunc status=none
        printf '\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc\xcc' | dd of="$file" bs=1 seek="$cave" conv=notrunc status=none
    fi
}
patch_state() (
    local file=$1 hash offsets branch cave temp=''
    trap '[[ -z $temp ]] || rm -f -- "$temp"' EXIT
    hash=$(hash_file "$file")
    if [[ $hash == "$OLD_HASH" ]]; then printf '1.9.7.15\n'; return; fi
    offsets=$(patch_offsets "$file" 2>/dev/null) || { printf 'unsupported\n'; return; }
    read -r branch cave <<< "${offsets//$'\n'/ }"
    if [[ $hash == "$ORIGINAL_HASH" && $(hex_at "$file" "$branch" 5) == e9d3000000 && $(hex_at "$file" "$cave" 20) == cccccccccccccccccccccccccccccccccccccccc ]]; then
        printf 'original\n'
    elif [[ $(hex_at "$file" "$branch" 5) == e999150000 && $(hex_at "$file" "$cave" 20) == e80000000058056f8307006a01ff10e926ebffff ]]; then
        temp=$(mktemp); cp -- "$file" "$temp"; mutate "$temp" original
        if [[ $(hash_file "$temp") == "$ORIGINAL_HASH" ]]; then printf 'patched\n'; else printf 'unsupported\n'; fi
    else printf 'unsupported\n'; fi
)
game_closed() {
    if pgrep -ix 'isaac-ng.exe' >/dev/null || pgrep -ix 'isaac-ng' >/dev/null; then fail 'Close Isaac before changing files'; return 1; fi
}
set_patch() (
    local file=$1 wanted=$2 state backup temp='' expected
    trap '[[ -z $temp ]] || rm -f -- "$temp"' EXIT
    game_closed || return 1
    state=$(patch_state "$file")
    [[ $state != "$wanted" ]] || { printf 'Already %s\n' "$wanted"; return; }
    [[ $state == original || $state == patched ]] || { fail "Unsupported executable ($state); only exact 1.9.7.17 is patchable"; return 1; }
    if [[ $wanted == patched ]]; then
        backup="$file.cpu-fix-backup-${ORIGINAL_HASH:0:12}"
        if [[ -e $backup ]]; then
            [[ $(hash_file "$backup") == "$ORIGINAL_HASH" ]] || { fail 'Unexpected backup hash'; return 1; }
        else cp -p -- "$file" "$backup"; fi
    fi
    temp=$(mktemp "$(dirname -- "$file")/.isaac-cpu-fix.XXXXXXXX")
    cp -p -- "$file" "$temp"; mutate "$temp" "$wanted"
    [[ $(patch_state "$temp") == "$wanted" ]] || { fail 'Pre-write verification failed'; return 1; }
    expected=$(hash_file "$temp"); mv -f -- "$temp" "$file"; temp=''
    [[ $(hash_file "$file") == "$expected" ]] || { fail 'Post-write verification failed'; return 1; }
    printf 'CPU patch: %s\n' "$wanted"
)
find_steam() {
    local root
    for root in "${STEAM_ROOT:-}" "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"; do
        if [[ -n $root && -d $root/steamapps ]]; then realpath -- "$root"; return; fi
    done
    fail 'Steam not found; set STEAM_ROOT to its directory'
}
find_isaac() {
    local explicit=${1:-${ISAAC_EXE:-}} root library candidate
    if [[ -n $explicit ]]; then [[ -f $explicit ]] || { fail 'EXE path not found'; return 1; }; realpath -- "$explicit"; return; fi
    if [[ -f ./isaac-ng.exe ]]; then realpath ./isaac-ng.exe; return; fi
    root=$(find_steam) || return 1
    local -a matches=() libraries=("$root")
    if [[ -f $root/steamapps/libraryfolders.vdf ]]; then
        while IFS= read -r library; do [[ $library == "$root" ]] || libraries+=("$library"); done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$root/steamapps/libraryfolders.vdf")
    fi
    for library in "${libraries[@]}"; do
        candidate="$library/steamapps/common/The Binding of Isaac Rebirth/isaac-ng.exe"
        [[ ! -f $candidate ]] || matches+=("$candidate")
    done
    [[ ${#matches[@]} == 1 ]] || { fail 'Could not identify one Isaac installation; pass the EXE path'; return 1; }
    realpath -- "${matches[0]}"
}
downgrade() {
    local file=$1 root log offset length deadline text depot='' game item relative
    root=$(find_steam) || return 1; game_closed || return 1
    pgrep -x steam >/dev/null || { fail 'Open Steam and sign in to the account that owns Isaac'; return 1; }
    log="$root/logs/console_log.txt"; offset=0
    [[ ! -f $log ]] || offset=$(stat -c %s -- "$log")
    if command -v steam >/dev/null; then
        steam -console +download_depot 250900 3353471 "$MANIFEST" >/dev/null 2>&1 &
    elif command -v flatpak >/dev/null; then
        flatpak run com.valvesoftware.Steam -console +download_depot 250900 3353471 "$MANIFEST" >/dev/null 2>&1 &
    else fail 'Steam launcher not found'; return 1; fi
    printf 'Downloading official 1.9.7.15 depot through Steam...\n'
    deadline=$((SECONDS+${DOWNLOAD_TIMEOUT:-1800}))
    while ((SECONDS<deadline)); do
        if [[ -f $log ]]; then
            length=$(stat -c %s -- "$log")
            ((length>=offset)) || { fail 'Steam rotated its log; retry'; return 1; }
            text=$(tail -c +$((offset+1)) -- "$log")
            depot=$(printf '%s\n' "$text" | sed -n "s/.*Depot download complete[[:space:]]*:[[:space:]]*\"\([^\"]*\)\"[[:space:]]*(manifest $MANIFEST).*/\1/p" | tail -n 1)
            [[ -z $depot ]] || break
            if printf '%s\n' "$text" | grep -Ei 'Depot download failed|Failed to download depot|Missing license|Access Denied' >&2; then fail 'Steam download failed'; return 1; fi
        fi
        sleep 2
    done
    [[ -n $depot ]] || { fail 'Timed out: check Steam Console. Game files were not changed'; return 1; }
    # Linux Steam can log a Windows-style suffix (ubuntu12_32\steamapps\...).
    # Keep a literal existing path first, otherwise normalize logged separators.
    [[ -d $depot ]] || depot=${depot//\\//}
    depot=$(realpath -- "$depot"); game=$(dirname -- "$file")
    [[ $depot != "$game" && -f $depot/isaac-ng.exe ]] || { fail 'Invalid depot directory'; return 1; }
    [[ $(hash_file "$depot/isaac-ng.exe") == "$OLD_HASH" ]] || { fail 'Downloaded EXE is not exact 1.9.7.15.J374'; return 1; }
    game_closed || return 1
    # Copy only downloaded depot files; no deletion/mirroring and no save backup.
    cp -a -- "$depot/." "$game/"
    while IFS= read -r -d '' item; do
        relative=${item#"$depot/"}
        [[ $(hash_file "$item") == "$(hash_file "$game/$relative")" ]] || { fail "Copy verification failed: $relative"; return 1; }
    done < <(find "$depot" -type f -print0)
    printf 'Installed and verified 1.9.7.15.J374. Use Proton to run this Windows build.\nSteam updates/Verify integrity can restore the latest version.\n'
}
main() {
    local command=${1:-status} file dependency
    [[ $# -le 2 ]] || { fail 'Usage: bash isaac-cpu-fix.sh {status|install|uninstall|downgrade} [isaac-ng.exe]'; return 1; }
    case "$command" in status|install|apply|uninstall|revert|downgrade) ;; *) fail 'Unknown command'; return 1;; esac
    for dependency in od dd sha256sum stat mktemp cp mv realpath pgrep sed grep find tail cut tr; do command -v "$dependency" >/dev/null || { fail "Required command: $dependency"; return 1; }; done
    [[ ${DOWNLOAD_TIMEOUT:-1800} =~ ^[1-9][0-9]{0,4}$ ]] || { fail 'DOWNLOAD_TIMEOUT must be 1-99999 seconds'; return 1; }
    file=$(find_isaac "${2:-}") || return 1
    case "$command" in
        install|apply) set_patch "$file" patched;;
        uninstall|revert) set_patch "$file" original;;
        downgrade) downgrade "$file";;
        status) printf 'Path: %s\nState: %s\nSHA256: %s\n' "$file" "$(patch_state "$file")" "$(hash_file "$file")";;
    esac
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
