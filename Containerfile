FROM docker.io/library/ros:jazzy-ros-base-noble

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1920x1080x24

# Force Mesa's software renderer, always.
#
# Gazebo's TurtleBot3 LIDAR is a <sensor type="gpu_lidar">, which needs a real
# OpenGL render target. Gazebo Sim 8 has no CPU-based lidar system, so this is
# the only route to a working /scan in a container with no GPU. Mesa renders on
# the CPU via llvmpipe instead, which the gz-sensors project documents as the
# supported workaround. MESA_GL_VERSION_OVERRIDE pins the reported GL version so
# Ogre2 accepts llvmpipe's 3.3.
#
# This is also simply the honest setting for a container: there is no GPU to
# pass through, so let everything agree that it is software rendering rather
# than having each library discover it separately and sometimes disagree.
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV MESA_GL_VERSION_OVERRIDE=3.3

# Install lightweight XFCE4 desktop, noVNC stack, supervisor, and utilities
#
# TigerVNC rather than Xvfb + x11vnc. Xvnc is both the X server and the VNC
# server in one process, and it supports the Extended Clipboard pseudo-encoding
# (added in TigerVNC 1.10). That matters because Ubuntu 24.04 ships
# libvncserver 0.9.14, which cannot parse the UTF-8 cut-text messages that
# encoding requires -- so with x11vnc, clipboard text simply never makes it
# across the wire. See x11vnc issue #260 and libvncserver PR #639.
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    openbox \
    xfce4-terminal \
    dbus-x11 \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    supervisor \
    sudo \
    curl \
    ca-certificates \
    git \
    nano \
    gedit \
    x11-xserver-utils \
    python3-colcon-common-extensions \
    mesa-utils \
    libgl1-mesa-dri \
    xfce4-clipman \
    xclip \
    && rm -rf /var/lib/apt/lists/*

# Replace Ubuntu's noVNC 1.3.0 with 1.7.0 from upstream.
#
# 1.3.0 is from 2022 and is the version the image has been carrying. The
# upgrade brings years of fixes to the framebuffer, input handling and touch
# support, and is the base for the clipboard sync added below.
#
# The tarball is used rather than a git clone because it carries no history,
# and because vendor/pako is committed to the repository, so there is nothing
# to build -- no npm, no node.
RUN rm -rf /usr/share/novnc \
    && mkdir -p /usr/share/novnc \
    && curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.7.0.tar.gz \
        | tar -xz --strip-components=1 -C /usr/share/novnc \
    && rm -rf /usr/share/novnc/.git \
    && chmod +x /usr/share/novnc/utils/novnc_proxy \
    && test -f /usr/share/novnc/vnc.html \
    && test -f /usr/share/novnc/utils/novnc_proxy \
    && test -f /usr/share/novnc/vendor/pako/lib/zlib/inflate.js

# Install modern Gazebo Sim (Harmonic) and ROS 2 Jazzy integration packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-jazzy-ros-gz \
    ros-jazzy-gz-ros2-control \
    && rm -rf /var/lib/apt/lists/*

# Install TurtleBot3 ROS 2 Jazzy simulation and description packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-jazzy-turtlebot3-simulations \
    ros-jazzy-turtlebot3-gazebo \
    ros-jazzy-turtlebot3-description \
    ros-jazzy-turtlebot3-teleop \
    ros-jazzy-turtlebot3-bringup \
    && rm -rf /var/lib/apt/lists/*

# Set the default robot model (burger, waffle, or waffle_pi)
ENV TURTLEBOT3_MODEL=waffle_pi

# Create a non-root user for students (named 'student')
RUN useradd -m -s /bin/bash student \
    && echo "student ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/student/ros2_ws/src \
    && chown -R student:student /home/student

# Shell environment: ROS 2 sourcing, the TurtleBot3 model, the Gazebo
# resource path, and the lab's aliases and helper functions all live in
# setup/tb3_env.sh, copied in below and sourced from .bashrc. One file that
# can be read and version-controlled, rather than a chain of `echo >>
# .bashrc` lines.
RUN echo 'if [ -f "$HOME/setup/tb3_env.sh" ]; then source "$HOME/setup/tb3_env.sh"; fi' >> /home/student/.bashrc

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Patch the noVNC page. Two edits, both of which have to be plain blocking
# scripts placed ahead of noVNC's own module scripts:
#
#   1. Seed the "resize" setting so the canvas scales to fit the browser
#      window, rather than sitting at 1920x1080 in a smaller one.
#   2. Load the clipboard sync script.
#
# lab_clipboard.js must be a module itself, because that is how it reaches
# noVNC's UI object -- see the comment at the top of that file.
#
# Must run as root: /usr/share/novnc is root-owned.
COPY lab/novnc/lab_clipboard.js /usr/share/novnc/lab_clipboard.js
RUN sed -i 's#<script type="module" crossorigin="anonymous" src="app/error-handler.js"></script>#<script>localStorage.setItem("resize","scale");</script>\n    <script type="module" src="lab_clipboard.js"></script>\n    <script type="module" crossorigin="anonymous" src="app/error-handler.js"></script>#' /usr/share/novnc/vnc.html \
    && grep -q 'type="module" src="lab_clipboard.js"' /usr/share/novnc/vnc.html \
    && grep -q 'localStorage.setItem("resize","scale")' /usr/share/novnc/vnc.html \
    && chmod 644 /usr/share/novnc/lab_clipboard.js

# The lab's own worlds, launcher scripts and command reference.
COPY lab/ /home/student/lab/
COPY lab/bin/ /home/student/bin/

# Shell environment (sourced from .bashrc, see above). setup/ is image-only
# configuration -- unlike ros2_ws, it is not student-editable state, so it is
# baked in rather than bind-mounted.
COPY setup/ /home/student/setup/

# Applications-menu entries. Nothing goes into ~/Desktop, so the desktop
# background stays clean; every launcher is reached through the panel's
# Applications menu instead.
#
# Each Exec line is a wrapper script rather than an inline command, because
# Exec= has its own quoting rules that make "source ...; ros2 ..." fragile,
# and getting that wrong produces a menu entry that silently does nothing.
COPY lab/applications/ /home/student/.local/share/applications/

# Everything the student writes to has to belong to the student, because the
# container starts as that user and the bind-mounted ros2_ws arrives with the
# host's ownership.
RUN chmod +x /home/student/bin/* \
    && chown -R student:student /home/student/lab /home/student/bin /home/student/setup /home/student/.local/share \
    && update-desktop-database /home/student/.local/share/applications

# Expose noVNC port
EXPOSE 6080

USER student
WORKDIR /home/student

# Configure Openbox autostart and background colour.
#
# xfce4-clipman is the clipboard manager, and is what makes Ctrl+V work inside
# XFCE applications once text has arrived over the VNC connection. Without a
# clipboard manager the selection dies the moment the app that set it exits,
# and paste silently does nothing. xclip gives the same thing by hand, from
# the terminal, when a clipboard manager is not enough.
RUN mkdir -p /home/student/.config/openbox \
    && echo 'xsetroot -solid "#2c3e50" &' > /home/student/.config/openbox/autostart \
    && echo 'xfce4-terminal &' >> /home/student/.config/openbox/autostart \
    && echo 'xfce4-clipman &' >> /home/student/.config/openbox/autostart \
    && echo 'xset r on &' >> /home/student/.config/openbox/autostart \
    && echo 'xset r rate 250 30 &' >> /home/student/.config/openbox/autostart

ENTRYPOINT ["/entrypoint.sh"]
