# Training readiness calibration - October 27, 2026

The project is ready to start fresh full-budget training with the calibrated
configuration in `teamConfig.m`. This report establishes implementation and pilot
readiness, not final assignment results. No full 300,000-step v3 run or reserved
30-case final evaluation has been completed.

## Confirmed fixes

- Progress is displayed against environment steps, with percentage, episode length,
  curriculum stage, tracking error, termination reason and success. The misleading
  `Episode n/300000` display is disabled.
- `TotalAgentSteps` is a per-episode history after multiple episodes. Final save and
  evaluation guards now use its last element. A regression test trains three
  episodes and verifies final-model and rolling-checkpoint save/load.
- One rolling checkpoint per algorithm retains recent policy snapshots for diagnosis.
  These snapshots are not completed-budget models or an exact-resume guarantee.
- Observation/error and critic-action scaling, zero-output initialization, bounded
  reward and explicit update scheduling replace the unstable initial setup.

## Selected shared configuration

Two 128-unit ReLU hidden layers per actor/critic; actor and critic output layers
initialized at zero; relative error scaled by the 0.02 m tolerance; actions bounded
by the unchanged 0.01 rad starter limit. Both methods use discount 0.95, progress
weight 20, failure penalty 250, batch size 256, warm start 3000, one mini-batch per
environment step, actor LR 1e-5, critic LR 3e-4, and gradient threshold 1.
TD3 delays actor updates by 10 critic updates; DDPG updates its actor every update.
Both explore with the same Gaussian noise settings. One computational thread is
used, matching calibration; the previous MATLAB thread limit is restored on exit.

The unchanged formal settings remain dt=0.05 s, 400 steps per episode, workspace from
the starter, 2 cm tolerance over every sample of the final five seconds, and exactly
300,000 environment steps per algorithm. Formal curriculum minimums remain
[30000, 60000, 0], a 20-episode window and 80% success for promotion.

## Experiments and acceptance evidence

The initial long-horizon run regressed and was stopped after its last logged 48,963
steps. Diagnostic calibration budgets were kept separate from formal comparisons.
The first conservative 12,000-step run exposed the save bug; its model was not saved.
The progress log was retained, and the save bug was fixed before later runs.

| Candidate | Diagnostic steps | Frozen successes: stationary / slow / full-speed cap | Outcome |
| --- | --- | --- | --- |
| Stronger progress, long horizon | 12,000 | 0/5 / 0/5 / 0/5 | Rejected |
| Slower actor, long horizon | 12,000 | 0/5 / 0/5 / 0/5 | Reduced drift, still rejected |
| Negative critic prior, long horizon | 12,000 | 0/5 / 0/5 / 0/5 | Rejected; constraint failures |
| Short horizon, tolerance-scaled error, zero critic outputs | 12,000 | 5/5 / 5/5 / 3/5 | Promising; proceeded to curriculum pilot |
| Same TD3 configuration through curriculum pilot | 24,000 | 5/5 / 5/5 / 5/5 | Accepted for full-run readiness |
| DDPG with the same shared configuration | 12,000 | 5/5 / 5/5 / 5/5 | Accepted for full-run readiness |

These are configuration packages, not a complete factorial study; the experiments
do not isolate a single causal parameter. Saved critic diagnostics showed large
overestimation in a rejected candidate (predictions near -6 versus observed returns
around -51 to -59). The selected package produced useful tracking instead of merely
preventing motion. Neither pilot is a fair final TD3-versus-DDPG comparison because
their budgets/curriculum schedules differ.

TD3's diagnostic curriculum used shortened stage minimums [4000,6000,0] and a
10-episode window, retaining the 80% promotion requirement and strict task success.
It promoted to slow targets at step 9200 and full-speed targets at step 15200,
completed 24,000 steps, and succeeded in its last 20 episodes. Shortened stage
minimums were diagnostic only and have NOT replaced the formal settings.
DDPG had two early joint-limit failures during learning, then recovered. Its final
frozen-policy validation had no violations. Early learning failures remain recorded.

## Fresh maximum-speed validation

A second validation seed (16029, distinct from training and final evaluation) was
used after selecting the configuration. Five cases per stage were generated, with
moving targets forced to exactly 0.003 or 0.01 m/s and path endpoints checked inside
the workspace. Both frozen policies passed all 15 cases, with zero joint-limit or
self-collision violations. All successes require a complete episode and <=2 cm at
every final-window sample.

| Frozen pilot | Stationary | Exactly 0.003 m/s | Exactly 0.01 m/s | Mean final-window error at 0.01 m/s |
| --- | --- | --- | --- | --- |
| TD3 | 5/5 | 5/5 | 5/5 | 4.53 mm |
| DDPG | 5/5 | 5/5 | 5/5 | 7.92 mm |

Across all 15 fresh cases, the worst final-window sample was 6.922 mm for TD3
and 13.407 mm for DDPG, both below the 20 mm threshold. Saved artifact verification
also confirmed each pilot's exact step budget and that reserved final cases were absent;
see `results/diagnostics/logs/readiness_artifact_verification.log`.

These are small validation samples for readiness, not final performance estimates,
across-seed robustness claims or a ranking of the algorithms. The reserved final
evaluation seed 918273645 and its cases have not been used for tuning or these checks.

## Evidence and remaining work

- `results/validation/calibrated_v3_final_checks.log`, `validation.csv`, `validation.mat`:
  all 20 regression tests passed, and active-code analysis reported zero issues.
- `results/diagnostics/td3_curriculum_pilot_e/`: saved TD3 pilot, curriculum log,
  episode progress, normal validation and `independent_max_speed_holdout/`.
- `results/diagnostics/ddpg_v3_pilot/`: equivalent DDPG artifacts and fresh holdout.
- Each validation MAT file retains the actual cases; fresh holdout files also retain
  configuration and the exact-speed flag for reproduction.
- Rejected-candidate models and raw logs remain under `results/diagnostics`.

Start fresh full runs with `setupProject; trainTD3`, then separately `trainDDPG`.
The pilot models remain in diagnostics and must not be copied into the formal output
folder. The formal evaluation guard requires completed matching step budgets.
After both full runs finish, inspect curriculum logs, run `plotLearningCurves`, then
freeze all choices and run `evaluateComparison` once for the reserved comparison.
Complete the results-based report with every case, failures, uncertainty, timing and
hardware. Successful pilots do not guarantee a particular full-run outcome.
