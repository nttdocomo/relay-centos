# FROM python:3.6.13-slim-buster
FROM centos:7.8.2003

ARG BUILD_ARCH=x86_64
# Pin the Rust version for now
ARG RUST_TOOLCHAIN_VERSION=1.59.1
ENV BUILD_ARCH=${BUILD_ARCH}
ENV BUILD_TARGET=${BUILD_ARCH}-unknown-linux-gnu
ENV RUST_TOOLCHAIN_VERSION=${RUST_TOOLCHAIN_VERSION}

ARG RELAY_FEATURES=ssl,processing
ENV RELAY_FEATURES=${RELAY_FEATURES}

# ENV RUSTUP_HOME=/usr/local/rustup \
#     CARGO_HOME=/usr/local/cargo \
#     PATH=/usr/local/cargo/bin:$PATH

# relay的编译依赖cmake3.2以上，系统默认的是2.8.12.2
COPY ./cmake-3.24.3.tar.gz /
COPY ./sentry-cli-Linux-x86_64 /bin/sentry-cli
# COPY ./relay /relay
RUN set -x \
    && yum --nogpg install -y gcc gcc-c++ make openssl-devel zip git \
    && tar zxvf cmake-3.* \
    && rm cmake-3.*tar.gz \
    && cd cmake-3.* \
    && ./bootstrap --prefix=/usr/local \
    && make -j$(nproc) \
    && make install \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain=${RUST_TOOLCHAIN_VERSION} \
    && chmod ugo+x /bin/sentry-cli \
    && rm -rf /cmake-3.* \
    && yum clean all

RUN git clone --branch 21.5.0 https://github.com/getsentry/relay.git \
    && cd ./relay \
    && make build-linux-release TARGET=${BUILD_TARGET} RELAY_FEATURES=${RELAY_FEATURES} \
    && cp ./target/$BUILD_TARGET/release/relay /opt/relay \
    && zip /opt/relay-debug.zip target/$BUILD_TARGET/release/relay.debug

# Collect source bundle
RUN sentry-cli --version \
    && sentry-cli difutil bundle-sources ./target/$BUILD_TARGET/release/relay.debug \
    && mv ./target/$BUILD_TARGET/release/relay.src.zip /opt/relay.src.zip
