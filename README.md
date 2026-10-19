# AICE2011 — ROS 2 + Gazebo Lab

The whole lab — ROS 2 Jazzy, Gazebo Sim, TurtleBot3 and a Linux desktop — runs in
one container. You start it with one command and use it through your browser.

**Once you're in the browser, this guide has done its job.** The lab document
covers everything past this point.

> [!IMPORTANT]
> On Windows Docker Desktop should be used to start the Docker engine. Then in the bottom right hand corner press the terminal button and follow the rest of the instructions.

> [!TIP]
> If you are on your personal device, Podman may be easier and faster to install than Docker ([Podman can be downloaded here](https://podman.io/docs/installation)). All the following commands will be the same, just use `podman` instead of `docker`.

---

## Setup the container environment

Open **`.env`** in this folder with a text editor (e.g. Visual Studio Code). It is the only file you need to edit.

Fill in your username in the `ROS2_WS` path, or replace with a preferred location.

> [!IMPORTANT]
> If you are on Windows, the location must be on the `C:/` drive.

> [!TIP]
> The placeholder path points to the Windows OneDrive desktop so that you can access your files from anywhere. If you point the mount to somewhere else, remember to back it up somewhere you can access later. 

Docker creates the folder for you if it doesn't exist yet, so you do not need
to make it first.

If something else on your machine already uses port 6080, change `VNC_PORT` in
the same file, and use that port in the address in the next section.

## Start the lab

Open a terminal (or the terminal within Docker Desktop) and run:

```bash
docker compose up -d
```

First run takes a minute or two while it downloads the image. Then open this
address in your browser:

**<http://127.0.0.1:6080/vnc.html?autoconnect=true>**

> [!IMPORTANT]
> If you changed the `VNC_PORT` use that instead of `6080`


## Everyday commands

All of these run in the terminal on your own computer (**not** inside the container), with this folder as the
working directory.

| I want to… | Command |
| --- | --- |
| Start the lab | `docker compose up -d` |
| Stop the container | `docker compose down` |
| See what it's doing | `docker compose logs -f` |
| Restart it | `docker compose restart` |
| Update to the newest image | `docker compose pull && docker compose up -d` |
| Check it's running | `docker compose ps` |

> [!WARNING]
> In the container you will find the directory `/home/student/ros2_ws`, if you do not store your files in that dir, they may be lost when the container is torn down.

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

**The page will not load**
Is the container up? `docker compose ps`. Then `docker compose logs` — a healthy
start prints six `entered RUNNING state` lines. If something else already owns
the port, change `VNC_PORT` in `.env` and use that port in the address.

**Nothing will happen when you click a menu item**
The world takes 20–60 seconds to appear. The terminal that opened shows its
progress and any error — that log is the point of the menu items opening a
terminal.

<p align="center"><sub>Maintained for the AICE2011 module at the University of Southampton.</sub></p>
