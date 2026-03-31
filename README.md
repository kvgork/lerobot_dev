# lerobot_dev

Primary development package for SO-101 LeRobot experiments. Part of a ROS2 Jazzy workspace integrating HuggingFace LeRobot with the SO-101 robot arm.

## Quick Start

```bash
# 1. Activate environment
conda activate lerobot_jazzy

# 2. Configure hardware (once)
lero-setup-env   # sets LERO_FOLLOWER_PORT, LERO_LEADER_PORT, LERO_CAM_SERIAL

# 3. Build
cd /home/koen/Documents/Personal/code/lerobot && colcon build && source install/setup.bash

# 4. Record a dataset
lero-record "Pick up the red block" so101_pick_block 50
```

## Documentation

| File | Description |
|------|-------------|
| `docs/HANDY_COMMANDS.md` | All aliases, shortcuts, and common commands |
| `docs/DATASET_RECORDING_GUIDE.md` | Step-by-step guide from calibration to published dataset |
| `docs/TRAINING_ARCHITECTURE.md` | Policy selection, training configs, and deployment plan |
| `CLAUDE.md` | Architecture notes for Claude Code |

## Hardware

- **Robot:** SO-101 arm (6-DoF, Feetech STS3215 servos)
- **Camera:** RealSense D435
- **Environment:** ROS2 Jazzy via RoboStack (conda env `lerobot_jazzy`)

## Related Packages

| Package | Purpose |
|---------|---------|
| `so101_ros2` | ROS2 hardware interface (serial comms) |
| `lerobot-ros` | LeRobot ↔ ROS2 bridge, `so101_ros` robot type |
| `lerobot` | HuggingFace LeRobot v0.4.4 (policies, datasets, CLI) |
