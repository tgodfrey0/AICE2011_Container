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

ENTRYPOINT ["/entrypoint.sh"]
