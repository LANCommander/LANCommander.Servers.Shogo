# Shogo: Mobile Armor Division Server (Docker)

This repository provides a Dockerized **Shogo: Mobile Armor Division** dedicated server. Shogo (Monolith, 1998) ships a Windows-only stand-alone server, `ShogoSrv.exe` (v2.2), which the image runs under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail `ShogoSrv.exe` with `-go`, so its setup wizard is skipped
- Server name, port, player limit, level rotation, frag/time limits and gameplay options are environment variables, written into `ShogoSrv.cfg` on every start
- ShogoSrv is a GUI app, so it runs on a virtual display (Xvfb)
- GameSpy `\status\` queries for monitoring
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  shogo:
    image: lancommander/shogo:latest
    container_name: shogo

    ports:
      - "27888:27888/udp"
      - "28037:28037/udp"

    volumes:
      - ./config:/config

    environment:
      SHOGO_SERVER_NAME: "My Shogo Server"
      SHOGO_LEVELS: "MCA_12FLOZ,MCA_AVERNUS,MCA_SPIRES"
      SHOGO_FRAG_LIMIT: "25"
      SHOGO_TIME_LIMIT: "15"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

Shogo is retail software with no public download. You must provide an install patched to **2.2** or later, which includes `ShogoSrv.exe`, `server.dll` and `SHOGO.REZ`:

- copy the game folder (the one containing `ShogoSrv.exe`) to `config/Server/`, **or**
- set `SHOGO_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/ShogoSrv.exe` doesn't exist yet.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Shogo install (ShogoSrv.exe, server.dll, SHOGO.REZ, Custom/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated ShogoSrv.cfg lands here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The `SHOGO_*` server settings are written into `SHOGO_CONFIG` on every start. Settings left empty are not touched, so you can set them in that file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `SHOGO_CONFIG` | Settings file in the game folder (`-config`) | `ShogoSrv.cfg` |
| `SHOGO_SERVER_NAME` | `ServerName` | `Shogo Server` |
| `SHOGO_PORT` | Game port (`Port`). GameSpy queries use this port + 149 | `27888` |
| `SHOGO_MAX_PLAYERS` | `MaxPlayers` | `16` |
| `SHOGO_LEVELS` | Comma-separated level rotation. A bare name is a retail level in `Worlds\Multi`; give a path with a backslash for others, e.g. `Custom\MyLevel` | all ten retail levels |
| `SHOGO_FRAG_LIMIT` | Frags that end a level, `0` = none (`EndFrags`) | `25` |
| `SHOGO_TIME_LIMIT` | Minutes that end a level, `0` = none (`EndTime`) | `0` |
| `SHOGO_GAMESPY` | Answer GameSpy queries and send master server heartbeats (`UseGameSpy`) | `true` |
| `SHOGO_REGISTER` | Register with the (defunct) shogo-mad.com server list (`ServerReg`) | `false` |
| `SHOGO_TRACTOR_BEAM` | `TractorBeam` | |
| `SHOGO_DOUBLE_JUMP` | `DoubleJump` | |
| `SHOGO_RAMMING_DAMAGE` | `RammingDamage` | |
| `SHOGO_RUN_SPEED` | Run speed multiplier (`RunSpeed`, game default `1.3`) | |
| `SHOGO_MISSILE_SPEED` | TOW missile speed multiplier (`MissileSpeed`) | |
| `SHOGO_RESPAWN_SCALE` | Item respawn rate multiplier (`RespawnScale`) | |
| `SHOGO_HEAL_SCALE` | Health powerup multiplier (`HealScale`) | |
| `SHOGO_WORLD_TIME_SPEED` | Seconds per day/night cycle, `-1` = off (`WorldTimeSpeed`) | |
| `SHOGO_WORLD_COLOR_NIGHT` | Night light color, `"r g b"` from 0 to 1 (`WorldColorNight`) | |
| `SHOGO_ARCHIVE_URL` | Zip of the game folder, used if `Server/ShogoSrv.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. ShogoSrv needs one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/shogo-server` |
| `START_ARGS` | Added to the `ShogoSrv.exe` command line | |

Retail levels: `MCA_12FLOZ`, `MCA_AVERNUS`, `MCA_ENTRANCE`, `MCA_MADSKILLS`, `MCA_MARITROPA1`, `MCA_MARITROPA2`, `MCA_MARITROPA3`, `MCA_SHINARA`, `MCA_SPIRES`, `MCA_ZERO`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/shogo:local .
```

---

## License

Shogo: Mobile Armor Division and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
