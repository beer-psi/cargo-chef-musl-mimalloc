ARG ALPINE_VERSION=3.21
ARG MUSLRUST_VERSION=1.88.0-stable-2025-07-05

###############################################################################
# Step 1: Building the mimalloc library
# This builds the mimalloc library on a separate container, so the final result
# can simply be copied to whatever other stage needs it, without polluting
# the final container.
###############################################################################
FROM alpine:$ALPINE_VERSION AS mimalloc-builder

RUN apk upgrade --no-cache
RUN apk add --no-cache alpine-sdk clang cmake curl mold ninja-is-really-ninja
RUN find /usr -type f -executable -name "ld" -exec sh -c 'ln -sf /usr/bin/ld.mold {}' \;

WORKDIR /tmp
ARG MIMALLOC_VERSION=3.0.3
RUN curl -f -L --retry 5 https://github.com/microsoft/mimalloc/archive/refs/tags/v$MIMALLOC_VERSION.tar.gz | tar xz
COPY build/mimalloc.diff /tmp

WORKDIR /tmp/mimalloc-$MIMALLOC_VERSION

RUN patch -p1 < /tmp/mimalloc.diff
RUN cmake \
  -Bout \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DMI_BUILD_OBJECT=OFF \
  -DMI_BUILD_TESTS=OFF \
  -DMI_LIBC_MUSL=ON \
  -DMI_SKIP_COLLECT_ON_EXIT=ON \
  -G Ninja \
  .
RUN cmake --build out --target install -- -v
RUN cp out/libmimalloc.* /usr/local/lib/ \
  && mkdir -p /usr/local/lib/pkgconfig \
  && cp out/mimalloc.pc /usr/local/lib/pkgconfig/
RUN rm -rf /tmp/mimalloc.diff /tmp/mimalloc-$MIMALLOC_VERSION

###############################################################################
# Step 2: Preparing the muslrust container for building our project
# - Installs cargo-chef for caching Rust Docker builds
# - Installs mold and forces it to be the default system linker
# - Patches musl libc.a (from Rust and system-wide) to use mimalloc
###############################################################################
FROM clux/muslrust:$MUSLRUST_VERSION AS chef
USER root

RUN cargo install cargo-chef --locked && rm -rf $CARGO_HOME/registry/
RUN apt-get update \
  && apt-get install -y mold \
  && rm -rf /var/lib/apt/lists/* \
  && find /usr -type f -executable -name "ld" -exec sh -c 'ln -sf /usr/bin/ld.mold {}' \;

WORKDIR /tmp

COPY build/patch-libc-with-mimalloc.sh /tmp
COPY --from=mimalloc-builder /usr/local/lib/libmimalloc.a libmimalloc.a
RUN chmod +x /tmp/patch-libc-with-mimalloc.sh \
    && /tmp/patch-libc-with-mimalloc.sh \
    && rm -rf /tmp/patch-libc-with-mimalloc.sh /tmp/libmimalloc.a

WORKDIR /volume
