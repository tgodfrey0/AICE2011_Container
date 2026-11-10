#!/usr/bin/env bash
###############################################################################
# Demo 1 -- Gazebo world, RViz2, keyboard teleop and a spare shell, one tmux
# pane per process, arranged as a 2x2 grid.
#
#   ./rviz.sh                 start the demo (attaches to the tmux session)
#   Ctrl-b d                  detach, leaving everything running
#   tmux attach -t tb3_rviz   attach again
#   tmux kill-session -t tb3_rviz    end the demo
#
# The shell pane is for poking at the graph while the demo runs, e.g.
#   ros2 topic list   |   ros2 node list   |   ros2 topic echo /odom --once
#
# ROS 2 is sourced from ~/.bashrc, and tmux panes are interactive shells, so
# every pane gets the ROS 2 environment (and setup/tb3_env.sh) automatically.
#
# TURTLEBOT3_MODEL is the one thing that has to be forced: the image ships
# ENV TURTLEBOT3_MODEL=waffle_pi, and tb3_env.sh only fills in a default when
# the variable is unset, so waffle_pi would otherwise win.
###############################################################################

set -o pipefail

SESSION="tb3_rviz"
MODEL="waffle"

# Start clean: a leftover session from an earlier run would otherwise be
# reused, with its panes still running the old processes.
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Panes are addressed by pane id (%N), not by index: the index of the first
# pane depends on the pane-base-index setting of whoever's tmux config runs
# this, and -P prints the id of the pane that was just created.
PANE_GAZEBO=$(tmux new-session -d -s "$SESSION" -n world \
    -e "TURTLEBOT3_MODEL=$MODEL" -P -F '#{pane_id}')

# Pane 2 -- RViz2. Started immediately; ROS 2 discovery connects it to the
# simulation as soon as both are up.
PANE_RVIZ=$(tmux split-window -h -t "$SESSION:world" -P -F '#{pane_id}')
tmux select-pane -t "$PANE_RVIZ" -T rviz
tmux send-keys -t "$PANE_RVIZ" \
    'ros2 launch turtlebot3_bringup rviz2.launch.py' C-m

# Pane 3 -- keyboard teleop. Click this pane to give it focus before driving.
PANE_TELEOP=$(tmux split-window -v -t "$SESSION:world" -P -F '#{pane_id}')
tmux select-pane -t "$PANE_TELEOP" -T teleop
tmux send-keys -t "$PANE_TELEOP" \
    'ros2 run turtlebot3_teleop teleop_keyboard' C-m

# Pane 4 -- a free shell for inspecting the graph while the demo runs.
PANE_SHELL=$(tmux split-window -v -t "$SESSION:world" -P -F '#{pane_id}')
tmux select-pane -t "$PANE_SHELL" -T shell
tmux send-keys -t "$PANE_SHELL" \
    "echo 'Shell pane -- try:  ros2 topic list |  ros2 node list |  ros2 topic echo /odom --once'" C-m

# The Gazebo pane is created first, so it is the only one not named yet.
tmux select-pane -t "$PANE_GAZEBO" -T gazebo
tmux send-keys -t "$PANE_GAZEBO" \
    'ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py' C-m

# Label each pane on screen, then arrange the four as a 2x2 grid.
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format ' #{pane_title} '
tmux select-layout -t "$SESSION:world" tiled
tmux select-pane -t "$PANE_GAZEBO"

exec tmux attach -t "$SESSION"
