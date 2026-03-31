# CLAUDE.md — lerobot_dev

Development package for SO-101 LeRobot experiments. See workspace root `CLAUDE.md` for build/test/lint commands.

## This Package

`lerobot_dev` is the primary workspace for custom nodes, scripts, and experiments. Add new ROS2 nodes here rather than in `lerobot_base`.

**Entry points** are registered in `setup.py` under `console_scripts`. After `colcon build + source`, they become available as CLI commands.

## Workspace Package Overview

### so101_ros2 (`src/so101_ros2/`)
Hardware interface for the SO-101 arm. Two nodes:
- `so101_ros2_pub` — reads servo positions via Feetech serial, publishes `/joint_states`
- `so101_ros2_sub` — subscribes to `/joint_commands`, drives servos

Key class: `SO101` in `so101_ros2/lerobot/so101.py` — wraps the `FeetechMotorsBus` from LeRobot.

Launch files: `so101_publisher_launch.py`, `so101_subscriber_launch.py`

Dependencies: `deepdiff`, `feetech-servo-sdk` (install via pip if missing)

### lerobot-ros (`src/lerobot-ros/`)
Pip-installed bridge package (NOT a colcon package). Provides:
- `so101_ros` robot type — uses joint names `["1", "2", "3", "4", "5"]` (strings, not `joint_1`)
- `keyboard_joint` and `gamepad_6dof` teleoperator types
- ros2_control and MoveIt Servo integration

Installed editable: `pip install -e ./lerobot_robot_ros -e ./lerobot_teleoperator_devices`

### lerobot (`src/lerobot/`)
HuggingFace LeRobot v0.4.4. Pip-installed, editable. Key submodules:
- `lerobot/robots/` — `so_follower` (direct serial), robot configs
- `lerobot/policies/` — ACT, Diffusion, pi0, SmolVLA, Gr00t, pi05, pi0_fast, rtc, sarm, xvla
- `lerobot/datasets/` — `LeRobotDataset` v3 (Parquet + MP4)
- `lerobot/scripts/` — all CLI entry points (17 total)

## SO-101 Joint Names

**Direct path** (`so101_follower`): motor keys are `shoulder_pan.pos`, `shoulder_lift.pos`, `elbow_flex.pos`, `wrist_flex.pos`, `wrist_roll.pos`, `gripper.pos`

**ROS2 path** (`so101_ros`): joint names are `["1", "2", "3", "4", "5"]`

These differ — dataset observation keys will differ between paths.

## LeRobot v0.4.4 API Notes

ACT config uses `input_features` / `output_features` dicts of `PolicyFeature(type=FeatureType.X, shape=(...))` — not the older `input_shapes` / `input_normalization_modes` pattern.

Normalization uses `NormalizationMode.MEAN_STD` / `MIN_MAX` / `IDENTITY` enum values.
Arm joints use `MotorNormMode.DEGREES` (default). Gripper always uses `RANGE_0_100`.

ACT constraints from `__post_init__`:
- `n_action_steps <= chunk_size`
- `n_obs_steps == 1`
- `temporal_ensemble_coeff` requires `n_action_steps=1`

## RealSense D435

Camera type for LeRobot configs: `"type": "realsense"`. Set `"use_depth": false` for RGB-only, `"use_depth": true` for RGB+depth.

Default ROS2 topics when using `realsense2_camera`:
- `/camera/camera/color/image_raw` — RGB
- `/camera/camera/depth/image_rect_raw` — Depth
- `/camera/camera/aligned_depth_to_color/image_raw` — Depth aligned to RGB

## Key Topics

| Topic | Type |
|-------|------|
| `/joint_states` | `sensor_msgs/JointState` |
| `/joint_commands` | `sensor_msgs/JointState` |
| `/gripper_controller/joint_trajectory` | `trajectory_msgs/JointTrajectory` |

## See Also

- `HANDY_COMMANDS.md` — all common commands, aliases, camera commands
- Workspace root `CLAUDE.md` — build, test, lint commands
- `../../LEROBOT_SO101_DEVELOPMENT.md` — full workflow guide
