# AICE2011 — ROS 2 + Gazebo Lab

The whole lab — ROS 2 Jazzy, Gazebo Sim, TurtleBot3 and a Linux desktop — runs in
one container. You start it with one command and use it through your browser.

**Once you're in the browser, this guide has done its job.** The lab document
covers everything past this point.

---

## 1. Start Docker Desktop

The lab is a container, so Docker has to be running before anything else.

### Windows (lab PCs)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
   Leave **Use WSL 2 instead of Hyper-V** ticked — it is the default.
2. Start Docker Desktop and wait until it says *Engine running*.
3. Leave it in **Linux containers** mode, which is the default. This image is
   Linux-only; there is no Windows build.

### Linux

```bash
sudo apt update && sudo apt install -y docker.io    # Debian / Ubuntu
sudo usermod -aG docker $USER                      # then log out and back in
sudo systemctl enable --now docker
```

### macOS

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), or
`brew install docker colima` then `colima start --cpu 6 --memory 8 --disk 40`.
Either way the commands below are `docker compose` ones.

> Every command in this guide is a `docker` command and works identically as
> `podman`, provided a Compose provider is installed.

---

## 2. Point the lab at your workspace

Open **`.env`** in this folder. It is the only file you need to edit.

```ini
ROS2_WS=./ros2_ws
```

Set `ROS2_WS` to where your workspace actually lives. Use **forward slashes**:

| Where your workspace is | What to put |
| --- | --- |
| Next to this `.env` file | `ROS2_WS=./ros2_ws` |
| University H: drive | `ROS2_WS=H:/aice2011/ros2_ws` |
| Windows, local disk | `ROS2_WS=C:/Users/yourname/ros2_ws` |
| Linux | `ROS2_WS=/home/yourname/ros2_ws` |
| macOS | `ROS2_WS=/Users/yourname/ros2_ws` |

Docker creates the folder for you if it doesn't exist yet, so you do not need
to make it first.

If something else on your machine already uses port 6080, change `VNC_PORT` in
the same file, and use that port in the address in the next section.

---

## 3. Start the lab

Open a terminal in this folder. **PowerShell** on Windows, any terminal
elsewhere, and:

```bash
docker compose up -d
```

First run takes a minute or two while it downloads the image. Then open this
address in your browser:

**<http://127.0.0.1:6080/vnc.html?autoconnect=true>**

Use `127.0.0.1`, not `localhost` — on some systems `localhost` resolves to IPv6,
which the container's port forwarding does not answer on.

If you changed `VNC_PORT`, use that number instead of `6080`.

There is no password. **Don't change the address to anything but `127.0.0.1`**,
or anyone who can reach it can control your desktop.

---

## Everyday commands

All of these run in the terminal on your own computer, with this folder as the
working directory.

| I want to… | Command |
| --- | --- |
| Start the lab | `docker compose up -d` |
| Stop it (your work is kept) | `docker compose stop` |
| Stop and remove it | `docker compose down` |
| See what it's doing | `docker compose logs -f` |
| Restart it | `docker compose restart` |
| Update to the newest image | `docker compose pull && docker compose up -d` |
| Check it's running | `docker compose ps` |

Your work is in the `ROS2_WS` folder from step 2, on your own machine. Nothing
you do in the lab is lost when you `docker compose down`, and nothing outside
that folder is saved at all.

---

## Copy and paste

**To paste into the container, you must use noVNC's clipboard panel.** Browsers
block a page from silently sharing its clipboard, so there is no shortcut — no
other browser-based remote desktop avoids this.

Click the **clipboard icon** in the toolbar at the top right of the lab. A box
opens.

**Into the container:** copy the text on your computer, click into that box and
press `Ctrl+V`, then **click away from the box**. That is the whole trick —
the text is only sent once you click elsewhere, so a box you have not clicked
out of has sent nothing.

**Out of the container:** copy something inside the lab (`Ctrl+C`) and it
appears in that box by itself. Select it there and press `Ctrl+C` to put it on
your computer's clipboard.

As a convenience, pressing `Ctrl+V` over the desktop also sends what you pasted
to the container's clipboard, so you can paste it somewhere else later. It does
not replace the panel: the panel is what puts text *into* the container.

Every command you need is also written down **inside** the lab:
**Applications → Command Reference**.

---

## If it doesn't start

**`Error: lstat ros2_ws: no such file or directory`**
Docker Compose creates `ros2_ws` for you, so this means `ROS2_WS` in your `.env`
points somewhere that doesn't exist and can't be created. Check the path, and
that you started Compose from the folder containing `.env`.

**The page will not load**
Is the container up? `docker compose ps`. Then `docker compose logs` — a healthy
start prints six `entered RUNNING state` lines. If something else already owns
the port, change `VNC_PORT` in `.env` and use that port in the address.

**`error gathering: external label "com.docker..." does not exist`**
Docker Compose is too old for `create_host_path`. Update Docker Desktop.

**`Permission denied` inside `ros2_ws`**
On SELinux Linux, add `:Z` to the end of the `source` path in `compose.yaml`.
Not needed on Docker Desktop.

**Nothing will happen when you click a menu item**
The world takes 20–60 seconds to appear. The terminal that opened shows its
progress and any error — that log is the point of the menu items opening a
terminal.

**It is very slow**
Gazebo renders on the CPU, with no GPU, so this is expected. Closing the Gazebo
window helps a lot. 8 GB of RAM is the minimum; 16 GB is comfortable.

---

## What this is, in short

| | |
| --- | --- |
| Image | `ghcr.io/tgodfrey0/aice2011_container:latest`, ≈ 3.7 GB, pulled for you |
| Architectures | Intel/AMD and Apple Silicon |
| Base | Ubuntu 24.04, ROS 2 Jazzy, Gazebo Sim 8 (Harmonic), TurtleBot3 |
| Desktop | XFCE4 over noVNC and TigerVNC, user `student`, no password |
| Your files | `ROS2_WS` from `.env`, bind-mounted to `/home/student/ros2_ws` |
| Internet | Not needed once the image has been pulled |

**Limits.** No GPU, no audio, no camera passthrough. One desktop at a time.
Port 6080 is unauthenticated. Gazebo is slower than a native install.

---

<p align="center"><sub>Maintained for the AICE2011 module. Container contents: ROS 2 Jazzy, Gazebo Sim Harmonic, TurtleBot3, XFCE4, noVNC.</sub></p>