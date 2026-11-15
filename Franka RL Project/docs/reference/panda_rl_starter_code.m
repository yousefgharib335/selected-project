%% Reinforcement Learning with the Franka Panda Robot in MATLAB - STARTER CODE
% Selected Topics in Robotics & AI, Fall 2026
%
% This file is a SKELETON. It gives you:
%   (A) the fixed numerical settings from the project brief,
%   (B) the common initial network size, which you adjust to your needs,
%   (C) the robot loading call and the end-effector frame to use,
%   (D) a list of helper functions you will probably need to build
%
% Everything else (environment, observations, rewards, success checks, training,
% evaluation, IK comparison) is YOUR work.
%
% Needs: Robotics System Toolbox, Reinforcement Learning Toolbox, Deep Learning Toolbox.

%% (A) FIXED SETTINGS  ---------------------------------------------------------
% Given here (not stated as numbers in the brief):
cfg.task         = '';                                   % your assigned task: 'obstacle' | 'waypoints' | 'path' | 'moving' | 'inspection' | 'transport'
cfg.dt           = 0.05;                                 % s, simulation time step
cfg.maxSteps     = 400;                                  % steps per episode (20 s simulated)
cfg.maxIncrement = 0.01;                                 % rad, max |joint increment| per joint per step
cfg.box          = [0.30 0.65; -0.30 0.30; 0.15 0.60];   % reachable workspace box [min max] per axis (x; y; z), m

% Copy these from the project brief (Common Simulation Requirements, Evaluation Protocol):
cfg.posTol       = ;        % m, position tolerance
cfg.oriTolDeg    = ;        % deg, orientation tolerance (where applicable)
cfg.dwellSteps   = ;        % steps corresponding to the required hold time at cfg.dt
cfg.budgetSteps  = ;        % environment steps per training run (same for every agent)
cfg.numEvalCases = ;        % unseen test cases, generated from cfg.evalSeed only

% Random seeds: choose your own two DIFFERENT integers and keep them fixed.
% A seed initialises the random number generator, so the same seed reproduces the
% same sampled cases, network initialisation and exploration. Report both seeds;
% your results must be reproducible from them.
cfg.trainSeed    = ;        % used for network initialisation, exploration and training/tuning cases (same for both RL agents)
cfg.evalSeed     = ;        % used ONLY to generate the 30 unseen evaluation cases - never for training or tuning

%% (B) COMMON INITIAL NETWORK SIZE  ------------------------- adjust to your needs
% Every team starts from the same size: two fully connected hidden layers of 128
% units (ReLU) for the actor and for each critic. This is only the starting point.
% Change the width, depth or structure if your task needs it, and document the
% change and its effect in the report. Use the same size for both algorithms you
% compare unless you explain why not.
netSize.hiddenUnits = 128;
netSize.numLayers   = 2;


%% (C) ROBOT  -------------------------------------------------------------------
robot  = loadrobot('frankaEmikaPanda', 'DataFormat', 'row');   % 7 revolute arm joints + 2 finger joints
eeName = 'panda_hand';                                          % end-effector frame for all task measurements
qReady = [0 -0.785 0 -2.356 0 1.571 0.785];                     % nominal 7-joint ready pose
gripperOpening = 0.04;                                          % fixed gripper opening (both fingers)
showdetails(robot);
% Note: the configuration vector of this model has 9 entries (7 arm + 2 fingers).
% Keep the fingers fixed at gripperOpening; the RL action only changes the 7 arm joints.

%% (D) HELPER FUNCTIONS YOU MAY NEED  -------------------------------- build these
% Write these yourself (names are suggestions). Suggested order of work:
%   1. fullConfig, forwardKinematics, checkArmCollision, drawScene
%   2. sampleTaskCase, computeErrors, checkTaskProgress
%   3. buildObservation, computeReward, envReset, envStep
%   4. validateEnvironment
%   5. makeAgent, trainAgent
%   6. evalCases, policyAction, runEpisode, episodeMetrics, evaluate
%   7. ikController
