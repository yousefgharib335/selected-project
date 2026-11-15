# Results

| Folder | Contents |
| --- | --- |
| `current/` | Output from the next formal run. MATLAB writes fresh validation output, training progress, checkpoints and agents here, followed by learning curves and the final comparison. Empty at the time of this reorganization. |
| [validation/](validation/) | Saved implementation checks, including the 20-test result and the robot visualization, code analysis and training smoke-test logs. |
| [diagnostics/](diagnostics/) | Calibration runs, frozen pilot policies and their validation results. Raw calibration logs are in `diagnostics/logs/`. Early TD3 console logs and a partial progress file are in `diagnostics/early_training/`. |
| [historical/](historical/) | Earlier TD3 agents and their evaluations. These used 16 observations and are incompatible with the current environment's 24 observations. |

The accepted pilot evidence is in `diagnostics/td3_curriculum_pilot_e/` and
`diagnostics/ddpg_v3_pilot/`. Each includes an independent maximum-speed validation
folder. For budgets, settings and results, see the
[calibration report](../docs/CALIBRATION_REPORT.md).
