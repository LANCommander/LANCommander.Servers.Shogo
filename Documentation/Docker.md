---
sidebar_label: Docker
---

# Shogo: Mobile Armor Division Docker Container

This Docker container runs a Shogo: Mobile Armor Division dedicated server. It is built on the WINE image and runs the game's stand-alone server, `ShogoSrv.exe` v2.2, on a virtual display. The container doesn't download the game, so you provide the files.

## Quick Start

```yaml
services:
  shogo:
    image: lancommander/shogo:latest
    container_name: shogo

    ports:
      - 27888:27888/udp
      - 28037:28037/udp

    volumes:
      - "/data/Servers/Shogo/Deathmatch:/config"

    environment:
      SHOGO_SERVER_NAME: "My Shogo Server"
      SHOGO_LEVELS: "MCA_12FLOZ,MCA_AVERNUS,MCA_SPIRES"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Before the first start, copy a Shogo 2.2 install, the folder that contains `ShogoSrv.exe`, into `Server/`. You can instead set `SHOGO_ARCHIVE_URL` to a zip of that folder.

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitialization/20-InstallShogo.ps1` checks for `Server/ShogoSrv.exe`. If it's missing and `SHOGO_ARCHIVE_URL` is set, the hook downloads and extracts the archive and remounts the overlay.
3. `PostInitialization/30-ConfigureShogo.ps1` writes the non-empty `SHOGO_*` settings into `ShogoSrv.cfg` (`SHOGO_CONFIG`). It also adds any setup-wizard key the file lacks, with the wizard's default.
4. `START_EXE` (`/usr/local/bin/shogo-server`) runs `ShogoSrv.exe -config ShogoSrv.cfg -go [START_ARGS]` from the game folder under Wine and Xvfb.

ShogoSrv's console is a list box in its window, so `docker logs` ends at:

```
Starting: ShogoSrv.exe -config ShogoSrv.cfg -go
Game port 27888/udp, status queries on 28037/udp
```

To check that the server is up, send a GameSpy status query to the query port. The reply comes from the game port:

```bash
python3 -c 'import socket; s=socket.socket(2,2); s.settimeout(3); s.sendto(b"\\status\\",("<server>",28037)); print(s.recvfrom(4096)[0])'
# b'\\gamename\\shogo\\gamever\\shogo 2.2\\...\\hostname\\My Shogo Server\\hostport\\27888\\mapname\\MCA_12FLOZ\\...'
```

## Configuration Options

### Ports

- **27888/udp**: Game (`SHOGO_PORT`)
- **28037/udp**: GameSpy status queries. This is always the game port + 149, and it only answers when `SHOGO_GAMESPY=true`

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### ShogoSrv.cfg

ShogoSrv saves its setup wizard answers to `ShogoSrv.cfg` (or the file given with `-config`), as `"Key" "Value"` lines, and `-go` reads them back. The hook edits the file through the merged view, so the edited copy is in `Overlay/` and is yours to change. A key that also has a non-empty `SHOGO_*` variable is overwritten on every start. ShogoSrv itself rewrites the file when it shuts down cleanly.

| Key | Meaning |
|-----|---------|
| `ServerName`, `Port`, `MaxPlayers` | `Port` `0` means 27888 |
| `EndType` | Bit mask: `1` frag limit, `2` time limit, `3` both, `0` never ends |
| `EndFrags`, `EndTime` | The frag and minute limits |
| `NumLevels`, `Level0` ... | Rotation, as paths like `Worlds\Multi\MCA_12FLOZ` |
| `NumRezFiles`, `RezFile0` ... | Extra `.rez` resource files to load, e.g. from `Custom/` |
| `UseGameSpy`, `UpdateInfo`, `ServerReg` | The wizard's broadcast check boxes |
| `TractorBeam`, `DoubleJump`, `RammingDamage`, `RunSpeed`, `MissileSpeed`, `RespawnScale`, `HealScale`, `WorldTimeSpeed`, `WorldColorNight` | Game options |
| `DashGoInfo` | `1` hides the "Power users can specify -go" message box. The hook always sets it |
| `NetService`, `ServiceName`, `GameType` | Leave at `0`, `Internet TCP/IP` and `1` |

### Custom Levels

Put custom `.dat` levels and `.rez` files in `Overlay/Custom/`. Add levels to `SHOGO_LEVELS` with their path, e.g. `Custom\MyLevel`. Add `.rez` files to `ShogoSrv.cfg` with `NumRezFiles`/`RezFile0`. Clients need the same files.

### Hooks

| Hook | When |
|------|------|
| `PreInstallShogo` / `PostInstallShogo` | Around the game file check/download |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **The server never starts and no port is bound**: ShogoSrv is waiting at its setup wizard on the virtual display. `-go` only skips the wizard when the settings file has every wizard key and at least one level. Check the hook's log line, set `SHOGO_LEVELS`, or delete `Overlay/ShogoSrv.cfg` to regenerate it from the defaults.
- **Exits immediately without a display**: ShogoSrv is a GUI program. Keep `WINE_XVFB=true`.
- **`err:dplay:... Unable to load service provider` in Wine output**: ShogoSrv lists the DirectPlay services, which Wine doesn't provide. It's harmless, because the server uses the game's own TCP/IP driver (`Internet TCP/IP`), not DirectPlay.
- **Not in the in-game server list**: LAN discovery is untested with this image. Discovery by broadcast needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`). Clients can always join by IP.
- **No console output or console commands**: the console only exists in ShogoSrv's window. Change settings through the environment or `ShogoSrv.cfg` and restart.
