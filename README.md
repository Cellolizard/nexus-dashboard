# Nexus Dashboard

Nexus Dashboard is a Flask app for operating a [Darkflame Universe](https://github.com/DarkflameUniverse/DarkflameServer) (DLU) game server: accounts, play keys, characters, moderation, mail, logs, and economy reports.

This repository is a maintained fork of [DarkflameUniverse/NexusDashboard](https://github.com/DarkflameUniverse/NexusDashboard). Upstream remains the original project. This tree is for UI modernization, reliability, cleanup, and operator QoL.

<p align="center">
  <img src="app/static/logo/logo.png" alt="Darkflame Universe logo"/>
</p>

## Contents

- [What's different](#whats-different)
- [Features](#features)
- [Before you start](#before-you-start)
- [Run with Docker](#run-with-docker)
- [Configure settings](#configure-settings)
- [Provide client files](#provide-client-files)
- [Install on Linux](#install-on-linux)
- [Install on Windows](#install-on-windows)
- [Develop](#develop)

<details>
<summary>On this page (expanded)</summary>

- [What's different](#whats-different)
- [Features](#features)
- [Before you start](#before-you-start)
- [Run with Docker](#run-with-docker)
  - [Required volumes](#required-volumes)
- [Configure settings](#configure-settings)
- [Provide client files](#provide-client-files)
- [Install on Linux](#install-on-linux)
  - [Install packages and clone the repo](#install-packages-and-clone-the-repo)
  - [Create the settings file](#create-the-settings-file)
  - [Install Python packages and migrate the database](#install-python-packages-and-migrate-the-database)
  - [Start the app](#start-the-app)
- [Install on Windows](#install-on-windows)
  - [Install prerequisites](#install-prerequisites)
  - [Clone the repo and create settings](#clone-the-repo-and-create-settings)
  - [Install packages and run migrations on Windows](#install-packages-and-run-migrations-on-windows)
  - [Start a development server](#start-a-development-server)
- [Develop](#develop)

</details>

## What's different

Compared to upstream:

- Missing CDClient rows or locale files no longer 500 pages and Ajax calls.
- Status icons are consistent across accounts, characters, pets, properties, and bug reports (success / danger / muted).
- Moderation QoL: Approve All, optional auto-approval, and a pending queue on the home dashboard for GM 3+.
- The Docker image includes MagickWand headers and a compiler so native deps install.

Published image: `ghcr.io/cellolizard/nexus-dashboard:latest` (built from `main`).

## Features

- **Accounts:** ban, lock, mute (all characters), delete, optional email verification / password reset / admin email edit, registration.
- **Play keys:** create, edit, note, and list tied accounts.
- **Characters:** rescue to a visited world; restrict trade, mail, and chat; inventory and stats viewers.
- **Moderation:** character and pet names, properties (including in-browser 3D view), Approve All, optional auto-approval, pending counts on home (GM 3+).
- **Bug reports, mail, logs, and economy reports** (items, currency, U-Score; daily job at 23:00 UTC; GM 3+ ignored).

<details>
<summary>Full feature list</summary>

- Account management
  - Ban, lock, and mute accounts (mute applies to all characters)
  - Account deletion
  - Optional email: verification, password reset, admin email edit, registration
- Play key management
  - Create, edit, and add notes
  - View accounts tied to a play key
- Character management
  - Rescue: pull a character to a previously visited world
  - Restrict trade, mail, and chat
  - Inventory viewer (backpack, vault, models, and more)
  - Stats viewer
- Moderation
  - Character names: approve, mark as needs rename, Approve All
  - Pet names: hourly auto-moderation from already moderated names, character association, cleanup of deleted pets/characters, Approve All
  - Properties: approve and unapprove, Approve All
  - Property and model viewer: pre-built and UGC, 360° in the browser, LOD0–LOD2, download
  - Approve All pending items at once
  - Optional auto-approval (interval stored in dashboard settings)
  - Pending counts and a short queue on the home dashboard (GM 3+)
- Bug reports: view and resolve
- Logs
  - Command, activity (world enter/exit)
  - Audit: moderation, GM-level changes, send-mail usage
  - System: background activity
- Send mail, with optional item attachments
- Economy reports (scheduled daily at 23:00 UTC; accounts with GM level 3 and above are ignored)
  - Items in existence (backpack and vault)
  - Currency and U-Score per character

</details>

## Before you start

You need a working DLU server and a MySQL-compatible database the dashboard can reach.

If you expose the dashboard outside a LAN, put it behind a reverse proxy with TLS:

- [Configure Nginx as a reverse proxy](https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04)
- [Secure Nginx with Let's Encrypt](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-22-04)

Docker is the supported production path. Linux and Windows sections are source installs.

## Run with Docker

The image is `ghcr.io/cellolizard/nexus-dashboard:latest`. On start, the entrypoint runs `flask db upgrade`, then Gunicorn.

```bash
docker run -d \
    -e APP_SECRET_KEY='<secret_key>' \
    -e APP_DATABASE_URI='mysql+pymysql://<username>:<password>@<host>:<port>/<database>' \
    -e REQUIRE_PLAY_KEY=True \
    -p 8000:8000/tcp \
    -v /path/to/logs:/logs:rw \
    -v /path/to/unpacked/client:/app/luclient:ro \
    -v /path/to/cachedir:/app/cache:rw \
    ghcr.io/cellolizard/nexus-dashboard:latest
```

Pass any other setting from `app/settings_example.py` as an environment variable.

### Required volumes

| Host path | Container path | Mode | Purpose |
| --- | --- | --- | --- |
| Unpacked client (`res/` and `locale/` are enough) | `/app/luclient` | read-only | Client assets and `cdclient.sqlite` |
| Cache directory | `/app/cache` | read-write | Generated model/image cache |
| Log directory | `/logs` | read-write | App logs |

Convert `res/cdclient.fdb` with lcdr's `fdb_to_sqlite.py` and place the result at `res/cdclient.sqlite` in the mounted client. You can also copy `CDServer.sqlite` from the DLU server and rename it to `cdclient.sqlite`. See [Provide client files](#provide-client-files).

## Configure settings

All keys live in `app/settings_example.py`. Copy that file to `app/settings.py` for a source install, or set the same names as environment variables in Docker.

| Name | Required | Notes |
| --- | --- | --- |
| `APP_SECRET_KEY` | Yes | Any 32-character random string |
| `APP_DATABASE_URI` | Yes | `mysql+pymysql://USERNAME:PASSWORD@HOST[:PORT]/DATABASE` |
| Everything else | No | Defaults in `settings_example.py` |

If the database is on the same host and uses the default port, omit `:PORT` and the colon:

```python
APP_SECRET_KEY = "abcdefghijklmnopqrstuvwxyz123456"
APP_DATABASE_URI = "mysql+pymysql://DBusername:DBpassword@localhost/DBname"
```

Email registration, invitations, and password recovery need extra mail setup not covered here.

## Provide client files

All install methods need client assets under `app/luclient` (or the Docker mount of that path).

Copy the following from the unpacked client:

```text
locale/locale.xml
res/BrickModels/
res/brickprimitives/
res/textures/
res/ui/
res/brickdb.zip
```

Unzip `brickdb.zip` in `res/` and delete the zip. You should end up with `Assemblies/`, `Primitives/`, `Materials.xml`, and `info.xml` alongside the folders you copied.

Put the client database at `app/luclient/res/cdclient.sqlite`. Either convert `cdclient.fdb` with lcdr's utilities, or copy `CDServer.sqlite` from the DLU server and rename it:

```bash
mv app/luclient/res/CDServer.sqlite app/luclient/res/cdclient.sqlite
```

## Install on Linux

Debian-family walkthrough. Credit: [HailStorm32](https://github.com/HailStorm32). Clone into `~/NexusDashboard` so the paths in this section match.

### Install packages and clone the repo

1. Install packages:

   ```bash
   sudo apt-get update
   sudo apt-get install -y python3 python3-pip sqlite3 git unzip libmagickwand-dev
   ```

   If `sqlite3` is not available, install `sqlite` instead.

2. Clone this repository into your home directory:

   ```bash
   cd ~
   git clone https://github.com/Cellolizard/nexus-dashboard.git NexusDashboard
   ```

### Create the settings file

1. Copy the example settings:

   ```bash
   cp ~/NexusDashboard/app/settings_example.py ~/NexusDashboard/app/settings.py
   ```

2. Edit `~/NexusDashboard/app/settings.py` and set `APP_SECRET_KEY` and `APP_DATABASE_URI`. See [Configure settings](#configure-settings).

3. Add client files under `~/NexusDashboard/app/luclient` as described in [Provide client files](#provide-client-files).

   ```bash
   mv ~/NexusDashboard/app/luclient/res/CDServer.sqlite \
      ~/NexusDashboard/app/luclient/res/cdclient.sqlite
   ```

### Install Python packages and migrate the database

```bash
cd ~/NexusDashboard
pip install -r requirements.txt
pip install gunicorn
flask db upgrade
```

### Start the app

```bash
gunicorn -b :8000 -w 4 wsgi:app
```

## Install on Windows

This path is a development server only. Production on Windows is not supported; use Docker.

### Install prerequisites

- [Python 3.11](https://www.python.org/downloads/) (matches the Docker image)
- [Git](https://git-scm.com/downloads)
- [ImageMagick](https://docs.wand-py.org/en/latest/guide/install.html#install-imagemagick-on-windows)
- [7-Zip](https://www.7-zip.org/download.html)

### Clone the repo and create settings

1. Open a command prompt, go to the directory where you want the project (for example Desktop), and clone:

   ```bat
   git clone https://github.com/Cellolizard/nexus-dashboard.git NexusDashboard
   ```

2. Copy settings:

   ```bat
   cd NexusDashboard\app
   copy settings_example.py settings.py
   notepad settings.py
   ```

3. Set `APP_SECRET_KEY` and `APP_DATABASE_URI`. See [Configure settings](#configure-settings).

4. Add client files under `NexusDashboard\app\luclient` as described in [Provide client files](#provide-client-files). Unzip `brickdb.zip` with **7-Zip > Extract Here**, then delete the zip. Rename `CDServer.sqlite` to `cdclient.sqlite`.

### Install packages and run migrations on Windows

From the repo root (`NexusDashboard`):

```bat
pip install -r requirements.txt
flask db upgrade
```

### Start a development server

```bat
flask run
```

This is not a production server.

## Develop

Use [EditorConfig](https://editorconfig.org/) so indentation and line endings stay consistent.

```bash
python3 -m flask run
```
