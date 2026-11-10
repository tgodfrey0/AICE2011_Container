#!/usr/bin/env bash
###############################################################################
# Demo 2 -- publish /cmd_vel, subscribe /odom, plot it live. One tmux pane per
# process.
#
#   ./run.sh                  start the demo (attaches to the tmux session)
#   Ctrl-b d                  detach, leaving everything running
#   tmux attach -t tb3_plot   attach again
#   tmux kill-session -t tb3_plot     end the demo
#
# ROS 2 is sourced from ~/.bashrc, and tmux panes are interactive shells, so
# every pane gets the ROS 2 environment (and setup/tb3_env.sh) automatically.
# TURTLEBOT3_MODEL is forced to waffle: the image default is waffle_pi and
# tb3_env.sh only fills in a default when the variable is unset.
###############################################################################

set -o pipefail

SESSION="tb3_plot"
MODEL="waffle"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Start clean: a leftover session from an earlier run would otherwise be
# reused, with its panes still running the old processes.
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Panes are addressed by pane id (%N), not by index: the index of the first
# pane depends on the pane-base-index setting of whoever's tmux config runs
# this, and -P prints the id of the pane that was just created.
PANE_GAZEBO=$(tmux new-session -d -s "$SESSION" -n demo \
    -e "TURTLEBOT3_MODEL=$MODEL" -P -F '#{pane_id}')

# Pane 2 -- the demo node: publishes /cmd_vel, records /odom, draws the plot.
# Started immediately like the world; it simply waits for the first /odom.
PANE_PLOT=$(tmux split-window -h -t "$SESSION:demo" -P -F '#{pane_id}')
tmux select-pane -t "$PANE_PLOT" -T plot
tmux send-keys -t "$PANE_PLOT" "python3 '$SCRIPT_DIR/cmd_vel_odom_demo.py'" C-m

# Pane 3 -- a free shell for inspecting the graph while the demo runs:
#   ros2 topic list / ros2 topic info /cmd_vel / ros2 topic echo /odom --once
PANE_SHELL=$(tmux split-window -v -t "$SESSION:demo" -P -F '#{pane_id}')
tmux select-pane -t "$PANE_SHELL" -T shell
tmux send-keys -t "$PANE_SHELL" \
    "echo 'Inspection pane -- try:  ros2 topic list |  ros2 topic info /cmd_vel |  ros2 topic echo /odom --once'" C-m

# The Gazebo pane is created first, so it is the only one not named yet.
# The empty world still spawns the robot (spawn_turtlebot3.launch.py plus
# robot_state_publisher), so /odom is published as usual for the plot.
tmux select-pane -t "$PANE_GAZEBO" -T gazebo
tmux send-keys -t "$PANE_GAZEBO" \
    'ros2 launch turtlebot3_gazebo empty_world.launch.py' C-m

# Label each pane on screen, then spread the three evenly across the window.
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format ' #{pane_title} '
tmux select-layout -t "$SESSION:demo" even-horizontal
tmux select-pane -t "$PANE_GAZEBO"

exec tmux attach -t "$SESSION"
