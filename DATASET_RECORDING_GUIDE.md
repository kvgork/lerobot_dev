# Dataset Recording Guide — SO-101 LeRobot

Step-by-step workflow from hardware setup to a published dataset.
All commands assume `conda activate lerobot_jazzy` is active.

---

## Prerequisites Checklist

- [ ] `conda activate lerobot_jazzy`
- [ ] `source /home/koen/Documents/Personal/code/lerobot/install/setup.bash`
- [ ] Both SO-101 arms plugged in via USB
- [ ] Serial port permissions granted (`sudo usermod -a -G dialout $USER` + re-login)
- [ ] HuggingFace login done (`hf auth login --token $HUGGINGFACE_TOKEN`)
- [ ] Hardware env vars configured (`lero-setup-env`) — sets `LERO_FOLLOWER_PORT`, `LERO_LEADER_PORT`, `LERO_CAM_SERIAL`
- [ ] RealSense D435 plugged in (if using camera)

---

## Step 1 — Find Serial Ports (once per machine/cable)

```bash
lero-find-port
# Unplug one arm when prompted. Repeat for the other arm.
```

Then save the ports permanently:
```bash
lero-setup-env
# Prompts for follower port, leader port, and camera serial.
# Writes LERO_FOLLOWER_PORT, LERO_LEADER_PORT, LERO_CAM_SERIAL to ~/.bashrc.
src_b  # reload
```

Reduce USB latency (run after every reconnect):
```bash
lero-latency
# expands to: sudo setserial $LERO_FOLLOWER_PORT low_latency && sudo setserial $LERO_LEADER_PORT low_latency
```

---

## Step 2 — Configure Motor IDs (once per arm, before assembly)

Connect **one motor at a time** to the controller board. Run the following and follow the prompts:

```bash
# Follower arm
lerobot-setup-motors \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT

# Leader arm
lerobot-setup-motors \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT
```

The script walks through motors 1–6 (gripper first, shoulder_pan last). Press Enter after connecting each.

---

## Step 3 — Calibrate Both Arms (once per robot, re-run if arm behaves erratically)

Calibration files are stored at `~/.cache/huggingface/lerobot/calibration/robots/<robot_id>/`.
The `robot.id` / `teleop.id` must be unique and consistent across all future commands.

```bash
lero-calibrate-follower   # alias for: lerobot-calibrate --robot.type=so101_follower --robot.port=$LERO_FOLLOWER_PORT --robot.id=my_awesome_follower_arm
lero-calibrate-leader     # alias for: lerobot-calibrate --teleop.type=so101_leader --teleop.port=$LERO_LEADER_PORT --teleop.id=my_awesome_leader_arm
```

**Calibration procedure:**
1. Move arm to neutral mid-range pose → press Enter
2. Move every joint through its full range of motion → script finishes automatically

---

## Step 4 — Find Your Camera (if using RealSense D435)

```bash
cam-find      # lerobot-find-cameras realsense — note the serial number shown
cam-find-usb  # lerobot-find-cameras opencv — for USB webcams
```

Then save the serial with `lero-setup-env` (or re-run it to update only the serial).

---

## Step 5 — Test Teleoperation (no recording)

Verify the leader-follower link works before committing to a full recording session.

```bash
# No camera
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --display_data=true

# With RealSense D435 (RGB only)
lerobot-teleoperate \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480}}' \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --display_data=true
```

Or use the alias: `teleop-start` (no camera).

`--display_data=true` opens Rerun with live camera + joint state visualisation.

---

## Step 6 — Record the Dataset

### Quickest way — use the `lero-record` function

```bash
# Minimal (uses $LERO_CAM_SERIAL automatically if set)
lero-record "Pick up the red block and place it in the bin"

# Custom dataset name and episode count
lero-record "Pick up the red block and place it in the bin" so101_pick_block 50
```

See `HANDY_COMMANDS.md` for full `lero-record` usage.

### Full commands (if you need more control)

```bash
export HF_USER=$(NO_COLOR=1 hf auth whoami | awk -F': *' 'NR==1 {print $2}')
export TASK_DESC="Pick up the red block and place it in the bin"
export DATASET_NAME=so101_pick_block
```

#### Option A — No camera (joints only)

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --dataset.repo_id=${HF_USER}/${DATASET_NAME} \
    --dataset.single_task="$TASK_DESC" \
    --dataset.num_episodes=50 \
    --dataset.fps=30 \
    --dataset.episode_time_s=60 \
    --dataset.reset_time_s=30
```

#### Option B — RealSense D435 (RGB only)

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480}}' \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/${DATASET_NAME} \
    --dataset.single_task="$TASK_DESC" \
    --dataset.num_episodes=50
```

#### Option C — RealSense D435 (RGB + Depth)

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480, "use_depth": true}}' \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/${DATASET_NAME} \
    --dataset.single_task="$TASK_DESC" \
    --dataset.num_episodes=50
```

#### Option D — Two cameras (RealSense front + wrist webcam)

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480}, "wrist": {"type": "opencv", "index_or_path": 2, "fps": 30, "width": 640, "height": 480}}' \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --dataset.repo_id=${HF_USER}/${DATASET_NAME} \
    --dataset.single_task="$TASK_DESC" \
    --dataset.num_episodes=50
```

#### Option E — Record locally, push later

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --dataset.repo_id=${HF_USER}/${DATASET_NAME} \
    --dataset.single_task="$TASK_DESC" \
    --dataset.num_episodes=50 \
    --dataset.push_to_hub=false \
    --dataset.root=/home/koen/datasets/${DATASET_NAME}
```

Push later: `lerobot-edit-dataset --repo-id ${HF_USER}/${DATASET_NAME}`

---

## During Recording — Keyboard Controls

| Key | Action |
|-----|--------|
| `Space` | End current episode early and save it |
| `Backspace` | Discard current episode and re-record |
| `q` or `Ctrl+C` | Stop recording (saves current episode first) |

**Tips for good demos:**
- Consistent start pose every episode — use a piece of tape on the table
- Keep episodes roughly the same duration
- Discard (Backspace) any episode where you fumbled or the arm collided
- Aim for 50 clean, consistent demos for ACT

---

## Step 7 — Verify the Recording

```bash
# Replay episode 0 on hardware to check it looks correct
lerobot-replay \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --dataset.repo_id=${HF_USER}/so101_pick_block \
    --dataset.episode=0

# Visualize with Rerun (alias: lero-viz)
lerobot-dataset-viz \
    --repo-id ${HF_USER}/so101_pick_block \
    --episode-index 0

# Quick dataset inspection (alias: lero-inspect)
python3 -c "
from lerobot.datasets.lerobot_dataset import LeRobotDataset
ds = LeRobotDataset('${HF_USER}/so101_pick_block')
print('Features:', list(ds.features.keys()))
print('Episodes:', ds.num_episodes)
print('Frames:', ds.num_frames)
print('FPS:', ds.fps)
"
```

---

## Step 8 — Resume Recording (adding more episodes)

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --teleop.type=so101_leader \
    --teleop.port=$LERO_LEADER_PORT \
    --teleop.id=my_awesome_leader_arm \
    --dataset.repo_id=${HF_USER}/so101_pick_block \
    --dataset.single_task="$TASK_DESC" \
    --dataset.num_episodes=25 \
    --resume=true
```

---

## Dataset Location

Datasets are stored locally at:
```
~/.cache/huggingface/lerobot/<HF_USER>/<dataset_name>/
  meta/info.json        # feature schema, fps, episode count
  meta/stats.json       # per-feature normalization stats
  data/chunk-000.parquet  # tabular frames (state, action, timestamps)
  videos/               # MP4 files per camera per chunk
```

---

## Next Step

See `TRAINING_ARCHITECTURE.md` for how to train a policy on your recorded dataset.
