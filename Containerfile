FROM docker.io/library/ros:jazzy-ros-base-noble

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV RESOLUTION=1920x1080x24

# Install lightweight XFCE4 desktop, noVNC stack, supervisor, and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    openbox \
    xfce4-terminal \
    dbus-x11 \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    supervisor \
    sudo \
    curl \
    git \
    nano \
    gedit \
    x11-xserver-utils \
    python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*

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

# Configure ROS environment auto-sourcing for the student user
RUN echo "source /opt/ros/jazzy/setup.bash" >> /home/student/.bashrc \
    && echo "if [ -f /home/student/ros2_ws/install/setup.bash ]; then source /home/student/ros2_ws/install/setup.bash; fi" >> /home/student/.bashrc
RUN echo "export TURTLEBOT3_MODEL=waffle_pi" >> /home/student/.bashrc
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Make the noVNC canvas scale itself to fit the browser window.
# noVNC 1.3 reads the "resize" setting from localStorage, so seed that key
# before app/ui.js loads. Must run as root: /usr/share/novnc is root-owned.
RUN sed -i 's#<script src="app/error-handler.js"></script>#<script>localStorage.setItem("resize","scale");</script>\n    <script src="app/error-handler.js"></script>#' /usr/share/novnc/vnc.html

# Expose noVNC port
EXPOSE 6080

USER student
WORKDIR /home/student

# Configure Openbox autostart and background colour
RUN mkdir -p /home/student/.config/openbox \
    && echo 'xsetroot -solid "#2c3e50" &' > /home/student/.config/openbox/autostart \
    && echo 'xfce4-terminal &' >> /home/student/.config/openbox/autostart \
    && echo 'xset r on &' >> /home/student/.config/openbox/autostart \
    && echo 'xset r rate 250 30 &' >> /home/student/.config/openbox/autostart \
    && chown -R student:student /home/student/.config

# Launcher scripts and Applications-menu entries only. Nothing is installed
# into ~/Desktop, so the desktop background stays clean; every launcher is
# reached through the panel's Applications menu instead. Wrapping each ROS
# command in a script keeps the .desktop Exec lines simple: Exec= has its own
# quoting rules that make inline "source ...; ros2 ..." strings fragile.
RUN mkdir -p /home/student/bin /home/student/.local/share/applications

# New terminal -- the important one: lets a student get a shell back after
# closing every terminal window.
RUN printf '%s\n' \
      '#!/bin/bash' \
      'exec xfce4-terminal' \
      > /home/student/bin/new-terminal

# Start the TurtleBot3 simulation.
RUN printf '%s\n' \
      '#!/bin/bash' \
      'source /opt/ros/jazzy/setup.bash' \
      '[ -f /home/student/ros2_ws/install/setup.bash ] && source /home/student/ros2_ws/install/setup.bash' \
      'exec ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py' \
      > /home/student/bin/start-simulation

# Drive the robot. Teleop needs the keyboard, so it has to be a real terminal.
RUN printf '%s\n' \
      '#!/bin/bash' \
      'source /opt/ros/jazzy/setup.bash' \
      '[ -f /home/student/ros2_ws/install/setup.bash ] && source /home/student/ros2_ws/install/setup.bash' \
      'exec ros2 run turtlebot3_teleop teleop_keyboard' \
      > /home/student/bin/start-teleop

# Build the workspace, so nobody has to remember the path or the flags.
RUN printf '%s\n' \
      '#!/bin/bash' \
      'source /opt/ros/jazzy/setup.bash' \
      '[ -f /home/student/ros2_ws/install/setup.bash ] && source /home/student/ros2_ws/install/setup.bash' \
      'cd /home/student/ros2_ws || exit 1' \
      'colcon build --symlink-install' \
      'echo' \
      'echo "Build finished. Press Enter to close this window."' \
      'read -r' \
      > /home/student/bin/build-workspace

# One .desktop definition per launcher, installed to the Applications menu
# only. Written with plain printf rather than a loop so it stays POSIX sh
# compatible.
RUN printf '[Desktop Entry]\nType=Application\nVersion=1.0\nName=New Terminal\nComment=Open a new terminal window\nExec=/home/student/bin/new-terminal\nIcon=utilities-terminal\nTerminal=false\nCategories=System;TerminalEmulator;\nStartupNotify=true\n' > /home/student/.local/share/applications/new-terminal.desktop \
 && printf '[Desktop Entry]\nType=Application\nVersion=1.0\nName=Start TurtleBot3 Simulation\nComment=Launch the TurtleBot3 world in Gazebo\nExec=/home/student/bin/start-simulation\nIcon=applications-games\nTerminal=false\nCategories=Utility;\nStartupNotify=true\n' > /home/student/.local/share/applications/start-simulation.desktop \
 && printf '[Desktop Entry]\nType=Application\nVersion=1.0\nName=TurtleBot3 Teleop\nComment=Drive the robot with the keyboard\nExec=/home/student/bin/start-teleop\nIcon=input-keyboard\nTerminal=false\nCategories=Utility;\nStartupNotify=true\n' > /home/student/.local/share/applications/start-teleop.desktop \
 && printf '[Desktop Entry]\nType=Application\nVersion=1.0\nName=Build ROS 2 Workspace\nComment=Run colcon build in ros2_ws\nExec=/home/student/bin/build-workspace\nIcon=system-run\nTerminal=false\nCategories=Utility;\nStartupNotify=true\n' > /home/student/.local/share/applications/build-workspace.desktop \
 && chmod +x /home/student/bin/* \
 && update-desktop-database /home/student/.local/share/applications

ENTRYPOINT ["/entrypoint.sh"]
