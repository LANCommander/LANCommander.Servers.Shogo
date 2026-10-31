# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Shogo 2.2 install (ShogoSrv.exe, SHOGO.REZ ...) in
#     /config/Server, or set SHOGO_ARCHIVE_URL to a zip of one
#   - ShogoSrv.exe is a GUI app. Its setup wizard is skipped with -go, which reuses the settings
#     saved in SHOGO_CONFIG. The SHOGO_* settings below are written into that file on every start
#     (empty settings are left alone)
#   - SHOGO_LEVELS is a comma-separated rotation; bare names are looked up in Worlds\Multi
#   - SHOGO_FRAG_LIMIT / SHOGO_TIME_LIMIT end a level; 0 turns that limit off
#   - The server needs a window, so it runs under Xvfb
# ----------------------------
ENV SHOGO_ARCHIVE_URL="" \
    SHOGO_CONFIG="ShogoSrv.cfg" \
    SHOGO_SERVER_NAME="Shogo Server" \
    SHOGO_PORT="27888" \
    SHOGO_MAX_PLAYERS="16" \
    SHOGO_LEVELS="MCA_12FLOZ,MCA_AVERNUS,MCA_ENTRANCE,MCA_MADSKILLS,MCA_MARITROPA1,MCA_MARITROPA2,MCA_MARITROPA3,MCA_SHINARA,MCA_SPIRES,MCA_ZERO" \
    SHOGO_FRAG_LIMIT="25" \
    SHOGO_TIME_LIMIT="0" \
    SHOGO_GAMESPY="true" \
    SHOGO_REGISTER="false" \
    SHOGO_TRACTOR_BEAM="" \
    SHOGO_DOUBLE_JUMP="" \
    SHOGO_RAMMING_DAMAGE="" \
    SHOGO_RUN_SPEED="" \
    SHOGO_MISSILE_SPEED="" \
    SHOGO_RESPAWN_SCALE="" \
    SHOGO_HEAL_SCALE="" \
    SHOGO_WORLD_TIME_SPEED="" \
    SHOGO_WORLD_COLOR_NIGHT="" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/shogo-server" \
    START_ARGS=""

COPY Scripts/shogo-server /usr/local/bin/shogo-server
RUN chmod +x /usr/local/bin/shogo-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27888/udp: game (SHOGO_PORT)
# 28037/udp: GameSpy status queries, always the game port + 149 (SHOGO_GAMESPY)
EXPOSE 27888/udp
EXPOSE 28037/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
