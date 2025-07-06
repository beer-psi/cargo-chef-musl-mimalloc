#!/bin/bash
set -euxo pipefail

RUST_LIBC_PATH=$(find /opt/rustup -name libc.a)

for LIBC_PATH in "$RUST_LIBC_PATH" "/usr/lib/x86_64-linux-musl/libc.a" "/usr/lib/aarch64-linux-musl/libc.a"; do
    if [ ! -f "$LIBC_PATH" ]; then
        continue
    fi

    {
        echo "CREATE libc.a"
        echo "ADDLIB $LIBC_PATH"
        echo "DELETE aligned_alloc.lo calloc.lo donate.lo free.lo libc_calloc.lo lite_malloc.lo malloc.lo malloc_usable_size.lo memalign.lo posix_memalign.lo realloc.lo reallocarray.lo valloc.lo"
        echo "ADDLIB libmimalloc.a"
        echo "SAVE"
    } | ar -M
    mv libc.a $LIBC_PATH
done
