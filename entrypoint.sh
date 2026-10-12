#!/bin/bash
set -e

# Clear stale lock files
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
