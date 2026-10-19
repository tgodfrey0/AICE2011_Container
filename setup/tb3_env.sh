# shellcheck shell=bash
###############################################################################
# AICE2011 shell environment -- sourced from ~/.bashrc inside the container.
#
# Everything a terminal needs beyond the bare ROS 2 install lives here:
#
#   1. Environment: ROS 2 sourcing, TurtleBot3 model, Gazebo resource path.
#   2. Aliases:    the common world / teleop / spawn commands.
#   3. Functions:  Gazebo cleanup and colcon build helpers.
#   4. Completion: package names for the build helpers, world names for
#                  run-world.
#
# It is copied into the image (see the Containerfile) rather than bind-mounted,
# so it is part of the image and students do not need to manage it.
#
# This is Gazebo Sim (gz sim, Harmonic) -- NOT Gazebo Classic. There is no
# gzserver/gzclient; the processes are the `gz sim` CLI and the gz-sim server
# and GUI binaries it starts.
###############################################################################

# Aliases and the like are pointless in a non-interactive shell, and the ROS 2
# setup scripts are noisy when sourced from one.
[[ $- == *i* ]] || return 0

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

source /opt/ros/jazzy/setup.bash

# The workspace is bind-mounted from the host, so its install space only
# exists once the student has built something.
if [[ -f "$HOME/ros2_ws/install/setup.bash" ]]; then
    source "$HOME/ros2_ws/install/setup.bash"
fi

export TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-waffle_pi}"

# Gazebo resolves model:// URIs (the house and robot in the lab worlds) through
# GZ_SIM_RESOURCE_PATH. tb3_launch.py sets this for worlds it starts, but it
# is exported here too so that manual `gz` commands and `ros_gz_sim create`
# find the models as well.
export GZ_SIM_RESOURCE_PATH="/opt/ros/jazzy/share/turtlebot3_gazebo/models${GZ_SIM_RESOURCE_PATH:+:$GZ_SIM_RESOURCE_PATH}"

# lab/bin (run-world, run-build, ...) is not on the default PATH.
export PATH="$HOME/bin:$PATH"

# Where things are. TB3_WS can be overridden before this file is sourced.
TB3_WS="${TB3_WS:-$HOME/ros2_ws}"
LAB_WORLD_DIR="$HOME/lab/worlds"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------

# Worlds (stock upstream launch files - they spawn the robot)
alias tb3_empty='ros2 launch turtlebot3_gazebo empty_world.launch.py'
alias test_tb3='ros2 launch turtlebot3_gazebo empty_world.launch.py'
alias tb3_base='ros2 launch turtlebot3_gazebo empty_world.launch.py'
alias tb3_world='ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py'
alias tb3_house='ros2 launch turtlebot3_gazebo turtlebot3_house.launch.py'

alias tb3_teleop='ros2 run turtlebot3_teleop teleop_keyboard'

# Spawn a robot into an already-running Base World, at the origin.
alias tb3_spawn='ros2 run ros_gz_sim create -file "/opt/ros/jazzy/share/turtlebot3_gazebo/models/turtlebot3_${TURTLEBOT3_MODEL}/model.sdf" -x 0 -y 0 -z 0.1'

alias tb3_rviz2='ros2 launch turtlebot3_bringup rviz2.launch.py'

# ---------------------------------------------------------------------------
# Gazebo management
# ---------------------------------------------------------------------------

# Stop Gazebo. Gazebo Sim (gz sim) runs as the `gz sim` CLI process plus the
# gz-sim server and GUI binaries it starts (gz-sim8-gazebo-server,
# gz-sim8-gazebo-gui in Harmonic); the two patterns below cover all of them.
tb3_kill() {
    echo "[tb3_kill] Searching for Gazebo processes…"

    local PATTERNS=(
        'gz sim'
        'gz-sim'
    )

    local PIDS=""

    local PAT FOUND
    for PAT in "${PATTERNS[@]}"; do
        FOUND=$(pgrep -f "$PAT")
        if [[ -n "$FOUND" ]]; then
            PIDS+=" $FOUND"
        fi
    done

    if [[ -z "$PIDS" ]]; then
        echo "[tb3_kill] No Gazebo-related processes detected."
        return 0
    fi

    echo "[tb3_kill] Found PIDs: $PIDS"
    echo "[tb3_kill] Sending SIGTERM…"
    # shellcheck disable=SC2086  # word splitting of PIDS is intended
    kill $PIDS 2>/dev/null || true
    sleep 1

    local STILL_RUNNING=""
    local PID
    for PID in $PIDS; do
        if ps -p "$PID" >/dev/null 2>&1; then
            STILL_RUNNING+=" $PID"
        fi
    done

    if [[ -z "$STILL_RUNNING" ]]; then
        echo "[tb3_kill] All Gazebo processes terminated cleanly."
        return 0
    fi

    echo "[tb3_kill] Force killing with SIGKILL (-9): $STILL_RUNNING"
    # shellcheck disable=SC2086
    kill -9 $STILL_RUNNING 2>/dev/null || true
    echo "[tb3_kill] Done."
}

# Stop Gazebo and every ROS 2 node, then restart the ros2 daemon so it stops
# reporting nodes that no longer exist.
tb3_kill_all() {
    tb3_kill

    pkill -9 -f "rclpy"          2>/dev/null || true
    pkill -9 -f "python.*launch" 2>/dev/null || true
    pkill -9 -f "ros2 launch"    2>/dev/null || true
    pkill -9 -f "rclcpp"         2>/dev/null || true
    pkill -9 -f "ros2_node"      2>/dev/null || true
    pkill -9 -f "ros_gz"         2>/dev/null || true

    echo "[tb3_kill_all] Restarting ros2 daemon…"
    ros2 daemon stop 2>/dev/null || true
    ros2 daemon start 2>/dev/null || true
    echo "[tb3_kill_all] Done."
}

# ---------------------------------------------------------------------------
# Build helpers
# ---------------------------------------------------------------------------

tb3_build() {
    cd "$TB3_WS" || return 1
    colcon build --symlink-install --executor sequential
    source "$TB3_WS/install/setup.bash"
}

tb3_build_par() {
    cd "$TB3_WS" || return 1
    colcon build --symlink-install
    source "$TB3_WS/install/setup.bash"
}

tb3_build_pkg() {
    if [[ $# -eq 0 ]]; then
        echo "[tb3_build_pkg] ERROR: No package specified"
        return 1
    fi

    cd "$TB3_WS" || return 1
    colcon build --symlink-install --executor sequential --packages-select "$@"
    source "$TB3_WS/install/setup.bash"
}

tb3_build_pkg_par() {
    if [[ $# -eq 0 ]]; then
        echo "[tb3_build_pkg_par] ERROR: No package specified"
        return 1
    fi

    cd "$TB3_WS" || return 1
    colcon build --symlink-install --packages-select "$@"
    source "$TB3_WS/install/setup.bash"
}

tb3_rebuild_pkg() {
    if [[ $# -eq 0 ]]; then
        echo "[tb3_rebuild_pkg] ERROR: No package specified"
        return 1
    fi

    cd "$TB3_WS" || return 1

    local PKG
    for PKG in "$@"; do
        echo "[tb3_rebuild_pkg] Cleaning $PKG"
        rm -rf "build/$PKG" "install/$PKG"
    done

    colcon build --symlink-install --executor sequential --packages-select "$@"
    source "$TB3_WS/install/setup.bash"
}

tb3_clean() {
    cd "$TB3_WS" || return 1
    rm -rf build/ install/ log/
}

tb3_rebuild() {
    tb3_clean
    tb3_build
}

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------

# Package names for the build helpers: whatever has been built in build/, or
# failing that whatever colcon can see in the workspace.
_tb3_complete_packages() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    if [[ -d "$TB3_WS/build" ]]; then
        local pkgs
        pkgs=$(ls -1 "$TB3_WS/build" 2>/dev/null)
        COMPREPLY=( $(compgen -W "${pkgs}" -- "${cur}") )
        return 0
    fi

    if command -v colcon >/dev/null 2>&1; then
        local pkgs
        pkgs=$(cd "$TB3_WS" && colcon list --names-only 2>/dev/null)
        COMPREPLY=( $(compgen -W "${pkgs}" -- "${cur}") )
        return 0
    fi

    return 0
}

# Print useful environment info for interactive shells
if [[ -n "$PS1" ]]; then
    echo "[TB3_ENV] TURTLEBOT3_MODEL=${TURTLEBOT3_MODEL:-unset}  ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}  ROS_DISTRO=${ROS_DISTRO:-jazzy}"
    command -v ros2 >/dev/null 2>&1 && ros2 --help >/dev/null 2>&1 && echo "[TB3_ENV] ROS 2 CLI available" || echo "[TB3_ENV] ROS 2 CLI available"
    echo "[TB3_ENV] GZ_SIM_RESOURCE_PATH=${GZ_SIM_RESOURCE_PATH}"
    echo "[TB3_ENV] TB3_WS=${TB3_WS}  LAB=$HOME/lab"
fi
_tb3_complete_worlds() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    local worlds=""
    if [[ -d "$LAB_WORLD_DIR" ]]; then
        worlds=$(ls -1 "$LAB_WORLD_DIR"/*.world 2>/dev/null \
            | xargs -n1 basename 2>/dev/null \
            | sed 's/\.world$//')
    fi

    COMPREPLY=(
        $(compgen -W "${worlds}" -- "${cur}")
        $(compgen -f -X '!*.world' -- "${cur}")
    )
    return 0
}

complete -F _tb3_complete_worlds run-world
