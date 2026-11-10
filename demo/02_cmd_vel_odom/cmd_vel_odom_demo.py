#!/usr/bin/env python3
###############################################################################
# Demo 2 -- ROS 2 node: publish, subscribe, plot.
#
#   publisher : /cmd_vel   geometry_msgs/msg/TwistStamped   this node -> robot
#   subscriber: /odom      nav_msgs/msg/Odometry            robot -> this node
#
# The node commands a constant turn (linear 0.2 m/s, angular 0.4 rad/s), so
# the robot drives a circle of radius v/omega = 0.5 m and stays inside the
# world. Every /odom message is recorded and drawn live by matplotlib:
#
#   left  : the x/y path travelled so far (odometry, not ground truth)
#   right : measured linear velocity against time
#
# Run it after the world is up:
#
#   python3 cmd_vel_odom_demo.py
#
# Ctrl+C stops it. No package and no colcon build needed: rclpy and the
# message types are plain Python modules from the ROS 2 install.
###############################################################################

import collections
import threading
import time

import matplotlib

matplotlib.use("TkAgg")  # opens its own window instead of drawing in the terminal
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.figure import Figure

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from geometry_msgs.msg import TwistStamped
from nav_msgs.msg import Odometry

# --- what the robot is told to do -------------------------------------------
LINEAR_X = 0.2    # m/s forward
ANGULAR_Z = 0.4   # rad/s turn  -> circle radius = LINEAR_X / ANGULAR_Z = 0.5 m
PUBLISH_RATE = 10.0  # Hz

# How many odometry samples to keep. Bounded so a demo left running all lecture
# does not grow without limit.
HISTORY = 5000


class CmdVelOdomDemo(Node):
    """Publish a speed command, record the odometry that comes back."""

    def __init__(self):
        super().__init__("cmd_vel_odom_demo")

        # The publisher declares what it sends: topic name + message type.
        self.pub = self.create_publisher(TwistStamped, "/cmd_vel", 10)

        # The subscriber hands every message to a callback.
        self.sub = self.create_subscription(Odometry, "/odom", self.on_odom, 20)

        # A timer is how a node does something periodically; here it publishes.
        self.timer = self.create_timer(1.0 / PUBLISH_RATE, self.publish_cmd)

        # Everything the callback records, read by the matplotlib thread.
        # deques are append/pop-safe from two threads.
        self.t0 = time.monotonic()
        self.t = collections.deque(maxlen=HISTORY)
        self.x = collections.deque(maxlen=HISTORY)
        self.y = collections.deque(maxlen=HISTORY)
        self.vx = collections.deque(maxlen=HISTORY)
        self.wz = collections.deque(maxlen=HISTORY)

        self._odom_seen = False
        self._last_report = 0.0

        self.get_logger().info(
            f"publishing /cmd_vel (geometry_msgs/msg/TwistStamped) "
            f"at {PUBLISH_RATE:.0f} Hz: linear.x={LINEAR_X}, angular.z={ANGULAR_Z}"
        )

    def publish_cmd(self):
        msg = TwistStamped()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.twist.linear.x = LINEAR_X
        msg.twist.angular.z = ANGULAR_Z
        self.pub.publish(msg)

    def on_odom(self, msg: Odometry):
        if not self._odom_seen:
            self._odom_seen = True
            self.get_logger().info("first /odom (nav_msgs/msg/Odometry) received")

        self.t.append(time.monotonic() - self.t0)
        self.x.append(msg.pose.pose.position.x)
        self.y.append(msg.pose.pose.position.y)
        self.vx.append(msg.twist.twist.linear.x)
        self.wz.append(msg.twist.twist.angular.z)

        now = time.monotonic()
        if now - self._last_report >= 5.0:
            self._last_report = now
            self.get_logger().info(
                f"x={self.x[-1]:+.2f} m  y={self.y[-1]:+.2f} m  "
                f"v={self.vx[-1]:+.2f} m/s"
            )


def make_figure() -> Figure:
    fig, (ax_path, ax_vel) = plt.subplots(1, 2, figsize=(11, 4.5))
    fig.suptitle("TurtleBot3: /cmd_vel out, /odom in")

    ax_path.set_title("odometry path (m)")
    ax_path.set_xlabel("x [m]")
    ax_path.set_ylabel("y [m]")
    ax_path.axis("equal")
    ax_path.grid(True)

    ax_vel.set_title("measured linear velocity (m/s)")
    ax_vel.set_xlabel("time [s]")
    ax_vel.set_ylabel("vx [m/s]")
    ax_vel.grid(True)

    if hasattr(fig.canvas.manager, "set_window_title"):
        fig.canvas.manager.set_window_title("/cmd_vel -> /odom demo")
    return fig


def main():
    rclpy.init()

    node = CmdVelOdomDemo()

    # Spin in the background: matplotlib owns the main thread, but the node
    # still needs someone to service the timer and the subscriber callback.
    def spin_node():
        # Exiting the context is a normal end, not an error worth a traceback
        # from inside the thread.
        try:
            rclpy.spin(node)
        except ExternalShutdownException:
            pass

    spinner = threading.Thread(target=spin_node, daemon=True)
    spinner.start()

    fig = make_figure()
    (path_line,) = fig.axes[0].plot([], [], "C0-", linewidth=1.5)
    (vel_line,) = fig.axes[1].plot([], [], "C1-", linewidth=1.5)

    def redraw(_frame):
        # Read the shared history and update both axes.
        t, x, y, vx = node.t, node.x, node.y, node.vx
        if x:
            path_line.set_data(x, y)
            ax = fig.axes[0]
            ax.relim()
            ax.autoscale_view()
        if t:
            vel_line.set_data(t, vx)
            ax = fig.axes[1]
            ax.relim()
            ax.autoscale_view()
        return path_line, vel_line

    # Keep a reference: FuncAnimation stops working if it is garbage collected.
    _anim = FuncAnimation(
        fig, redraw, interval=200, blit=False, cache_frame_data=False
    )

    try:
        plt.show()  # blocks until the window is closed
    except KeyboardInterrupt:
        pass
    finally:
        rclpy.shutdown()
        spinner.join(timeout=2.0)
        node.destroy_node()
        print("\n[cmd_vel_odom_demo] stopped.")


if __name__ == "__main__":
    main()
