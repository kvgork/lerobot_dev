# Training Architecture Plan — SO-101 LeRobot

Policy training plan for SO-101 tabletop manipulation tasks.

---

## Policy Selection Guide

| Policy | Use When | Episodes Needed | Training Time (RTX 3090) |
|--------|----------|-----------------|--------------------------|
| **ACT** | First attempt, pick-and-place, precise motions | 20–50 | ~1.5–3 hours |
| **Diffusion** | Multiple valid paths, ACT overfits | 50–100 | ~3–6 hours |
| **pi0 / pi0_fast** | Few demos (<30), large pretrained prior | 10–30 | Variable |
| **SmolVLA** | Language-conditioned multi-task | 50–100 | Variable |

**Start with ACT.** It has the fewest hyperparameters to tune and works well for SO-101 single-task manipulation.

---

## Recommended Training Workflow

### 1. Train ACT (first model)

```bash
export HF_USER=$(NO_COLOR=1 hf auth whoami | awk -F': *' 'NR==1 {print $2}')
export DATASET=so101_pick_block
export RUN_NAME=act_so101_pick_block

lerobot-train \
    --dataset.repo_id=${HF_USER}/${DATASET} \
    --policy.type=act \
    --policy.device=cuda \
    --batch_size=8 \
    --steps=100000 \
    --save_freq=20000 \
    --log_freq=200 \
    --wandb.enable=true \
    --wandb.project=lerobot_so101 \
    --output_dir=outputs/train/${RUN_NAME} \
    --job_name=${RUN_NAME} \
    --policy.repo_id=${HF_USER}/${RUN_NAME}
```

The `--policy.repo_id` flag pushes the final checkpoint to HuggingFace Hub.

### 2. Resume a training run

```bash
lerobot-train \
    --dataset.repo_id=${HF_USER}/${DATASET} \
    --policy.type=act \
    --policy.device=cuda \
    --output_dir=outputs/train/${RUN_NAME} \
    --resume=true
```

### 3. Train Diffusion (if ACT overfits or task is multi-modal)

```bash
lerobot-train \
    --dataset.repo_id=${HF_USER}/${DATASET} \
    --policy.type=diffusion \
    --policy.device=cuda \
    --batch_size=64 \
    --steps=100000 \
    --output_dir=outputs/train/diffusion_so101 \
    --wandb.enable=true
```

### 4. Fine-tune from a pretrained checkpoint

```bash
lerobot-train \
    --dataset.repo_id=${HF_USER}/so101_new_task \
    --policy.path=outputs/train/act_so101_pick_block/checkpoints/last \
    --policy.device=cuda \
    --output_dir=outputs/train/act_so101_new_task_finetuned \
    --optimizer.lr=1e-6
```

---

## ACT Architecture for SO-101

ACT (Action Chunking with Transformers) is the reference architecture for SO-101.

### Feature Configuration

```python
from lerobot.configs.types import FeatureType, NormalizationMode, PolicyFeature
from lerobot.policies.act.configuration_act import ACTConfig

# 1 camera (RGB only)
config = ACTConfig(
    n_obs_steps=1,          # MUST be 1 — ACT constraint
    chunk_size=100,         # Actions predicted per forward pass
    n_action_steps=100,     # Actions executed before re-querying (must be <= chunk_size)

    input_features={
        "observation.state": PolicyFeature(
            type=FeatureType.STATE,
            shape=(6,),     # [shoulder_pan, shoulder_lift, elbow_flex, wrist_flex, wrist_roll, gripper]
        ),
        "observation.images.front": PolicyFeature(
            type=FeatureType.VISUAL,
            shape=(3, 480, 640),  # CHW format
        ),
    },
    output_features={
        "action": PolicyFeature(
            type=FeatureType.ACTION,
            shape=(6,),     # 6-DoF joint positions in degrees
        ),
    },
    normalization_mapping={
        "VISUAL": NormalizationMode.MEAN_STD,
        "STATE":  NormalizationMode.MEAN_STD,
        "ACTION": NormalizationMode.MEAN_STD,
    },
)
```

For two cameras (front + wrist):
```python
input_features={
    "observation.state": PolicyFeature(type=FeatureType.STATE, shape=(6,)),
    "observation.images.front": PolicyFeature(type=FeatureType.VISUAL, shape=(3, 480, 640)),
    "observation.images.wrist": PolicyFeature(type=FeatureType.VISUAL, shape=(3, 480, 640)),
},
```

### Key ACT Constraints (enforced in `__post_init__`)

- `n_obs_steps` MUST equal 1 (hard error otherwise)
- `n_action_steps` must be `<= chunk_size`
- `temporal_ensemble_coeff` only valid when `n_action_steps == 1`

### ACT Architecture Defaults (no need to change for SO-101)

| Parameter | Default | Notes |
|-----------|---------|-------|
| `vision_backbone` | `resnet18` | Pre-trained on ImageNet |
| `dim_model` | 512 | Transformer hidden dim |
| `n_heads` | 8 | Attention heads |
| `dim_feedforward` | 3200 | FFN hidden dim |
| `n_encoder_layers` | 4 | Encoder depth |
| `n_decoder_layers` | 1 | Decoder depth |
| `use_vae` | True | Action VAE |
| `latent_dim` | 32 | VAE latent size |
| `kl_weight` | 10.0 | KL loss weight; reduce to 1.0 if unstable |
| `optimizer_lr` | 1e-5 | AdamW LR |
| `optimizer_weight_decay` | 1e-4 | Weight decay |

---

## Diffusion Policy Architecture for SO-101

Use Diffusion when ACT overfits or when there are multiple valid ways to complete the task.

```python
from lerobot.policies.diffusion.configuration_diffusion import DiffusionConfig
from lerobot.configs.types import FeatureType, NormalizationMode, PolicyFeature

config = DiffusionConfig(
    n_obs_steps=2,          # Diffusion supports multi-step observations
    horizon=16,             # Prediction horizon (must be divisible by 8 with default down_dims)
    n_action_steps=8,       # Actions executed per inference

    input_features={
        "observation.state": PolicyFeature(type=FeatureType.STATE, shape=(6,)),
        "observation.images.front": PolicyFeature(type=FeatureType.VISUAL, shape=(3, 480, 640)),
    },
    output_features={
        "action": PolicyFeature(type=FeatureType.ACTION, shape=(6,)),
    },
    normalization_mapping={
        "VISUAL": NormalizationMode.MEAN_STD,
        "STATE":  NormalizationMode.MIN_MAX,    # Diffusion default differs from ACT
        "ACTION": NormalizationMode.MIN_MAX,
    },

    num_train_timesteps=100,
    num_inference_steps=10,   # Reduce for faster real-time deployment
    optimizer_lr=1e-4,
)
```

**Diffusion constraint**: `horizon % 8 == 0` with default `down_dims=(512, 1024, 2048)`.

---

## Training Health Indicators

A healthy ACT run:
- Reconstruction loss drops steadily in the first 5,000 steps
- KL loss settles to a small positive value
- If KL loss dominates: reduce `kl_weight` from 10.0 to 1.0
- If loss plateaus above 0.5 after 20k steps: check normalization and dataset quality

### Checkpoint Structure

```
outputs/train/act_so101_pick_block/
  checkpoints/
    last/                       # Most recent checkpoint (always kept)
    020000/pretrained_model/    # Checkpoint at step 20,000
    040000/pretrained_model/
    ...
  train_stats.jsonl             # Per-step training metrics
```

---

## Evaluation / Deployment

### Deploy on hardware (direct Feetech path)

In LeRobot v0.4.4, deployment uses `lerobot-record` without teleop flags.

```bash
lerobot-record \
    --robot.type=so101_follower \
    --robot.port=$LERO_FOLLOWER_PORT \
    --robot.id=my_awesome_follower_arm \
    --robot.cameras='{"front": {"type": "intelrealsense", "serial_number_or_name": "'$LERO_CAM_SERIAL'", "fps": 30, "width": 640, "height": 480}}' \
    --robot.max_relative_target=5.0 \
    --display_data=true \
    --dataset.repo_id=${HF_USER}/eval_so101_pick_block \
    --dataset.num_episodes=20 \
    --dataset.single_task="Pick up the red block and place it in the bin" \
    --policy.path=outputs/train/act_so101_pick_block/checkpoints/last
```

`--robot.max_relative_target=5.0` limits per-step motor travel to 5 degrees — use for first deployments.

### Safety checklist before first deployment

- [ ] Arm is bolted down or clamped
- [ ] Workspace clear of people and fragile objects
- [ ] Run `lerobot-replay` on episode 0 first to verify hardware works
- [ ] Set `--robot.max_relative_target=5.0`
- [ ] Keep one hand on USB cable / power switch
- [ ] Verify `Ctrl+C` stops the arm before a full run

---

## Recommended Training Architecture Progression

```
Phase 1 — Data Collection
  50 episodes × ACT → baseline model
  Camera: RealSense D435 RGB, 640×480 @ 30fps
  Task: single, well-defined pick-and-place

Phase 2 — Baseline Training
  Policy: ACT (chunk_size=100, n_action_steps=100)
  Steps: 100k, batch_size=8
  Target: >70% success rate on training task

Phase 3 — Iteration
  If ACT overfits (>90% train, <50% eval):
    → Collect 50 more diverse episodes
    → Try Diffusion policy
  If success rate is 50–70%:
    → Check calibration, improve episode consistency
    → Add wrist camera for better grasp observation
  If success rate is >70%:
    → Expand to multi-task (new dataset, SmolVLA)

Phase 4 — Multi-task (optional)
  Add language conditioning with SmolVLA
  Collect 50+ episodes per task variant
  Use HuggingFace Hub for dataset versioning
```

---

## Important Notes on Joint Units

`use_degrees=True` is the default for SO-101. All joint positions are in **degrees** (not radians). This must be consistent between recording and training — never mix degree and radian datasets.

Motor key names (direct hardware path):
```
shoulder_pan.pos   → action[0]
shoulder_lift.pos  → action[1]
elbow_flex.pos     → action[2]
wrist_flex.pos     → action[3]
wrist_roll.pos     → action[4]
gripper.pos        → action[5]  (range 0–100)
```

---

## References

- `DATASET_RECORDING_GUIDE.md` — how to collect data
- `HANDY_COMMANDS.md` — quick command reference
- LeRobot docs: https://huggingface.co/docs/lerobot/index
- ACT paper: https://arxiv.org/abs/2304.13705
