# Validation - October 27, 2026

Independent training follow-up: `trainTD3` and `trainDDPG` now call a shared
single-agent trainer after validation. Separate six-step TD3 and DDPG smoke runs
verified exact budgets, separate saved files, and refusal to overwrite an existing
agent. Code analysis passed for all four training files. Temporary test models were
removed; `results/validation/split_training_validation.log` retains the evidence.
The curriculum warnings in this log are expected for deliberately six-step runs.

MATLAB R2026b: **20 tests passed, zero failures/incomplete tests** with the calibrated
v3 configuration. New checks cover the bounded reward/failure-cost
relationship, normalized action-change reward, zero-action actor initialization,
exact-budget custom reporting for both TD3/DDPG, reward preference for movement
toward the target, and multi-episode model/checkpoint save/load. MATLAB code
analysis (`checkcode -id`) reported no issues in active `.m` files. The unchanged
reference skeleton is excluded because its assignment placeholders are intentional.

Evidence: `results/validation/validation.csv`, `validation.mat` and
`calibrated_v3_final_checks.log`. Earlier `verification_final.log` describes the
previous 15-test implementation. The robot visualisation/FK demonstration also passed:
both figures were created and the task-start transform was finite. Its output is
retained in `results/validation/robot_demo.log`.

Collision follow-up: the imported model home pose is self-colliding under the
same checks as training: panda_link5 with panda_link7, panda_hand and
panda_rightfinger. This is a home-FK demonstration only. The seeded task-start
pose and the starter ready pose both pass. `main` now prints collision status
and pairs, and asserts the task start is valid. Figure 1 was subsequently changed
to the collision-free starter ready pose, with an explicit validity assertion;
the default model home FK is retained as a console-only reference. Figure 2
continues to show the validated task start. Both plots use tighter viewing limits.
The earlier robot smoke check verified figures/FK, not home collision freedom.

Coverage: valid/repeatable reset, bounded actions, joint/self-collision failures,
reward calculation, full-window success, exact environment/training budgets,
shared configuration, LoggedSignals adapter, both TD3/DDPG network construction
and gradient-update smoke runs, stability-gated curriculum promotion, partial-window
failure regression, episode metrics, clipped IK, all-controller evaluation/export,
case reuse, repeatable scoring, and learning-curve/stability exports.

The exporter test uses two temporary validation-only cases, short episodes and
synthetic untrained model artifacts. Any controller scores printed in this test
log are fixture diagnostics, NOT project performance results. The reserved final
evaluation seed and its cases were not used for these tests.

Full 300,000-step runs per method and the final 30-case comparison remain unexecuted.
See `CALIBRATION_REPORT.md` for completed learning pilots and fresh maximum-speed
validation. Both selected pilot policies passed two separate 15-case validation sets,
including exact-maximum-speed cases; none are the reserved final evaluation set.
Their learned quality, curriculum progression and training time remain unproven.
MATLAB was run outside the sandbox because startup inside the sandbox failed with
a filesystem-inconsistency error. This was an execution-environment issue.
