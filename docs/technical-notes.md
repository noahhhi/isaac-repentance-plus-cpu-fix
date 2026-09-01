# Technical notes

Repentance+ 1.9.7.17 contains an idle worker loop that immediately retries when
its task queue is empty. Profiling shows repeated
`RtlEnterCriticalSection`/`RtlLeaveCriticalSection` calls rather than a blocking
wait. The supported executable's empty-queue branch is at virtual address
`0x00A9E9C6`.

This patch redirects that branch to 20 bytes of unused `int3` alignment padding
at `0x00A9FF64`. The injected x86 code obtains its runtime address with a
`call`/`pop` pair, derives the relocated Sleep IAT slot, calls `Sleep(1)`, and
jumps back to `0x00A9EA9E`. It is therefore safe when Windows ASLR loads the
32-bit image away from its preferred `0x00400000` base.

The patcher requires both the known SHA-256 and the exact original bytes by
default. It writes through a temporary file in the game directory, atomically
replaces the executable, and verifies the result. It never includes or
downloads copyrighted game data.

## Why a normal Isaac Mod cannot fix it

Workshop/Lua Mods execute callbacks owned by the game's scripting runtime. The
busy loop is in a native engine worker and remains active even when there is no
Lua callback or gameplay update to run. The standard Mod API exposes neither
thread synchronization nor native memory patching, so Lua cannot make this
worker sleep.

A native loader or REPENTOGON-level binary extension could apply the same
machine-code change, but that is a separate native compatibility component—not
character gameplay logic. It should not be silently bundled into an ordinary
character Mod. If a larger project owns a native launcher, this patcher can be
called as an explicit optional pre-launch compatibility step.
