FROM ubuntu:24.04 AS runtime-base

ARG NODE_VERSION=24.11.1
ARG NODE_SHA256=60e3b0a8500819514aca603487c254298cd776de0698d3cd08f11dba5b8289a8
ARG OPENCODE_VERSION=1.19.0
ARG REA_VERSION=6.4.0
ARG GHIDRA_VERSION=12.1.4
ARG GHIDRA_RELEASE_DATE=20260921
ARG GHIDRA_SHA256=ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db
ARG APP_UID=1000
ARG APP_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils unzip openjdk-21-jdk-headless \
    python3 git ripgrep file binutils jq procps gcc g++ make \
    && rm -rf /var/lib/apt/lists/*

RUN test "$(dpkg --print-architecture)" = amd64 \
    && curl -fSL --retry 3 "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz \
    && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz

FROM runtime-base AS ghidra
COPY vendor/ghidra /tmp/ghidra-parts
RUN cd /tmp/ghidra-parts && sha256sum -c SHA256SUMS \
    && cat ghidra-*.zip.part-* > /tmp/ghidra.zip \
    && echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum -c - \
    && mkdir -p /opt/ghidra \
    && unzip -q /tmp/ghidra.zip -d /opt/ghidra \
    && mv "/opt/ghidra/ghidra_${GHIDRA_VERSION}_PUBLIC" /opt/ghidra/current \
    && rm -rf /tmp/ghidra.zip /tmp/ghidra-parts \
    && test -x /opt/ghidra/current/Ghidra/Features/Decompiler/os/linux_x86_64/decompile

FROM runtime-base
COPY --from=ghidra /opt/ghidra /opt/ghidra
RUN npm install --prefix /opt/tools --no-audit --no-fund \
      "opencode-ai@${OPENCODE_VERSION}" "rea-agents@${REA_VERSION}"

# Ubuntu's base image can already contain UID/GID 1000. Reuse or rename those
# identities without changing ownership anywhere outside the image's app home.
RUN test "$APP_UID" -gt 0 && test "$APP_GID" -gt 0 \
    && if getent group "$APP_GID" >/dev/null; then \
      groupmod -n analyst "$(getent group "$APP_GID" | cut -d: -f1)"; \
    else groupadd -g "$APP_GID" analyst; fi \
    && if getent passwd "$APP_UID" >/dev/null; then \
      usermod -l analyst -d /home/analyst -g analyst "$(getent passwd "$APP_UID" | cut -d: -f1)"; \
    else useradd -m -u "$APP_UID" -g analyst -s /bin/bash analyst; fi \
    && mkdir -p /workspace /home/analyst/.config/opencode \
      /home/analyst/.local/share/rea-web /home/analyst/.cache \
      /home/analyst/.agents/skills \
    && cp -R /opt/tools/node_modules/rea-agents/skills/reverse-engineer-anything /home/analyst/.agents/skills/ \
    && chown -R analyst:analyst /home/analyst /workspace

COPY entrypoint.sh instructions.md /opt/rea-web/
COPY tests /opt/rea-web/tests
RUN chmod +x /opt/rea-web/entrypoint.sh \
    && gcc -g -O0 /opt/rea-web/tests/fixtures/smoke.c -o /opt/rea-web/tests/fixtures/smoke

ENV HOME=/home/analyst \
    PATH=/opt/tools/node_modules/.bin:/usr/local/bin:/usr/bin:/bin \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    GHIDRA_INSTALL_DIR=/opt/ghidra/current \
    REA_ANALYSIS_PROVIDER=ghidra \
    OPENCODE_CONFIG=/home/analyst/.config/opencode/opencode.json \
    NPM_CONFIG_UPDATE_NOTIFIER=false

LABEL org.opencontainers.image.title="OpenCode REA Web" \
      org.opencontainers.image.description="Browser-based reverse engineering with OpenCode, REA and Ghidra" \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.licenses="MIT"

USER analyst
WORKDIR /workspace
EXPOSE 4096
ENTRYPOINT ["/opt/rea-web/entrypoint.sh"]
CMD ["opencode", "web", "--hostname", "0.0.0.0", "--port", "4096"]
