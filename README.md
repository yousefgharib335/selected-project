# Selected Project

MCT464 Selected Topics in Robotics & AI, Fall 2026. Simulate moving-target tracking with a Franka Emika Panda and compare TD3, DDPG, and inverse kinematics.

## Run on another computer

1. Accept the owner's invitation to this private repository. Clone with GitHub Desktop or run:

   ```sh
   git clone https://github.com/yousefgharib335/selected-project.git
   ```

2. Install MATLAB R2026b with Robotics System Toolbox, Reinforcement Learning Toolbox, and Deep Learning Toolbox. Set MATLAB's Current Folder to `Franka RL Project` inside the clone.
3. Run the robot demonstration and validation:

   ```matlab
   setupProject
   main
   validateProject
   ```

MATLAB loads the Panda model from Robotics System Toolbox. All project paths are relative to the clone.

## Training and reports

Use `trainTD3` and `trainDDPG` for the full 300,000-step runs. After both finish, run `plotLearningCurves` and `evaluateComparison`. New MATLAB results are saved locally in `Franka RL Project/results/current`, which Git ignores. Saved calibration and validation records are included for reference.

- [MATLAB project guide](Franka%20RL%20Project/README.md)
- [Progress 1 report](Progress_1_Franka_Panda_Final_Progress2.pdf)
- [Assignment brief](RL%20Franka%20Panda%20Project%20Description.pdf)
- [Progress milestones](Progress.pdf)
