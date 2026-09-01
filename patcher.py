#!/usr/bin/env python3
"""Version-locked CPU busy-loop patcher for Isaac Repentance+ 1.9.7.17.

The patch is deliberately small and does not distribute any game files.  It
redirects the empty worker-queue branch to position-independent code that calls
Sleep(1), then resumes the original control flow.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


KNOWN_ORIGINAL_SHA256 = (
    "3bdfc8bae0dc7e334b76009d0ad45dfbb16ee5f00c06ffbc3a0094e34d44616b"
)
BRANCH_VA = 0x00A9E9C6
ORIGINAL_CONTINUE_VA = 0x00A9EA9E
CAVE_VA = 0x00A9FF64
SLEEP_IAT_VA = 0x00B182D8

ORIGINAL_BRANCH = bytes.fromhex("e9 d3 00 00 00")
ORIGINAL_CAVE = bytes([0xCC]) * 20


class PatchError(RuntimeError):
    pass


def rel32(source_after_instruction: int, target: int) -> bytes:
    return struct.pack("<i", target - source_after_instruction)


def make_branch_patch() -> bytes:
    return b"\xE9" + rel32(BRANCH_VA + 5, CAVE_VA)


def make_cave_patch() -> bytes:
    # Position-independent x86 code.  call/pop obtains the runtime image
    # address, so this remains valid when Windows ASLR relocates isaac-ng.exe.
    iat_delta = SLEEP_IAT_VA - (CAVE_VA + 5)
    return b"".join(
        (
            b"\xE8\x00\x00\x00\x00",  # call next instruction
            b"\x58",                    # pop eax
            b"\x05" + struct.pack("<i", iat_delta),  # add eax, Sleep IAT delta
            b"\x6A\x01",                # push 1
            b"\xFF\x10",                # call dword ptr [eax]
            b"\xE9" + rel32(CAVE_VA + 20, ORIGINAL_CONTINUE_VA),
        )
    )


PATCHED_BRANCH = make_branch_patch()
PATCHED_CAVE = make_cave_patch()


@dataclass(frozen=True)
class Section:
    name: str
    virtual_address: int
    virtual_size: int
    raw_offset: int
    raw_size: int


class PEImage:
    def __init__(self, data: bytes | bytearray) -> None:
        self.data = data
        if len(data) < 0x40 or data[:2] != b"MZ":
            raise PatchError("not a valid PE executable (missing MZ header)")
        pe_offset = self._u32(0x3C)
        if pe_offset + 24 > len(data) or data[pe_offset : pe_offset + 4] != b"PE\0\0":
            raise PatchError("not a valid PE executable (missing PE header)")
        coff = pe_offset + 4
        section_count = self._u16(coff + 2)
        optional_size = self._u16(coff + 16)
        optional = coff + 20
        if self._u16(optional) != 0x10B:
            raise PatchError("expected a 32-bit PE executable")
        self.image_base = self._u32(optional + 28)
        section_table = optional + optional_size
        sections: list[Section] = []
        for index in range(section_count):
            offset = section_table + index * 40
            if offset + 40 > len(data):
                raise PatchError("truncated PE section table")
            name = bytes(data[offset : offset + 8]).split(b"\0", 1)[0].decode(
                "ascii", errors="replace"
            )
            sections.append(
                Section(
                    name=name,
                    virtual_size=self._u32(offset + 8),
                    virtual_address=self._u32(offset + 12),
                    raw_size=self._u32(offset + 16),
                    raw_offset=self._u32(offset + 20),
                )
            )
        self.sections = tuple(sections)

    def _u16(self, offset: int) -> int:
        try:
            return struct.unpack_from("<H", self.data, offset)[0]
        except struct.error as exc:
            raise PatchError("truncated PE header") from exc

    def _u32(self, offset: int) -> int:
        try:
            return struct.unpack_from("<I", self.data, offset)[0]
        except struct.error as exc:
            raise PatchError("truncated PE header") from exc

    def va_to_offset(self, va: int) -> int:
        rva = va - self.image_base
        for section in self.sections:
            span = max(section.virtual_size, section.raw_size)
            if section.virtual_address <= rva < section.virtual_address + span:
                offset = section.raw_offset + rva - section.virtual_address
                if offset >= len(self.data):
                    break
                return offset
        raise PatchError(f"cannot map virtual address 0x{va:08X} to the file")


def sha256(data: bytes | bytearray) -> str:
    return hashlib.sha256(data).hexdigest()


def patch_state(data: bytes | bytearray) -> str:
    image = PEImage(data)
    branch_offset = image.va_to_offset(BRANCH_VA)
    cave_offset = image.va_to_offset(CAVE_VA)
    branch = bytes(data[branch_offset : branch_offset + len(ORIGINAL_BRANCH)])
    cave = bytes(data[cave_offset : cave_offset + len(ORIGINAL_CAVE)])
    if branch == ORIGINAL_BRANCH and cave == ORIGINAL_CAVE:
        return "original"
    if branch == PATCHED_BRANCH and cave == PATCHED_CAVE:
        return "patched"
    return "unknown"


def mutate(data: bytearray, apply_patch: bool) -> None:
    image = PEImage(data)
    branch_offset = image.va_to_offset(BRANCH_VA)
    cave_offset = image.va_to_offset(CAVE_VA)
    if apply_patch:
        data[cave_offset : cave_offset + len(PATCHED_CAVE)] = PATCHED_CAVE
        data[branch_offset : branch_offset + len(PATCHED_BRANCH)] = PATCHED_BRANCH
    else:
        data[branch_offset : branch_offset + len(ORIGINAL_BRANCH)] = ORIGINAL_BRANCH
        data[cave_offset : cave_offset + len(ORIGINAL_CAVE)] = ORIGINAL_CAVE


def candidate_paths() -> Iterable[Path]:
    explicit = os.environ.get("ISAAC_EXE")
    if explicit:
        yield Path(explicit).expanduser()
    compat = os.environ.get("STEAM_COMPAT_INSTALL_PATH")
    if compat:
        yield Path(compat) / "isaac-ng.exe"
    yield Path.cwd() / "isaac-ng.exe"
    program_files_x86 = os.environ.get("ProgramFiles(x86)")
    if program_files_x86:
        yield (
            Path(program_files_x86)
            / "Steam"
            / "steamapps"
            / "common"
            / "The Binding of Isaac Rebirth"
            / "isaac-ng.exe"
        )
    home = Path.home()
    for steam_root in (
        home / ".local/share/Steam",
        home / ".steam/steam",
        home / ".var/app/com.valvesoftware.Steam/data/Steam",
    ):
        yield (
            steam_root
            / "steamapps/common/The Binding of Isaac Rebirth/isaac-ng.exe"
        )


def resolve_executable(value: str | None) -> Path:
    if value:
        path = Path(value).expanduser().resolve()
        if not path.is_file():
            raise PatchError(f"file not found: {path}")
        return path
    for candidate in candidate_paths():
        if candidate.is_file():
            return candidate.resolve()
    raise PatchError("isaac-ng.exe was not found; pass its full path explicitly")


def atomic_replace(path: Path, data: bytes | bytearray) -> None:
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        shutil.copystat(path, temporary)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def status(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {
        "path": str(path),
        "state": patch_state(data),
        "sha256": sha256(data),
        "supported_original_sha256": KNOWN_ORIGINAL_SHA256,
    }


def apply(path: Path, allow_byte_compatible: bool, make_backup: bool) -> dict[str, object]:
    original = path.read_bytes()
    state = patch_state(original)
    original_hash = sha256(original)
    if state == "patched":
        return {**status(path), "changed": False, "message": "already patched"}
    if state != "original":
        raise PatchError("target bytes are neither the supported original nor this patch")
    if original_hash != KNOWN_ORIGINAL_SHA256 and not allow_byte_compatible:
        raise PatchError(
            "the executable hash is not the supported 1.9.7.17 build; "
            "use --allow-byte-compatible only after independently verifying the build"
        )

    backup: Path | None = None
    if make_backup:
        backup = path.with_name(f"{path.name}.cpu-fix-backup-{original_hash[:12]}")
        if backup.exists():
            backup_hash = sha256(backup.read_bytes())
            if backup_hash != original_hash:
                raise PatchError(f"existing backup has an unexpected hash: {backup}")
        else:
            shutil.copy2(path, backup)

    patched = bytearray(original)
    mutate(patched, apply_patch=True)
    if patch_state(patched) != "patched":
        raise PatchError("internal verification failed before writing")
    atomic_replace(path, patched)
    written = path.read_bytes()
    if patch_state(written) != "patched":
        raise PatchError("post-write verification failed")
    return {
        **status(path),
        "changed": True,
        "message": "CPU busy-loop patch applied",
        "backup": str(backup) if backup else None,
    }


def revert(path: Path) -> dict[str, object]:
    current = path.read_bytes()
    state = patch_state(current)
    if state == "original":
        return {**status(path), "changed": False, "message": "already original"}
    if state != "patched":
        raise PatchError("target bytes do not match this patch; refusing to revert")
    restored = bytearray(current)
    mutate(restored, apply_patch=False)
    if patch_state(restored) != "original":
        raise PatchError("internal verification failed before writing")
    atomic_replace(path, restored)
    written = path.read_bytes()
    if patch_state(written) != "original":
        raise PatchError("post-write verification failed")
    return {**status(path), "changed": True, "message": "patch reverted"}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Patch Isaac Repentance+ 1.9.7.17's idle worker busy loop."
    )
    parser.add_argument("command", choices=("status", "apply", "revert"))
    parser.add_argument("path", nargs="?", help="full path to isaac-ng.exe")
    parser.add_argument(
        "--allow-byte-compatible",
        action="store_true",
        help="allow an unknown file hash when every target byte still matches",
    )
    parser.add_argument(
        "--no-backup", action="store_true", help="do not create a backup before apply"
    )
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        path = resolve_executable(args.path)
        if args.command == "status":
            result = status(path)
        elif args.command == "apply":
            result = apply(path, args.allow_byte_compatible, not args.no_backup)
        else:
            result = revert(path)
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            for key, value in result.items():
                print(f"{key}: {value}")
        return 0
    except (OSError, PatchError) as exc:
        if args.json:
            print(json.dumps({"error": str(exc)}, ensure_ascii=False, indent=2))
        else:
            print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
