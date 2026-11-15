# TD3 review at 30,028 environment steps - October 27, 2026

This review describes an earlier run that was subsequently stopped at 48,963
logged steps. See [the calibration report](CALIBRATION_REPORT.md) for the current setup.

This is a training/curriculum diagnostic, not final unseen-case evaluation.
The checkpoint is the first completed episode crossing 30,000 steps: episode 107,
30,028/300,000 steps, curriculum stage 1 (stationary targets). It is not an exact
30,000-step saved model. Full training continues; the final agent is saved at completion.

| Training window | Successes | Constraint failures | Mean per-episode tracking error | Mean episode steps |
| --- | --- | --- | --- | --- |
| First 10 episodes | 1/10 | 0/10 | 2.636 cm | 400 |
| Last 20 at checkpoint | 0/20 | 20/20 | 29.768 cm | 289.55 |

The last 20 failures comprised 19 joint-limit violations and one self-collision.
Only one episode had succeeded in the whole run through the checkpoint. The
stability requirement for curriculum promotion was not met, so staying in stage 1
is correct. All error means here average the per-episode means over valid observed
steps, including episodes that later failed; they are not final-window accuracy.

## Training-only environment and exploration diagnostic

`diagnoseTrainingStart` uses validation seed 6029 and five sampled stationary cases.
These are not final evaluation cases. The initialized actors output zero, as checked
by the existing test suite. The diagnostic compares that initial behavior, without
learning, against the same behavior with configured Gaussian exploration.

- Initial zero actor: 5/5 successes, 400 steps in every case, no constraint violations.
- Initial zero actor with noise: 1/5 successes, 400 steps in every case, no violations.
- Noisy-case mean tracking errors ranged from 1.016 to 2.389 cm.

This is an intentionally easy sanity check: stationary targets begin 1-2 cm from
the hand, so a zero-action policy should already satisfy tolerance. It is not evidence
that the policy solves moving-target tracking. The limited sample shows that the
reset/step/scoring path and initial exploration do not by themselves reproduce the
large constraint-failing drift seen in the learned run.

Evidence is retained in `results/diagnostics/training_start_diagnostic.csv` and
`.mat`, `results/diagnostics/logs/training_start_diagnostic.log`,
`results/diagnostics/td3_30000_progress_snapshot.csv`, and
`results/diagnostics/early_training/td3_training_v2.log`. The corresponding
episode history is `results/diagnostics/td3_v2_aborted_progress.csv`.

## Diagnosis and limits

The measured problem is learning instability/policy regression, not the progress
display or the episode/step budget. Learned-policy behavior is much worse than the
initial-policy diagnostic on this stationary stage. This supports investigating
actor/critic updates; it does not prove one optimizer parameter caused the regression.
No intermediate learned weights or critic gradients were saved at this checkpoint,
so direct analysis of those values is not available yet.

One confirmed configuration detail is that the run inherits `LearningFrequency=-1`
and `MaxMiniBatchPerEpoch=100`. MATLAB therefore learns in episode-end batches;
learning work per environment step can change when episodes get shorter. These
defaults are documented in [MathWorks TD3 options](https://www.mathworks.com/help/reinforcement-learning/ref/rl.option.rltd3agentoptions.html).
They are supported behavior, not a MATLAB defect. A controlled follow-up should
explicitly set learning frequency/update counts and compare more conservative actor
and critic updates, holding reward, cases, seed and diagnostic budget fixed. Change
one factor at a time; do not claim this suggestion is a demonstrated fix.

The bounded reward tests still pass. They remove the earlier unbounded-cost incentive
but cannot guarantee an accurate learned critic or convergence. The two 128-unit
hidden layers and configured 300,000-step budget have not been changed.

No hyperparameters were changed during this run, and it was left running after the
review. DDPG full training and final unseen-case evaluation have not been started.
Before comparing algorithms, settle the learning setup on training/validation data;
report diagnostic runs separately and keep final cases reserved.
