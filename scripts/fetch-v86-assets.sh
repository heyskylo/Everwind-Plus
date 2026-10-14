#!/usr/bin/env bash
#
# Downloads the v86 x86 emulator runtime plus a Tiny Core Linux ISO into
# Everwind/V86Assets/ so they can be bundled into the Everwind app.
#
# v86 translates guest x86 machine code into WebAssembly at runtime. WebKit
# compiles that WebAssembly ahead of time inside its own (entitled) process, so
# no JIT entitlement is required by the app itself.
#
# Run this once before building locally, and it runs automatically in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/Everwind/V86Assets"

V86_VERSION="0.5.462"
NPM="https://cdn.jsdelivr.net/npm/v86@${V86_VERSION}"
GH="https://raw.githubusercontent.com/copy/v86/master"

mkdir -p "$DEST"

# download <url> <filename> <minimum-bytes>
download() {
    local url="$1" name="$2" min="${3:-1}"
    local out="$DEST/$name"

    if [[ -f "$out" ]]; then
        local have
        have="$(wc -c < "$out" | tr -d ' ')"
        if (( have >= min )); then
            echo "  ok      $name ($have bytes)"
            return 0
        fi
    fi

    echo "  fetch   $name"
    local tmp="$out.part"
    rm -f "$tmp"
    curl -fSL --retry 3 --retry-delay 2 -o "$tmp" "$url"

    local size
    size="$(wc -c < "$tmp" | tr -d ' ')"
    if (( size < min )); then
        echo "ERROR: $name is only $size bytes (expected >= $min)" >&2
        rm -f "$tmp"
        exit 1
    fi

    mv "$tmp" "$out"
    echo "  done    $name ($size bytes)"
}

echo "==> Fetching v86 runtime into $DEST"
download "$NPM/build/libv86.js"         "libv86.js"          300000
download "$NPM/build/v86.wasm"          "v86.wasm"           1000000
download "$NPM/build/v86-fallback.wasm" "v86-fallback.wasm"  1000000
download "$GH/bios/seabios.bin"         "seabios.bin"        100000
download "$GH/bios/vgabios.bin"         "vgabios.bin"        30000

echo "==> Fetching Tiny Core Linux (x86) live ISO"
download "https://i.copy.sh/TinyCore-11.0.iso" "TinyCore-11.0.iso" 10000000

echo "==> Done. Bundled assets in Everwind/V86Assets/"
