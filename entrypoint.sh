#!/bin/bash
set -e

# X clients reach the display through a unix socket in /tmp/.X11-unix. That
# directory normally exists on a desktop but not in a bare container, and the
# X server runs as the unprivileged student user here, which cannot create it.
sudo install -d -m 1777 /tmp/.X11-unix

# Clear stale lock files left behind by an unclean shutdown
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# The ./ros2_ws bind mount hides the src/ directory baked into the image,
# so recreate the expected workspace layout
sudo mkdir -p /home/student/ros2_ws/src

# Fix ownership on student home directory (must come after the mkdir above)
sudo chown -R student:student /home/student

# Qt apps (Gazebo, xfce4-terminal) warn on every start if XDG_RUNTIME_DIR is unset
export XDG_RUNTIME_DIR=/tmp/runtime-student
sudo install -d -o student -g student -m 700 "$XDG_RUNTIME_DIR"

# Launch supervisor (pass XDG_RUNTIME_DIR through, sudo resets the environment)
exec sudo XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
