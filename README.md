# AICE2011 — ROS 2 + Gazebo Container Lab

This repository gives you a complete **ROS 2 Jazzy + Gazebo Sim (Harmonic) + TurtleBot3** environment as a single container image. Everything runs inside the container, and you reach it through **a web browser** — there is no VM to import, nothing to install on your own machine beyond a container runtime, and no dual-booting.

Once it is running, open a URL in your browser and you get a full Linux desktop (XFCE4) with a terminal, Gazebo and TurtleBot3 already installed and configured. Your ROS 2 workspace lives on your machine's disk, so your code is not lost when the container is thrown away.

```
┌──────────────┐   http://127.0.0.1:6080   ┌──────────────────────────────┐
│   your        │ ────────────────────────► │  container                   │
│   browser     │        (noVNC/VNC)        │  ┌────────────────────────┐  │
└──────────────┘                            │  │ XFCE4 desktop           │  │
                                            │  │ ROS 2 Jazzy            │  │
┌──────────────┐   bind mount              │  │ Gazebo Sim 8 (Harmonic) │  │
│ ./ros2_ws    │ ◄────────────────────────► │  │ TurtleBot3              │  │
│ (your files) │                            │  └────────────────────────┘  │
└──────────────┘                            └──────────────────────────────┘
```

---

## Contents

- [What's in the container](#whats-in-the-container)
- [Requirements](#requirements)
- [Before you start: a 60-second checklist](#before-you-start-a-60-second-checklist)
- [Quick start (one command)](#quick-start-one-command)
  - [Option A — docker compose (easiest)](#option-a--docker-compose-easiest)
  - [Option B — pull the prebuilt image](#option-b--pull-the-prebuilt-image)
  - [Option C — build it yourself](#option-c--build-it-yourself)
- [Setting up on your machine](#setting-up-on-your-machine)
  - [Windows](#windows)
  - [Linux](#linux)
  - [macOS](#macos)
- [Using the lab](#using-the-lab)
  - [1. Open the desktop](#1-open-the-desktop)
  - [2. Start the TurtleBot3 simulation](#2-start-the-turtlebot3-simulation)
  - [3. Drive the robot](#3-drive-the-robot)
  - [4. Build your own ROS 2 workspace](#4-build-your-own-ros-2-workspace)
  - [5. Other worlds](#5-other-worlds)
  - [Command cheat sheet](#command-cheat-sheet)
- [Everyday container management](#everyday-container-management)
- [Where your work is saved](#where-your-work-is-saved)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)
- [Getting help](#getting-help)

---

## What's in the container

| Component | Version / detail |
| --- | --- |
| Base OS | Ubuntu 24.04 (Noble) |
| ROS 2 | **Jazzy** (auto-sourced when you open a terminal) |
| Gazebo Sim | **8.15.0** (Harmonic) via `ros-jazzy-ros-gz` and `ros-jazzy-gz-ros2-control` |
| TurtleBot3 | `simulations`, `gazebo`, `description`, `teleop`, `bringup` |
| Robot model | `TURTLEBOT3_MODEL=waffle_pi` (also accepts `burger` and `waffle`) |
| Desktop | XFCE4 + Openbox, running on a virtual display (Xvfb) |
| Remote access | x11vnc + noVNC, served on **port 6080** |
| User | `student` (passwordless `sudo`) |
| Build tools | `colcon`, `python3-colcon-common-extensions`, `git` |
| Architectures | `linux/amd64` and `linux/arm64` — covers Intel/AMD and Apple Silicon on Linux, macOS and Windows |
| Image size | ≈ 3.7 GB on disk |

The desktop, virtual display, VNC server and noVNC proxy are all started by `supervisor`, so they come up automatically every time you run the container.

---

## Requirements

| | Minimum | Recommended |
| --- | --- | --- |
| CPU | 4 cores | 8+ cores (Gazebo is CPU-bound) |
| RAM | 8 GB free | 16 GB |
| Disk | 15 GB free | 25 GB+ |
| Browser | Any modern Chrome, Edge, Firefox or Safari | — |

A ready-made image is published on GitHub Container Registry, so the normal route is to `podman pull` or `docker pull` it and start it in about a minute — no GitHub account or login required. Downloading it needs roughly **5 GB** of free disk space.

If you would rather build the image from this repository, the first build takes roughly **5–20 minutes** depending on your machine and internet speed and produces a 3.7 GB image. Every build after that reuses the cache and finishes in seconds unless you change the `Containerfile`.

> **macOS and Windows run the image inside a small virtual machine.** Give that virtual machine at least 8 GB of RAM (see the platform sections below) or Gazebo will crawl.

---

## Before you start: a 60-second checklist

Do these three things first. They cover almost every problem people hit, and each one fails with a confusing message if you skip it.

### 1. Get the code, and check you are in the right folder

Clone the repository (or download it and unzip it). **All the commands in this README are relative to the folder you unzipped**, so `cd` into it before you do anything else:

```bash
cd ~/aice2011_container        # <- whatever you actually called it
```

You should see these files:

```bash
ls
#   Containerfile  entrypoint.sh  README.md  ros2_ws  supervisord.conf
```

If `ros2_ws` is missing from that list, go to step 2.

### 2. Make sure the `ros2_ws` folder exists

Your work is saved in `ros2_ws`, and the start commands mount it into the container. The folder ships with the repository, but it is **empty**, so:

- **Windows Explorer's default view hides empty folders.** Use *View → Show → Hidden items*, or just run the command below.
- **Some unzip tools skip empty folders.** Check with `ls ros2_ws` rather than trusting the file browser.
- If you deleted it by accident, recreate it:

```bash
mkdir -p ros2_ws/src
```

That must succeed **before** you start the container.

> **Using [Option A](#option-a--docker-compose-easiest)? You can skip this step.** `docker compose up -d` creates `ros2_ws` for you if it is missing, and fixes its ownership so the `student` user inside the container can write to it.

### 3. Check you have room and memory

```bash
df -h .          # need ~5 GB free for the image, 15 GB to be comfortable
free -h          # need 8 GB free RAM (16 GB+ recommended for Gazebo)
```

`free` is Linux-only. On macOS use `vm_stat`, and on Windows check **Settings → System → About → Installed RAM**. Remember that macOS and Windows also need the virtual machine to be given enough memory — see [the platform sections](#setting-up-on-your-machine).

### Why this matters: the error message does not help

If you skip step 2, or run the command from the wrong folder, **the error is identical and unhelpful** either way:

```
Error: lstat ros2_ws: no such file or directory
```

It means *"create `ros2_ws`, or `cd` somewhere that has it"* — it does **not** name which mistake you made. If you see that, check both. Docker Desktop on macOS and Windows is even less obvious: it quietly creates a root-owned empty `ros2_ws` for you, and then the `student` user inside the container cannot write to it, so `colcon build` fails later with `Permission denied`. [That symptom has its own section below](#permission-denied-on-the-workspace).

---

## Quick start (one command)

All three options below get you to the same place: a running container and a desktop in your browser. Pick whichever suits you.

### Option A — docker compose (easiest)

This repository ships a `compose.yaml`, so the whole lab is one command. **It creates the `ros2_ws` folder for you if it is missing**, which is the single most common thing to get wrong by hand.

```bash
docker compose up -d
```

Then open **<http://127.0.0.1:6080/vnc.html?autoconnect=true>** in your browser. That is it — no image name, no volume paths, no `mkdir`.

Stop it again with `docker compose down`. Your work stays in `./ros2_ws`.

| I want to… | Command |
| --- | --- |
| Start | `docker compose up -d` |
| See the logs | `docker compose logs -f` |
| Stop (keep work) | `docker compose stop` |
| Stop and remove | `docker compose down` |
| Update to the newest image | `docker compose pull && docker compose up -d` |

> `docker compose` needs **Docker Desktop**, or the `docker-compose` plugin on Linux. With **Podman**, `podman compose` also works *provided* a Compose provider is installed — on many distributions that is a separate package (`podman-compose` on Fedora/Debian/Ubuntu, `docker-compose` otherwise). Without one, Podman prints `compose provider failed ... executable file not found`; install the provider, or just use [Option B](#option-b--pull-the-prebuilt-image) and run `podman run` yourself.
>
> Nothing in this file builds the image — it pulls the prebuilt one from GitHub Container Registry, so it works natively on Intel/AMD and Apple Silicon, and needs no GitHub account.

### Option B — pull the prebuilt image

The same thing by hand, if you would rather not use Compose. A ready-to-run image is published on GitHub Container Registry for both **Intel/AMD (`linux/amd64`)** and **Apple Silicon (`linux/arm64`)** machines. This takes about a minute:

```bash
# 1. Pull the image (no account or login needed)
podman pull ghcr.io/tgodfrey0/aice2011_container:latest

# 2. Start the lab
podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest

# 3. Open the desktop
#    http://127.0.0.1:6080/vnc.html?autoconnect=true
```

Everything under `podman machine` / Docker Desktop applies unchanged — see [Setting up on your machine](#setting-up-on-your-machine) if you need to install Podman or start a virtual machine first.

Every push is also tagged with the commit it was built from, so you can pin an exact version:

```bash
podman pull ghcr.io/tgodfrey0/aice2011_container:sha-1234567   # replace with the commit you want
```

> The `:latest` tag is rebuilt automatically whenever the `Containerfile` changes on `main`, so it always reflects the current `main` branch.

### Option C — build it yourself

Choose this if you want to modify the `Containerfile`, pin package versions, or you would rather not download a 3.7 GB prebuilt image. The first build takes roughly **5–20 minutes**; later builds reuse the cache and finish in seconds.

```bash
# 1. Build the image (only needed once)
podman build -t ros2-gazebo-lab -f Containerfile .

# 2. Start the lab
podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ros2-gazebo-lab

# 3. Open the desktop
#    http://127.0.0.1:6080/vnc.html?autoconnect=true
```

The `127.0.0.1` in `-p 127.0.0.1:6080:6080` means "only accept connections from this computer". See [Why bind to 127.0.0.1?](#why-bind-to-127001) — please keep it, the VNC server has no password.

> **Prefer Docker?** Every `podman` command below works identically as `docker`. The only differences are called out in each platform section.

---

## Setting up on your machine

You only need **one** of the options below. Pick the one that matches your machine and your lab partner's instructions.

### Windows

<details open>
<summary><strong>Windows — Docker Desktop (recommended)</strong></summary>

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) for Windows.
   During setup, keep the **Use WSL 2 instead of Hyper-V** option enabled — it is the default.
2. Start Docker Desktop and wait until it reports *Engine running*.
3. Open **PowerShell**, `cd` into this repository, and pull the prebuilt image. This works on Intel/AMD Windows exactly as it does on Linux: Docker Desktop runs Linux containers under WSL 2, so it fetches the `linux/amd64` build.

```powershell
docker pull ghcr.io/tgodfrey0/aice2011_container:latest
docker run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws ghcr.io/tgodfrey0/aice2011_container:latest
```

   Building is still a perfectly good option if you want to change the `Containerfile` — just replace step 3 with:

```powershell
docker build -t ros2-gazebo-lab -f Containerfile .
docker run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws ros2-gazebo-lab
```

   That takes roughly **5–20 minutes** on Windows and trips over a line-ending gotcha — see [Windows notes](#windows-notes). Pulling the prebuilt image avoids it entirely.

4. Open **<http://127.0.0.1:6080/vnc.html?autoconnect=true>** in your browser.

**PowerShell tips**

- Use the **backtick** `` ` `` at the end of a line to continue a command onto the next line. A backslash `\` does *not* work.
- Every command in this README is written on a single line so that you can copy and paste it directly, whichever shell you use.

</details>

<details>
<summary><strong>Windows — running inside WSL 2 instead</strong></summary>

This option is useful if your lab partner's instructions assume a Linux command line.

1. Install the Windows Subsystem for Linux and an Ubuntu distribution from the Microsoft Store.
2. Inside Ubuntu, install Docker or Podman:

```bash
sudo apt update && sudo apt install -y podman
```

3. Keep your copy of this repository **inside the WSL filesystem** (for example `~/aice2011_container`) rather than under `C:\`. Files stored on the Windows drive are much slower inside WSL.

```bash
cd ~/aice2011_container
podman pull ghcr.io/tgodfrey0/aice2011_container:latest
podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

   Inside WSL this is an ordinary Linux userspace, so the same pull works as
   described in [Option B](#option-b--pull-the-prebuilt-image). Substitute
   `podman build -t ros2-gazebo-lab -f Containerfile .` for the `podman pull`
   line if you would rather build it yourself.

4. Then open the same URL from your Windows browser.

</details>

<details>
<summary><strong>Windows notes</strong></summary>

- The `:Z` label is omitted in the Windows commands above. It is only needed on SELinux-enabled Linux hosts, and it confuses the Windows path parser.
- Docker Desktop must be left in **Linux containers** mode, which is its default. If it is switched to Windows containers, the pull fails — this image is Linux-only and there is no `windows/amd64` build. Check the mode by clicking the whale icon in the system tray.
- **Only affects `docker build`.** Git for Windows checks text files out with CRLF line endings, which rewrites `entrypoint.sh` and makes the container die on startup with `exec /entrypoint.sh: exec format error`. Pulling the prebuilt image avoids this completely, because the script is baked into the image with Unix line endings. If you do want to build, either set `git config --global core.autocrlf input` before cloning, or run `git rm --cached -r . && git reset --hard` afterwards to re-checkout with the correct endings.
- If the build fails with an error about the WSL 2 engine, make sure Docker Desktop is fully started and that *Settings → Resources → WSL Integration* has your distribution enabled.
- The same `colcon build` slowdown described for macOS applies: keep your workspace small.

</details>

### Linux

<details open>
<summary><strong>Ubuntu / Debian / Fedora — Podman (recommended)</strong></summary>

Install Podman:

```bash
# Fedora
sudo dnf install podman

# Ubuntu / Debian
sudo apt update && sudo apt install -y podman
```

Podman runs **rootless** by default, so there is no `sudo` needed for any of the commands below.

Pull the prebuilt image and start:

```bash
podman pull ghcr.io/tgodfrey0/aice2011_container:latest
podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

Then open **<http://127.0.0.1:6080/vnc.html?autoconnect=true>**.

The `:Z` at the end of the mount is important on SELinux-enabled distributions (Fedora, RHEL, Rocky, CentOS). It tells the container to relabel the folder so the `student` user inside the container is allowed to write to it. On distributions without SELinux it is harmless and you can leave it as it is.

To build it from this repository instead, swap the `podman pull` line for `podman build -t ros2-gazebo-lab -f Containerfile .` and run `ros2-gazebo-lab` in place of the full image name. See [Option C](#option-c--build-it-yourself).

</details>

<details>
<summary><strong>Linux — Docker</strong></summary>

```bash
sudo apt install docker.io          # Ubuntu / Debian
sudo dnf install docker             # Fedora
sudo usermod -aG docker $USER       # log out and back in afterwards
```

```bash
docker pull ghcr.io/tgodfrey0/aice2011_container:latest
docker run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

Substitute `docker build -t ros2-gazebo-lab -f Containerfile .` for the `docker pull` line if you would rather build it yourself.

</details>

<details>
<summary><strong>Checking your setup / fixing Podman</strong></summary>

```bash
# What is running?
podman ps

# Did the desktop start correctly?
podman logs ros_lab_test
```

You should see `xvfb`, `x11vnc`, `openbox` and `novnc` all reporting `entered RUNNING state`.

If Podman complains about user namespaces or `subuid`/`subgid`:

```bash
podman system migrate
```

And if you get `cannot clone: Operation not permitted` after installing Podman on a fresh machine, log out and back in (or reboot) so your new group memberships take effect.

</details>

### macOS

macOS cannot run Linux containers directly, so both Podman and Docker run a small Linux virtual machine for you. You only need to create and start that machine once.

<details open>
<summary><strong>macOS — Podman Desktop (recommended)</strong></summary>

1. Install [Podman Desktop](https://podman-desktop.io/) (it bundles Podman itself).
2. Open it, and use the built-in terminal (**Terminal → Podman machine init**) or your own terminal:

```bash
podman machine init --cpus 6 --memory 8192 --disk-size 40
podman machine start
```

3. Pull the prebuilt image and start:

```bash
podman pull ghcr.io/tgodfrey0/aice2011_container:latest
podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

   Apple Silicon pulls the `linux/arm64` build and Intel Macs pull `linux/amd64`; both are published, so no special flag is needed. Swap in `podman build -t ros2-gazebo-lab -f Containerfile .` if you want to build it yourself — see [Option C](#option-c--build-it-yourself).

4. When you are finished for the day, give the virtual machine its memory back:

```bash
podman machine stop
```

</details>

<details>
<summary><strong>macOS — Docker Desktop</strong></summary>

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) for Mac (Apple Silicon or Intel).
2. Start Docker Desktop and wait for the whale icon to say it is running.
3. Then:

```bash
docker pull ghcr.io/tgodfrey0/aice2011_container:latest
docker run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws ghcr.io/tgodfrey0/aice2011_container:latest
```

Note the missing `:Z` — that label is only meaningful on SELinux-enabled Linux hosts.

Substitute `docker build -t ros2-gazebo-lab -f Containerfile .` for the `docker pull` line if you would rather build it yourself.

</details>

<details>
<summary><strong>macOS — Colima (lighter alternative to Docker Desktop)</strong></summary>

Useful if you would rather not run Docker Desktop (it is a commercial product with a licence). Colima runs the same Linux virtual machine with a much smaller footprint.

```bash
brew install docker colima
colima start --cpu 6 --memory 8 --disk 40
```

`colima start` prints a summary when it is ready. Then use the **Docker** commands (Colima provides the Docker-compatible engine and the `docker` CLI comes from Homebrew):

```bash
docker pull ghcr.io/tgodfrey0/aice2011_container:latest
docker run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws ghcr.io/tgodfrey0/aice2011_container:latest
```

```bash
colima stop      # when you are done
```

</details>

<details>
<summary><strong>Apple Silicon (M1/M2/M3/M4) notes</strong></summary>

Pulling is the best route on Apple Silicon: `podman pull` / `docker pull` fetches the prebuilt native `linux/arm64` image, so you neither build nor translate anything.

If you are building anyway, the image builds natively for `arm64`, so no extra flags are normally needed.

If a package ever fails to resolve on `arm64`, build for Intel instead and let the virtual machine translate it:

```bash
podman build --platform linux/amd64 -t ros2-gazebo-lab -f Containerfile .
```

This always works, but Gazebo will run noticeably slower because every instruction is being translated. Try the native build first, or simply `podman pull` the `linux/amd64` image instead of building it.

</details>

<details>
<summary><strong>macOS — why <code>colcon build</code> is slow here</strong></summary>

On macOS the `./ros2_ws` folder is not a real Linux folder: it lives on macOS and is shared into the virtual machine over a network filesystem. Reading and writing each file is far more expensive than on Linux, so a `colcon build` that takes 20 seconds natively can take several minutes.

What to do about it:

- Keep the number of files in your workspace small — avoid committing build artefacts or large datasets into `ros2_ws`.
- Use `colcon build --symlink-install`, which avoids copying Python files around.
- If a single build is painfully slow, build inside the container on a temporary folder and copy the result back:

```bash
# from your host terminal, while the container is running
podman exec -u student -w /tmp ros_lab_test bash -c 'source /opt/ros/jazzy/setup.bash && cp -r /home/student/ros2_ws/src /tmp/ws_src && cd /tmp/ws_src && colcon build'
podman cp ros_lab_test:/tmp/ws_src/build ros2_ws/build
podman cp ros_lab_test:/tmp/ws_src/install ros2_ws/install
```

</details>


---

## Using the lab

### 1. Open the desktop

With the container running, open:

**<http://127.0.0.1:6080/vnc.html?autoconnect=true>**

- The desktop connects automatically thanks to `autoconnect=true`. Without that parameter you get a connect panel and have to click **Connect** yourself.
- The screen is scaled to fit your browser window. Use the full-screen button (usually `F11`) for the most space.
- **There is no login prompt.** The desktop starts as the `student` user and a terminal window opens automatically.

> If you typed `localhost` instead of `127.0.0.1` and the page will not load, use `127.0.0.1`. On some systems `localhost` resolves to the IPv6 address `::1`, which the container's port forwarding does not handle. See [Troubleshooting](#troubleshooting).

### 2. Start the TurtleBot3 simulation

In the terminal inside the desktop:

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

ROS 2 is already set up in that terminal — no `source` command needed. If you ever open a terminal that does *not* have it (for example a `podman exec` shell), run `source /opt/ros/jazzy/setup.bash` first.

The Gazebo window opens with the TurtleBot3 Waffle Pi in a small arena. It takes 20–60 seconds for the robot to appear the first time — be patient.

The launch file starts Gazebo and a bridge between Gazebo and ROS 2, so these topics become available:

| Topic | Type |
| --- | --- |
| `/cmd_vel` | `geometry_msgs/msg/TwistStamped` — commands to the robot |
| `/odom` | `nav_msgs/msg/Odometry` |
| `/imu` | `sensor_msgs/msg/Imu` |
| `/scan` | `sensor_msgs/msg/LaserScan` |
| `/camera/image_raw` | `sensor_msgs/msg/Image` |
| `/camera/camera_info` | `sensor_msgs/msg/CameraInfo` |
| `/clock` | `rosgraph_msgs/msg/Clock` |

> **Note:** in Jazzy the bridge uses `TwistStamped` for `/cmd_vel`, not the older plain `Twist`. The type changed from Humble, so older lab notes and tutorials will not match.

Sanity check from a **second** terminal in the desktop:

```bash
ros2 topic list
ros2 topic echo /odom --once
```

To stop the simulation press `Ctrl+C` in the terminal running the launch file.

### 3. Drive the robot

In a **second** terminal:

```bash
ros2 run turtlebot3_teleop teleop_keyboard
```

Then click on the terminal window so it has keyboard focus, and drive with:

| Key | Action |
| --- | --- |
| `w` | increase forward speed |
| `x` | decrease forward speed |
| `a` / `d` | turn left / right |
| `s` or `space` | stop immediately |
| `Ctrl+C` | quit teleop |

> **Note:** the executable in Jazzy is `teleop_keyboard`. Older ROS 2 tutorials use `keyboard_teleop` — that name does not exist here.

You can also publish velocity commands directly, which is what you will do in most lab exercises. Note the `TwistStamped` type and the extra `twist:` level:

```bash
ros2 topic pub --rate 10 /cmd_vel geometry_msgs/msg/TwistStamped "{twist: {linear: {x: 0.2}, angular: {z: 0.5}}}"
```

Check that the robot actually moved:

```bash
ros2 topic echo /odom --once
```

### 4. Build your own ROS 2 workspace

Your workspace is the `ros2_ws` folder in this repository, mounted at `/home/student/ros2_ws` inside the container. The `src` folder is created automatically when the container starts.

Create a new package:

```bash
cd ~/ros2_ws
ros2 pkg create --build-type ament_cmake my_first_lab
```

Build and source it:

```bash
cd ~/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

After this, `ros2 run my_first_lab <executable>` works, and your package is visible to `ros2 pkg list`.

> `source install/setup.bash` is only needed in terminals that were open *before* you built. Any terminal you open afterwards picks your workspace up automatically.

### 5. Other worlds

`ros2 launch turtlebot3_gazebo <file>` gives you:

| Launch file | What you get |
| --- | --- |
| `turtlebot3_world.launch.py` | small rectangular arena (default) |
| `turtlebot3_house.launch.py` | robot inside a furnished house |
| `turtlebot3_dqn_stage1.launch.py` … `stage4` | the DQN reinforcement-learning environments |
| `empty_world.launch.py` | bare Gazebo world, useful for your own models |
| `spawn_turtlebot3.launch.py` | spawns the robot into an already-running world |

To switch robot model, change the environment variable **before** launching (it must match for the simulation *and* your nodes):

```bash
export TURTLEBOT3_MODEL=burger      # or: waffle, waffle_pi (default)
```

---

## Command cheat sheet

Run these on your **host** machine (not in the container):

```bash
podman ps                             # is it running?
podman logs -f ros_lab_test           # watch startup / errors
podman stop ros_lab_test              # stop (your files are kept)
podman start ros_lab_test             # start again
podman restart ros_lab_test           # stop + start
podman rm -f ros_lab_test             # delete the container entirely

podman exec -it ros_lab_test bash     # a shell inside the container
podman cp ros_lab_test:/home/student/ros2_ws/install ./ws-install-backup    # copy files out
podman image inspect ghcr.io/tgodfrey0/aice2011_container:latest --format '{{.Size}}'   # image size
podman system df                      # disk space used by images/containers
```

Inside the container (in the desktop terminal, or via `podman exec`):

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py   # start the sim
ros2 run turtlebot3_teleop teleop_keyboard                 # drive it
ros2 topic list / ros2 node list                           # inspect ROS 2
gz sim --versions                                          # Gazebo version
colcon build --symlink-install                              # build the workspace
```

---

## Everyday container management

| I want to… | Command |
| --- | --- |
| Start the lab for the day | `podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest` |
| Stop it when I go home | `podman stop ros_lab_test` |
| Back the next morning | `podman start ros_lab_test` |
| Wipe it and start clean | `podman rm -f ros_lab_test` (your `ros2_ws` is **not** deleted) |
| Free disk space | `podman container prune` then `podman image prune` |

> If you built the image yourself in [Option C](#option-c--build-it-yourself), replace `ghcr.io/tgodfrey0/aice2011_container:latest` with `ros2-gazebo-lab` in these commands.
>
> Rebuilding or re-pulling the image is safe: your work is in `./ros2_ws`, which is mounted from your machine, not stored in the image.

---

## Where your work is saved

The `-v ./ros2_ws:/home/student/ros2_ws:Z` part of the run command **bind-mounts** the `ros2_ws` folder from this repository into the container.

That means:

- Everything you create under `/home/student/ros2_ws` appears in `./ros2_ws` on your machine immediately, and survives `podman rm`.
- Anything you save *outside* `ros2_ws` (for example in `/home/student/Downloads`) is **destroyed** when you delete the container. Do not keep work there.
- The container's home directory is fixed to `student` with passwordless `sudo`, so `sudo` is available if you need to install something (try to avoid it — if everyone installs different things, builds will differ).

---

## Troubleshooting

### `Error: lstat ros2_ws: no such file or directory`

The container refuses to start. This one message covers two different mistakes, so check both:

1. **You are in the wrong folder.** The `ros2_ws` path is relative, so it only works from the folder you unzipped. `pwd` should show the directory containing `Containerfile`, not your home folder.
2. **The `ros2_ws` folder does not exist.** It ships empty, so Windows Explorer hides it and some unzip tools skip it. See [step 2 of the checklist](#before-you-start-a-60-second-checklist), or just run:

```bash
pwd                  # am I in the right place?
ls                   # does it list ros2_ws?
mkdir -p ros2_ws/src # if it is missing, create it
```

Then run the start command again.

### The desktop will not load

**1. Is the container running?**

```bash
podman ps
```

If `ros_lab_test` is missing, start it again with the run command above.

**2. Do the services start cleanly?**

```bash
podman logs ros_lab_test
```

A healthy start looks like this — four `entered RUNNING state` lines:

```
success: xvfb entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
success: x11vnc entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
success: openbox entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
success: novnc entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
```

**3. Is something else using port 6080?**

```bash
ss -ltn | grep 6080        # Linux
```

If another container or program holds the port, stop it, or start the lab on a different port and change the left-hand side in the run command:

```bash
podman run -d --name ros_lab_test -p 127.0.0.1:6081:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

**4. Use `127.0.0.1` instead of `localhost`.**

On some systems `localhost` resolves to `::1`, and the container's port forwarding only listens on IPv4. The page then fails to load even though the lab is running fine.

### The container name is already in use

```
Error: creating container storage: the container name "ros_lab_test" is already in use
```

A previous container is still registered. Either delete it, or replace it automatically:

```bash
podman rm -f ros_lab_test
```

```bash
podman run --rm --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

Adding `--rm` means the container deletes itself when you stop it, so this cannot happen again.

### Permission denied on the workspace

Symptoms: `mkdir: cannot create directory ... Permission denied` inside `/home/student/ros2_ws`.

This is almost always SELinux. Make sure your run command ends the mount with `:Z` and then start a **new** container (editing the command is not enough — the label is applied when the container is created):

```bash
podman run -d --name ros_lab_test -p 127.0.0.1:6080:6080 -v ./ros2_ws:/home/student/ros2_ws:Z ghcr.io/tgodfrey0/aice2011_container:latest
```

If you are on Windows or macOS with Docker Desktop, drop the `:Z` — it is not used there.

### Gazebo is very slow, or crashes with a graphics error

The container has **no access to your GPU**: it uses Mesa's software renderer, which is correct but slow. Gazebo normally still runs, just more slowly than on a native installation.

If the Gazebo window fails to appear or you see errors mentioning `libGL`, `GLX` or `Qt platform plugin xcb`, try the software renderer explicitly:

```bash
export LIBGL_ALWAYS_SOFTWARE=1
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

Other things that help:

- Close the Gazebo GUI window entirely and use a headless world (`empty_world.launch.py`) when you only need ROS 2 topics — this makes a large difference.
- Add Gazebo's **World Stats** plugin in the GUI. It shows the *real time factor* (RTF): `1.0` means the simulation runs at full speed, and anything below that means Gazebo is falling behind.
- Give the virtual machine more resources (macOS/Windows: see the platform sections above).

### <code>colcon build</code> takes minutes instead of seconds

Expected on macOS and Windows — the workspace folder is shared across a virtual machine boundary. See [macOS — why colcon build is slow](#macos--why-colcon-build-is-slow-here) for what to do about it.

### The disk is full

```bash
podman system df          # what is using space
podman container prune    # delete stopped containers
podman image prune        # delete dangling (unused) images
```

Deleting the image itself and fetching it again takes about a minute (or 5–20 minutes if you rebuild from source instead) and recovers ~3.7 GB:

```bash
podman rmi ghcr.io/tgodfrey0/aice2011_container:latest
```

### Nothing sees anything

If ROS 2 nodes cannot see each other:

```bash
echo $ROS_DOMAIN_ID         # should match in every terminal (unset means 0)
echo $RMW_IMPLEMENTATION
```

Every terminal inside the desktop already sources the same environment, so mismatches normally only appear when mixing in a terminal outside the container. If you need two containers on one machine to talk, give them the same `ROS_DOMAIN_ID`.

### Messages that are safe to ignore

Gazebo prints several warnings on every launch. They are **not** problems, and you can leave the terminal running without watching them:

```
[Wrn] [LocalCache.cc:104] Server directory does not exist [/home/student/.gz/fuel/...]
[Wrn] [Utils.cc:132] XML Element[gz_frame_id] ... not defined in SDF
[Wrn] [Ogre2RenderTarget.cc:668] Anti-aliasing level ... is not supported
[Wrn] [Ogre2Camera.cc:423] Ogre2Camera::SetVisibilityMask ... will be ignored
[Wrn] [QT] WorldStats.qml:53:3: QML RowLayout: Binding loop detected for property "x"
```

### Why bind to 127.0.0.1?

`-p 127.0.0.1:6080:6080` publishes the port on the loopback interface only, so the desktop is reachable **only from your own machine**. Writing `-p 6080:6080` instead publishes it on every network interface, which on a university network means anyone nearby who guesses the port can control your machine's desktop — the VNC server in this image has **no password**.

If you must reach the lab from another device on a trusted network, use an SSH tunnel instead:

```bash
ssh -L 6080:127.0.0.1:6080 your-login@your-machine
```

---

## Known limitations

- **No GPU acceleration.** Gazebo renders in software. It works, but it is slower than a native install.
- **No audio.** There is no sound device in the container.
- **No camera passthrough.** Physical cameras are not forwarded; only simulated sensors (LIDAR, IMU, RGB camera) are available.
- **Port 6080 is unauthenticated.** Keep it bound to `127.0.0.1`.
- **One desktop at a time per container.** Start a second container with a different name and a different port if you need two labs running (change the left-hand port number).
- **ARM (Apple Silicon) is slower than x86** if you have to fall back to `--platform linux/amd64`.

---

## Getting help

If something in this guide does not match what you see, include these details when you ask for help — they make any problem much faster to diagnose:

```bash
podman version                     # or: docker version
uname -a                           # Linux only
podman ps -a
podman logs --tail 50 ros_lab_test
```

<p align="center"><sub>Maintained for the AICE2011 module. Container contents: ROS 2 Jazzy, Gazebo Sim Harmonic, TurtleBot3, XFCE4, noVNC.</sub></p>