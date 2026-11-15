# Franka Panda RL handoff - October 27, 2026

The calibrated v3 project is ready to start fresh full-budget training. No formal
v3 full-budget run is active or completed. Read `Franka RL Project/README.md`,
`docs/CALIBRATION_REPORT.md`, `docs/REQUIREMENTS.md` and `docs/VALIDATION.md`.

## Run from the MATLAB project folder

```matlab
setupProject
trainTD3              % only TD3; validates first, then exactly 300000 steps
```

Run `trainDDPG` separately. After both finish, inspect curriculum logs, run
`plotLearningCurves`, freeze all choices, then run `evaluateComparison` for the
reserved final 30-case comparison. Do not use final cases for tuning.

## Accepted configuration and evidence

- Shared task/reward, two 128-unit ReLU hidden layers; starter physics unchanged.
- Gamma 0.95, bounded progress weight 20, failure penalty 250.
- Observations physically scaled, relative position in 2 cm units, critic actions
  in 0.01 rad units; actor and critic outputs initialized to zero.
- One mini-batch per environment step, batch 256, warm-up 3000, actor LR 1e-5,
  critic LR 3e-4, gradient threshold 1; TD3 actor updates every 10 critic updates.
- Training uses one computational thread and restores the prior MATLAB limit.
- Actual step-based display includes error, stage, termination reason and success.
- Final-step history indexing fixed; multi-episode final save/load tested.
- One rolling checkpoint per method every ~5000 steps. These are diagnostic policy
  snapshots, not an implemented exact-resume mechanism or full-budget evaluation models.
- All 20 regression tests passed; active MATLAB code analysis reported zero issues.
- TD3 24000-step pilot promoted through stationary/slow/full-speed stages and
  succeeded in its last 20 training episodes. Pilot stage minimums were deliberately
  shortened; formal [30000,60000,0] minimums and 20-episode window remain unchanged.
- Saved TD3 and DDPG pilot policies each passed 15 calibration cases and 15 fresh
  exact-speed cases, including five at exactly 0.01 m/s, without frozen-policy
  constraint failures. These are readiness checks, not final assignment results.
- Evidence/models are under results/diagnostics/td3_curriculum_pilot_e and
  ddpg_v3_pilot. See the [results index](Franka%20RL%20Project/results/README.md)
  for the archived logs and validation evidence.

## Important distinctions

The old unstable runs were stopped. Rejected calibrations and logs are retained;
see CALIBRATION_REPORT.md. Do not pool their statistics with formal runs or copy
short-run models into results/current. Full-budget model guards reject them.

The formal budget is 300000 environment steps per algorithm, not episodes.
Training seed 2029; calibration seed 6029; fresh validation seed 16029;
reserved final evaluation seed 918273645, not used in calibration.

Both 300000-step v3 runs, reserved final evaluation, learning plots and the final
results-based report remain outstanding. Pilot success does not guarantee a
particular full-run outcome or establish across-seed statistical robustness.

Figure 1 shows the collision-free starter ready pose; Figure 2 is a validated task
start. The imported default home self-collides and is a console-only FK reference.
Historical 16-input agents are in results/historical and cannot be used with the
current 24-input environment. The original starter reference is unchanged.
