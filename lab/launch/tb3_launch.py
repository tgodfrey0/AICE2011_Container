#!/usr/bin/env python3
#
# AICE2011 lab launcher.
#
#   ros2 launch /home/student/lab/launch/tb3_launch.py world:=base_world
#   ros2 launch /home/student/lab/launch/tb3_launch.py world:=house_world
#
# `world` may also be an absolute path to any .world / .sdf file, which is
# how you bring your own world into the lab.
#
# This does three things and deliberately nothing else:
#
#   1. Starts Gazebo with the chosen world, server and GUI.
#   2. Publishes the robot's TF frames.
#   3. Bridges Gazebo topics onto ROS 2 topics (/scan, /odom, /imu, /camera).
#
# It does NOT spawn the robot. The worlds in lab/worlds contain the robot
# already, because Gazebo can only service a spawn request once the world has
# finished loading -- and on a software-rendered container that takes long
# enough that the shipped launch files regularly lose the request, which is
# how you end up with a Gazebo window containing no robot.
#
# See the world files themselves for how to add one.


import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import (
    AppendEnvironmentVariable,
    DeclareLaunchArgument,
    IncludeLaunchDescription,
    OpaqueFunction,
)
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

WORLD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, 'worlds')


def _world_path(context):
    """Resolve the `world` argument to a file on disk.

    Accepts either a bare name that lives in lab/worlds, or an absolute path
    to a world file anywhere on disk.
    """
    world = LaunchConfiguration('world').perform(context).strip()

    candidates = []
    if os.path.isabs(world):
        candidates.append(world)
    else:
        candidates.append(os.path.join(WORLD_DIR, world))
    candidates.extend([
        os.path.join(WORLD_DIR, world + '.world'),
        os.path.join(WORLD_DIR, world + '.sdf'),
    ])

    for candidate in candidates:
        if os.path.isfile(candidate):
            return os.path.abspath(candidate)

    raise RuntimeError(
        "Cannot find world '{}'. Looked in: {}".format(
            world, ', '.join(sorted({os.path.abspath(c) for c in candidates}))
        )
    )


def _gazebo(context, *args, **kwargs):
    world_path = _world_path(context)

    gazebo_share = get_package_share_directory('ros_gz_sim')

    server = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(gazebo_share, 'launch', 'gz_sim.launch.py')
        ),
        launch_arguments={
            'gz_args': '-r -s -v2 {}'.format(world_path),
            'on_exit_shutdown': 'true',
        }.items(),
    )

    client = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(gazebo_share, 'launch', 'gz_sim.launch.py')
        ),
        launch_arguments={
            'gz_args': '-g -v2',
        }.items(),
    )

    return [server, client]


def generate_launch_description():
    turtlebot3_share = get_package_share_directory('turtlebot3_gazebo')
    model = os.environ.get('TURTLEBOT3_MODEL', 'waffle_pi')

    robot_state_publisher = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(turtlebot3_share, 'launch', 'robot_state_publisher.launch.py')
        ),
        launch_arguments={'use_sim_time': 'true'}.items(),
    )

    # Gazebo <-> ROS 2 bridge, using the topic mapping that ships with the
    # robot model. Without this, Gazebo has topics but ROS 2 sees nothing.
    bridge_params = os.path.join(
        turtlebot3_share, 'params', 'turtlebot3_{}_bridge.yaml'.format(model)
    )

    bridge = Node(
        package='ros_gz_bridge',
        executable='parameter_bridge',
        arguments=['--ros-args', '-p', 'config_file:={}'.format(bridge_params)],
        output='screen',
    )

    actions = [
        DeclareLaunchArgument(
            'world',
            default_value='house_world',
            description='Name of a world in lab/worlds, or an absolute path to one.',
        ),

        # model:// URIs in the world files resolve through this. It has to be
        # set before Gazebo is started, not after, so it goes first.
        AppendEnvironmentVariable(
            'GZ_SIM_RESOURCE_PATH', turtlebot3_share + '/models'
        ),

        OpaqueFunction(function=_gazebo),
        robot_state_publisher,
        bridge,
    ]

    # The burger has no camera, so bridging its image topic only produces
    # errors in the log.
    if model != 'burger':
        actions.append(Node(
            package='ros_gz_image',
            executable='image_bridge',
            arguments=['/camera/image_raw'],
            output='screen',
        ))

    return LaunchDescription(actions)