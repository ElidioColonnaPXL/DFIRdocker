# syntax=docker/dockerfile:1
ARG PYTHON_IMAGE=python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df

FROM ${PYTHON_IMAGE} AS builder
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git libssl-dev libusb-1.0-0-dev pkg-config zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
RUN python -m venv /opt/venv
COPY requirements.txt /tmp/requirements.txt
RUN /opt/venv/bin/pip install -r /tmp/requirements.txt \
    && /opt/venv/bin/pip check

# Preserve the upstream collection, including READMEs and license information.
# It contains old plugins and links to external projects, not a supported plugin pack.
ARG COMMUNITY3_COMMIT=5ae4e232e14667277a0cc74848b87b634b4d8ad1
RUN git init /opt/community3 \
    && git -C /opt/community3 remote add origin https://github.com/volatilityfoundation/community3.git \
    && git -C /opt/community3 fetch --depth 1 origin "${COMMUNITY3_COMMIT}" \
    && git -C /opt/community3 checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/community3 rev-parse HEAD)" = "${COMMUNITY3_COMMIT}" \
    && printf '%s\n' "${COMMUNITY3_COMMIT}" > /opt/community3/UPSTREAM_COMMIT \
    && rm -rf /opt/community3/.git

FROM ${PYTHON_IMAGE} AS runtime
LABEL org.opencontainers.image.title="DFIRdocker" \
      org.opencontainers.image.description="DFIR toolbox with Volatility 3 and an archived community plugin collection" \
      org.opencontainers.image.source="https://github.com/ElidioColonnaPXL/DFIRdocker"
ENV PATH="/opt/dfir/bin:/opt/venv/bin:${PATH}" \
    HOME=/tmp/dfir-home \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    LC_ALL=C.UTF-8
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash binutils ca-certificates coreutils curl ewf-tools file findutils \
    jq less libimage-exiftool-perl libusb-1.0-0 p7zip-full ripgrep \
    sleuthkit sqlite3 tshark unzip yara \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 dfir \
    && useradd --uid 1000 --gid dfir --no-create-home --shell /bin/bash dfir \
    && mkdir -p /evidence /output /symbols /plugins /cache/volatility3 /opt/dfir \
    && chown -R dfir:dfir /output /cache /symbols /plugins
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/community3 /opt/community3
COPY bin/ /opt/dfir/bin/
COPY tests/smoke.py /opt/dfir/smoke.py
COPY requirements.txt /opt/dfir/requirements.txt
RUN chmod 0755 /opt/dfir/bin/vol /opt/dfir/bin/vol-community \
    && ln -s vol /opt/dfir/bin/vol3 \
    && ln -s vol /opt/dfir/bin/volatility3 \
    && /opt/venv/bin/pip freeze > /opt/dfir/python-packages.txt \
    && dpkg-query -W > /opt/dfir/debian-packages.txt
USER dfir
WORKDIR /output
# Run on every target architecture; an unimportable built-in plugin fails the build.
RUN python /opt/dfir/smoke.py
CMD ["bash"]
