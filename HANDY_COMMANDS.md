# Handy Commands — LeRobot SO-101 Dev

Quick reference for daily development. All commands assume `conda activate lerobot_jazzy` is already done.

---

## Environment

```bash
# Activate environment (ROS2 Jazzy auto-sources on activation)
conda activate lerobot_jazzy

# Source workspace after build
source /home/koen/Documents/Personal/code/lerobot/install/setup.bash
```

---

## Build

```bash
# Full build
cd /home/koen/Documents/Personal/code/lerobot && colcon build

# Single package
colcon build --packages-select lerobot_dev
colcon build --packages-select so101_ros2
colcon build --packages-select lerobot_base

# Build + source in one line
colcon build && source install/setup.bash
```

---

## Teleoperation

### From .bashrc aliases

```bash
# Uses $LERO_FOLLOWER_PORT and $LERO_LEADER_PORT (set via lero-setup-env)
teleop-start
start-teleop
```

### Via ROS2 bridge

```bash
# Launch SO-101 publisher (reads hardware, publishes /joint_states)
ros2 launch so101_ros2 so101_publisher_launch.py

# Launch SO-101 subscriber (listens to /joint_commands, drives hardware)
ros2 launch so101_ros2 so101_subscriber_launch.py

# Keyboard teleoperation via lerobot-ros
lerobot-teleoperate \
  --robot.type=so101_ros \
  --robot.id=my_awesome_follower_arm \
  --teleop.type=keyboard_joint \
  --teleop.id=my_awesome_leader_arm \
  --display_data=true
```

---

## Quick Record (bash function)

### First-time setup

Run the interactive setup script once to store your hardware config in `~/.bashrc`:

```bash
lero-setup-env
# or directly:
bash src/lerobot_dev/scripts/lero_setup_env.sh
```

It will prompt for:
- **Follower arm serial port** (e.g. `/dev/ttyACM0`) — run `lero-find-port` first
- **Leader arm serial port** (e.g. `/dev/ttyACM1`)
- **RealSense D435 serial number** (e.g. `123456789012`) — run `cam-find` first; leave empty for no camera

The script writes these env vars to `~/.bashrc` and can be re-run to update them:
```bash
LERO_FOLLOWER_PORT=/dev/ttyACM0
LERO_LEADER_PORT=/dev/ttyACM1
LERO_CAM_SERIAL=123456789012
```

After running, reload with `src_b`.

### Recording

```bash
# Signature
lero-record "task description" [dataset_name] [num_episodes]

# Minimal — uses dataset name "so101_dataset" and 50 episodes
lero-record "Pick up the red block and place it in the bin"

# Custom dataset name
lero-record "Pick up the red block and place it in the bin" so101_pick_block

# Custom dataset name and episode count
lero-record "Pick up the red block and place it in the bin" so101_pick_block 100
```

- Auto-detects your HuggingFace username
- Uses `LERO_FOLLOWER_PORT`, `LERO_LEADER_PORT`, `LERO_CAM_SERIAL` from env
- If `LERO_CAM_SERIAL` is not set, records without camera (joints only)
- Prints a summary of ports and camera before starting

---

## Data Recording (full commands)

```bash
# Get your HuggingFace username
export HF_USER=$(NO_COLOR=1 hf auth whoami | awk -F': *' 'NR==1 {print $2}')

# Find RealSense serial number
lerobot-find-cameras realsense

# Record joints only (no camera)
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm \
  --teleop.type=so101_leader \
  --teleop.port=$LERO_LEADER_PORT \
  --teleop.id=my_awesome_leader_arm \
  --dataset.repo_id=${HF_USER}/<dataset_name> \
  --dataset.single_task="<describe the task>" \
  --dataset.num_episodes=50

# Record with RealSense D435 (RGB only)
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm \
  --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480}}' \
  --teleop.type=so101_leader \
  --teleop.port=$LERO_LEADER_PORT \
  --teleop.id=my_awesome_leader_arm \
  --display_data=true \
  --dataset.repo_id=${HF_USER}/<dataset_name> \
  --dataset.single_task="<describe the task>" \
  --dataset.num_episodes=50

# Record with RealSense D435 (RGB + Depth)
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm \
  --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480, "use_depth": true}}' \
  --teleop.type=so101_leader \
  --teleop.port=$LERO_LEADER_PORT \
  --teleop.id=my_awesome_leader_arm \
  --display_data=true \
  --dataset.repo_id=${HF_USER}/<dataset_name> \
  --dataset.single_task="<describe the task>" \
  --dataset.num_episodes=50

# Resume recording into existing dataset
lerobot-record \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm \
  --teleop.type=so101_leader \
  --teleop.port=$LERO_LEADER_PORT \
  --teleop.id=my_awesome_leader_arm \
  --dataset.repo_id=${HF_USER}/<dataset_name> \
  --dataset.single_task="<describe the task>" \
  --dataset.num_episodes=25 \
  --resume=true

# During recording keyboard controls:
# Space      = end episode early (save it)
# Backspace  = discard episode (re-record)
# q / Ctrl+C = stop session
```

---

## RealSense D435 Camera

```bash
# Check if camera is detected
rs-enumerate-devices

# View RGB stream only (640x480 @ 30fps)
realsense-viewer
# or via ROS2:
ros2 launch realsense2_camera rs_launch.py enable_depth:=false enable_color:=true

# View RGB + Depth streams (3D)
ros2 launch realsense2_camera rs_launch.py enable_depth:=true enable_color:=true align_depth.enable:=true

# Record RGB-only images for LeRobot dataset
# (see lerobot-record commands above with use_depth: false)

# Record RGB + Depth for LeRobot dataset
# (see lerobot-record commands above with use_depth: true)

# Quick camera preview with cv2 (Python)
python3 -c "
import pyrealsense2 as rs, numpy as np, cv2
pipe = rs.pipeline()
cfg = rs.config()
cfg.enable_stream(rs.stream.color, 640, 480, rs.format.bgr8, 30)
pipe.start(cfg)
while True:
    frame = pipe.wait_for_frames().get_color_frame()
    cv2.imshow('RealSense RGB', np.asanyarray(frame.get_data()))
    if cv2.waitKey(1) == ord('q'): break
pipe.stop()
"

# Quick RGB + Depth preview
python3 -c "
import pyrealsense2 as rs, numpy as np, cv2
pipe = rs.pipeline()
cfg = rs.config()
cfg.enable_stream(rs.stream.color, 640, 480, rs.format.bgr8, 30)
cfg.enable_stream(rs.stream.depth, 640, 480, rs.format.z16, 30)
pipe.start(cfg)
align = rs.align(rs.stream.color)
while True:
    frames = align.process(pipe.wait_for_frames())
    color = np.asanyarray(frames.get_color_frame().get_data())
    depth = np.asanyarray(frames.get_depth_frame().get_data())
    depth_vis = cv2.applyColorMap(cv2.convertScaleAbs(depth, alpha=0.03), cv2.COLORMAP_JET)
    cv2.imshow('RGB', color); cv2.imshow('Depth', depth_vis)
    if cv2.waitKey(1) == ord('q'): break
pipe.stop()
"
```

---

## Training

```bash
# Train ACT policy
lerobot-train \
  --policy.type=act \
  --dataset.repo_id=<your_hf_username>/<dataset_name> \
  --output_dir=outputs/train/act_so101

# Train Diffusion policy
lerobot-train \
  --policy.type=diffusion \
  --dataset.repo_id=<your_hf_username>/<dataset_name> \
  --output_dir=outputs/train/diffusion_so101

# Resume training from checkpoint
lerobot-train \
  --policy.type=act \
  --dataset.repo_id=<your_hf_username>/<dataset_name> \
  --resume=true \
  --output_dir=outputs/train/act_so101
```

---

## Replay / Evaluation

```bash
# Replay a recorded episode
lerobot-replay \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm \
  --dataset.repo_id=<your_hf_username>/<dataset_name> \
  --episode=0

# Run policy on robot
lerobot-eval \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm \
  --policy.path=outputs/train/act_so101/checkpoints/last/pretrained_model

# Find joint limits (calibration helper)
lerobot-find-joint-limits \
  --robot.type=so101_follower \
  --robot.port=$LERO_FOLLOWER_PORT \
  --robot.id=my_awesome_follower_arm
```

---

## ROS2 Debugging

```bash
# List all active topics
ros2 topic list

# Monitor joint states
ros2 topic echo /joint_states

# Monitor joint commands
ros2 topic echo /joint_commands

# Check node graph
ros2 node list
ros2 node info /lerobot_joint_state_publisher

# Record a bag file
ros2 bag record /joint_states /joint_commands -o my_bag

# Check LeRobot version
python -c "import lerobot; print(lerobot.__version__)"
```

---

## Code Quality

```bash
# Run all pre-commit checks (alias: start-precommit)
pre-commit run --all-files

# Ruff lint + format
ruff check src/ --fix && ruff format src/

# Run tests for this package
colcon test --packages-select lerobot_dev
colcon test-result --verbose
```

---

## .bashrc Aliases Reference

| Alias | What it does |
|-------|-------------|
| `start-teleop` | Teleoperate (ACM1 follower + ACM0 leader) |
| `teleop-start` | Teleoperate (ACM0 follower + ACM1 leader) |
| `lero-ws` | `cd` to workspace root |
| `lero-build` | Build workspace + source |
| `lero-source` | Source workspace install |
| `lero-find-port` | Find USB serial ports for SO-101 arms |
| `lero-latency` | Set low_latency on both USB serial ports |
| `lero-calibrate-follower` | Calibrate follower arm (ACM0) |
| `lero-calibrate-leader` | Calibrate leader arm (ACM1) |
| `lero-setup-env` | Interactive setup: write ports + camera serial to `~/.bashrc` |
| `lero-record "task" [name] [n]` | Record dataset — uses env vars for ports/camera |
| `lero-whoami` | Set `$HF_USER` env var from logged-in HF account |
| `lero-viz` | Open Rerun dataset visualizer |
| `lero-inspect` | Quick Python dataset info (interactive) |
| `cam-rgb` | Launch RealSense RGB-only stream (ROS2) |
| `cam-3d` | Launch RealSense RGB+Depth stream (ROS2) |
| `cam-find` | Find RealSense camera serial numbers |
| `cam-find-usb` | Find USB camera indices |
| `start-precommit` | `pre-commit run -a` |
| `src_b` | `source ~/.bashrc` |
