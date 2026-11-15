function trainComparison()
% Optional convenience command to train both. Use trainTD3/trainDDPG separately.
cfg = teamConfig();
validateProject();
for algorithm = ["TD3", "DDPG"]
    trainTrackingAgent(algorithm, cfg);
end
plotLearningCurves(cfg);
end
