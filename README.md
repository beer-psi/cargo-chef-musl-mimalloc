## cargo-chef-musl-mimalloc

A Docker environment for building static, **performant** Rust binaries using [`musl`](https://musl.libc.org)
and [`mimalloc`](https://github.com/microsoft/mimalloc), with caching done by
[`cargo-chef`](https://github.com/LukeMathWalker/cargo-chef).

The goal is to provide a set of opinionated defaults for building small, efficient and fast containers,
with caching to speed up CI build times.

## Example 

```dockerfile
FROM beerpsi/cargo-chef-musl-mimalloc:latest AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM gcr.io/distroless/static AS runtime
WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /app/target/x86_64-unknown-linux-musl/release/executable /app/
USER nonroot
CMD ["/app/executable"]
```

## Credits

This is just a patched together image, built on the shoulders of giants:
- [`muslrust`](https://github.com/clux/muslrust)
- [`cargo-chef`](https://github.com/LukeMathWalker/cargo-chef)
- [`mimalloc`](https://github.com/microsoft/mimalloc)
- [`rust-alpine-mimalloc`](github.com/tweag/rust-alpine-mimalloc), which originally came up with the
idea of replacing the `musl` allocator with `mimalloc`.
