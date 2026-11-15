# Requirement traceability

Sources: parent assignment PDF (3 pages) and unchanged reference starter in
`docs/reference/panda_rl_starter_code.m`. The skeleton is deliberately not executable.

| Requirement | Implementation / evidence |
| --- | --- |
| Robot, visualisation, frame, home/start FK | main.m and robot/testForwardKinematics.m |
| Fixed settings and seeds | teamConfig.m |
| Observation/action/reward/reset/termination justification | README.md, MovingTargetTrackingEnv.m |
| State carried in LoggedSignals | createTrackingEnvironment.m |
| Validate before training and retain evidence | validateProject.m, tests, validation CSV/MAT |
| Progressive training after stability | environment curriculum and saved stage CSV/configuration |
| Two RL methods, equal reward/budget/seeds/network sizes | makeAgent.m; independent trainTD3.m/trainDDPG.m using trainTrackingAgent.m |
| Policy/critic/exploration/update-rule formulation | README.md; empirical discussion still required |
| Conventional IK with same clipped increments | ikController.m and shared episode runner |
| 30 unseen shared cases, frozen policies | evaluateComparison.m and saved evaluation_cases.mat |
| Required metrics, every trial, mean/std, times, hardware | comparison per-case/summary CSVs and MAT |
| Learning stability, RL/IK success/failure explanation | trainingStats and traces; analysis pending full runs |

Implementation alone is not proof of performance. Complete full budget-matched training,
final evaluation, plots and an evidence-based report. A curriculum that does not reach
the full task must be reported as such. Do not tune settings using final evaluation.
