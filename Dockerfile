# Minimalne środowisko do uruchamiania Godota 4.4.1 w trybie headless
FROM debian:bookworm-slim

ARG GODOT_VER=4.4.1
ARG GODOT_FLAVOR=stable
# Jeśli zmieni się nazewnictwo plików w release, zaktualizuj URL-e poniżej.
ARG GODOT_ZIP=Godot_v${GODOT_VER}-${GODOT_FLAVOR}_linux.x86_64.zip
ARG GODOT_URL=https://downloads.tuxfamily.org/godotengine/${GODOT_VER}/${GODOT_ZIP}
ARG TEMPLATES_TPZ=Godot_v${GODOT_VER}-${GODOT_FLAVOR}_export_templates.tpz
ARG TEMPLATES_URL=https://downloads.tuxfamily.org/godotengine/${GODOT_VER}/${TEMPLATES_TPZ}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget unzip \
    libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 \
    libasound2 libpulse0 fontconfig \
 && rm -rf /var/lib/apt/lists/*

# Pobranie Godota (editor bin działa headless via --headless)
RUN wget -O /tmp/godot.zip "${GODOT_URL}" \
 && unzip /tmp/godot.zip -d /usr/local/bin \
 && mv /usr/local/bin/Godot_v${GODOT_VER}-${GODOT_FLAVOR}_linux.x86_64 /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm -f /tmp/godot.zip

# Export Templates (dla --export/--export-release)
# Godot szuka ich w: ~/.local/share/godot/export_templates/<version>.stable/
RUN wget -O /tmp/templates.tpz "${TEMPLATES_URL}" \
 && mkdir -p /root/.local/share/godot/export_templates/${GODOT_VER}.stable \
 && unzip -q /tmp/templates.tpz -d /root/.local/share/godot/export_templates/${GODOT_VER}.stable \
 && rm -f /tmp/templates.tpz

# Domyślny katalog pracy
WORKDIR /workspace

# Szybki test: wersja
CMD ["godot", "--version"]
