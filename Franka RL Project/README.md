# Franka Panda moving-target tracking

Needs MATLAB R2026b, Robotics System Toolbox, Reinforcement Learning Toolbox and
Deep Learning Toolbox. From this folder:

```matlab
setupProject
main                 % visualisation and home/start forward kinematics
validateProject      % tests and saved validation evidence
trainTD3             % validate, then train ONLY TD3 for 300,000 steps
trainDDPG            % validate, then train ONLY DDPG for 300,000 steps
plotLearningCurves   % run after BOTH agents exist; reward curves and stability CSV
evaluateComparison   % final frozen policies and IK on the same 30 cases
```

Full training, final evaluation, plots and the written results discussion must still
be completed before claiming learned performance or submission readiness. Training
is computationally expensive. Existing final agents are never overwritten. Archive
a completed run before starting again. Outputs are in `results/current`.
See the [results index](results/README.md) for the saved validation, pilots and earlier runs.

The v3 setup has passed learning pilots, all three TD3 curriculum stages, and fresh
maximum-speed validation for both methods. See `docs/CALIBRATION_REPORT.md` for
settings, rejected experiments, evidence and limits. Pilot models remain under
`results/diagnostics`; full runs start fresh and save separately to `results/current`.

`trainTD3` and `trainDDPG` are independent: run either first, and run the other
later. Each saves its own agent and curriculum CSV. Both use the shared settings
in `teamConfig.m`. `trainComparison` remains an optional command to train both
sequentially and then plot them. Single-agent commands return `[agent, trainingStats]`
when outputs are requested and do not require the other agent to exist.

## Settings and formulation

`teamConfig.m` copies the starter/PDF settings: dt=0.05 s, 400 steps (20 s),
seven joint increments bounded by 0.01 rad, workspace x=[0.30,0.65], y=[-0.30,0.30],
z=[0.15,0.60] m, 2 cm position tolerance, target speed <=0.01 m/s. Targets follow a
straight line at constant velocity. Success requires all 400 valid steps, no constraint
violation, and every tracking error in the final 100 steps (five seconds) <=2 cm.
Orientation/dwell requirements do not apply to moving-target tracking. Measurements
use `panda_hand`. Both fingers stay at 0.04 m; simulation is kinematic.

Figure 1 displays the collision-free starter ready pose; Figure 2 displays a
validated sampled task start. Both are checked for collision and joint limits
before display. The imported model's default home pose self-collides, so its
forward-kinematics results and colliding pairs are printed only in the Command
Window for the required home-FK reference. It is not displayed or used as a reset.

The 24 observations are joint angles (7), target position (3), target velocity (3),
target-minus-hand position (3), previous joint increment (7), and remaining episode
fraction (1). Previous action makes the smoothness reward observable; remaining time
represents the finite horizon. Historical 16-input agents are incompatible.

Reward version `bounded-progress-short-horizon-v3`: let `c=(50*error)/(1+50*error)`.
Reward is `-c - 0.01*sum(((action-previousAction)/0.01).^2)` plus
`20*(previousCost-0.95*c)` and a 0.01 penalty near a joint limit (within 0.1 rad).
A joint-limit or self-collision violation yields -250 and terminates as a failure.
Tracking cost stays below 1 and normalized action-change cost is at most 0.28.
At discount 0.95, a conservative bound on the magnitude of the entire future valid
cost is 45.8, below the 250 failure penalty. This removes the earlier incentive to
terminate rather than accumulate unbounded negative tracking rewards. The smooth
bounded tracking cost remains monotonic in error. Both methods use this same reward.
Unsafe proposals are rejected and recorded applied increments are zero. Clipping
enforces the increment bound; it does not solve the task for the RL agent.

Reset samples collision-free poses near the starter ready pose, targets offset 1-2 cm,
and path endpoints inside the workspace. Convexity of the box keeps the whole straight
segment inside it. This validates a local region but does not prove every path has
a feasible joint trajectory; failures must be retained. Collision exclusions cover
connected/overlapping model meshes; other body pairs are checked at every step.
`createTrackingEnvironment` uses `rlFunctionEnv`, passing the task-state object and
diagnostics through `LoggedSignals` in its step/reset callbacks.

## Methods and progressive training

Both methods use training seed 2029, identical task/reward, two 128-unit ReLU hidden
layers per actor/critic, and exactly 300,000 cumulative steps including failed steps.
Validation uses seed 6029. Reserved final evaluation seed: 918273645. The previous
evaluation seed was used by old tests, so it is not reused for the final comparison.
No IK or planning runs in either RL learning loop.

TD3 and DDPG are off-policy deterministic actor-critic methods for continuous actions.
Both fit bootstrapped critic targets from replay and update their actors using
deterministic policy gradients through the critic. DDPG has one critic and updates
the actor at every update. TD3 uses twin critics, the minimum target Q, target-policy
smoothing, actor updates every 10 critic updates and target updates every two updates.
Both learn every environment step with one mini-batch per update after 3000 warm-up
steps, using batch size 256, actor learning rate 1e-5, critic learning rate 3e-4 and
gradient clipping at 1. Both explore with Gaussian
noise: standard deviation 0.001 rad, floor 0.0002 rad, decay 1e-5. TD3 target noise is
0.001 rad clipped to +/-0.002 rad. These algorithmic differences permit investigating
overestimation and learning stability; any observed advantage needs completed runs.

Training uses one computational thread to match the calibration execution mode;
the previous MATLAB thread limit is restored when the training function exits.
The active count is recorded with the hardware metadata. The discount factor 0.95
was selected on calibration cases to learn near-term tracking corrections without
the large critic estimation lag observed with the earlier 0.99 configuration.
All starter-fixed simulation values and the formal 300,000-step budget are unchanged.

Network version `tolerance-scaled-zero-outputs-v3` scales observations using fixed physical
ranges in both actors and critics. Critics also divide joint actions by 0.01 so tiny
radian inputs are not overwhelmed by larger observation values. Relative position is
scaled by the 2 cm task tolerance. Actor and critic output weights and biases start
at zero, preventing a randomly initialized policy from applying a
persistent large joint drift before learning. Hidden layers remain randomly initialized,
with two 128-unit ReLU layers; no controller or IK is embedded in the actor.

Training progress now prints `steps current/300000 (percent)`, followed by episode
number, episode length out of 400, curriculum stage, reward, mean error, termination
reason and success. The old `Episode: n/300000` output is disabled. A supported custom
stop callback reports progress and stops on the same exact step budget. Per-episode
diagnostics are saved to `td3_progress.csv` or `ddpg_progress.csv`. Improved total
reward from shorter failed episodes must not be presented as improved tracking.

One rolling `<algorithm>_checkpoint.mat` is saved about every 5,000 steps, at
episode boundaries, separately from the completed `<algorithm>_agent.mat`.
Checkpoints retain the policy, configuration, step count, RNG state and curriculum
history for diagnosis; they are not completed-budget models for final evaluation.
The final budget check reads the last cumulative step count from MATLAB's
per-episode statistics history. A multi-episode save/load test covers this path.

Curriculum stages: stationary targets, <=0.003 m/s, then <=0.01 m/s. Promotion requires
at least 30,000 and 60,000 stage steps respectively, and >=80% successes in the last
20 training episodes. Promotion occurs on reset. Per-method logs record stage, speed,
start step, seed and promotion success rate; other settings stay fixed. Stage durations
can differ because stability is measured independently. A run never reaching the full
task is flagged as a curriculum/training failure. Budget-truncated episodes never
count as successes. Training time, hardware, curriculum and episode statistics are saved.

## Evaluation and reporting

After both agents exist and all tuning choices are frozen, `evaluateComparison` generates
the reserved 30 cases once using only the evaluation seed, saves them, and uses them
for both frozen actors and IK. Actors run directly without exploration or learning.
The Robotics System Toolbox IK baseline targets the next moving-target position with
orientation unrestricted, clips increments to 0.01 rad, disables random solver restarts,
and uses exactly the same constraint checks and episode scoring.

Every trial, including failures, stays in the per-case table and success denominator.
Partial final windows cannot count as success. Unavailable final-window errors are NaN;
summaries give valid sample counts rather than treating missing values as zero.
Whole-episode errors cover valid observed steps, whose count is retained. Results include
final position, mean/max tracking and final-window errors, joint/collision violations,
mean/max absolute increment, and sum of squared successive action differences (including
the first change from zero). Simulated duration is attempted steps*0.05 s, separately
from training and episode wall-clock times. Summaries retain means, sample standard
deviations and valid counts. Full traces, hardware, seeds, and statistics are saved.
Both RL methods and IK remain in the output; the better RL method is ranked by success,
then final-window error for the requested RL-versus-IK comparison.

Retain learning curves and discuss their variability, failures, accuracy, smoothness,
constraints and timing in the final report. One seed-matched run per method does not
establish across-seed robustness. Never use final cases for tuning. Historical agents
and results in `results/historical` are provenance only and cannot be pooled with new runs.
See `docs/REQUIREMENTS.md` for traceability and outstanding empirical work.
