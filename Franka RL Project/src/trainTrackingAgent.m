function [agent, trainingStats] = trainTrackingAgent(algorithm, cfg)
% Shared single-agent training implementation; callers validate before training.
algorithm = upper(string(algorithm));
assert(isscalar(algorithm) && any(algorithm == ["TD3", "DDPG"]), ...
    "Choose TD3 or DDPG.");
if ~isfolder(cfg.resultsDir), mkdir(cfg.resultsDir); end
destination = fullfile(cfg.resultsDir, lower(algorithm) + "_agent.mat");
assert(~isfile(destination), "Refusing to overwrite an existing trained agent: %s", destination);
previousThreads = maxNumCompThreads(cfg.numComputeThreads);
restoreThreads = onCleanup(@() maxNumCompThreads(previousThreads));
rng(cfg.trainSeed, "twister");
[env, model] = createTrackingEnvironment(cfg);
agent = makeAgent(algorithm, env, cfg);
% rlFunctionEnv validation has already run; start the counted run here.
model.setStepBudget(cfg.budgetSteps);
model.configureCurriculum(cfg);
progressReporter = makeTrainingProgressReporter(algorithm, model, cfg, agent);
options = rlTrainingOptions("MaxEpisodes", cfg.budgetSteps, ...
    "MaxStepsPerEpisode", cfg.maxSteps, "StopTrainingCriteria", "Custom", ...
    "StopTrainingValue", progressReporter, "SaveAgentCriteria", "none", ...
    "Verbose", false, "Plots", "none", "UseParallel", false, ...
    "SimulationStorageType", "none");
hardware = hardwareInfo();
timer = tic;
trainingStats = train(agent, env, options);
trainingWallSeconds = toc(timer);
actualEnvironmentSteps = model.totalStepCount;
actualAgentSteps = double(trainingStats.TotalAgentSteps(end));
assert(actualAgentSteps == cfg.budgetSteps && ...
    model.totalStepCount == cfg.budgetSteps, "Training budget mismatch.");
curriculumHistory = model.curriculumHistory;
reachedFullTask = model.curriculumStage == numel(cfg.curriculumSpeeds);
save(destination, "agent", "trainingStats", "cfg", "algorithm", "hardware", ...
    "trainingWallSeconds", "curriculumHistory", "reachedFullTask", ...
    "actualEnvironmentSteps", "actualAgentSteps", "-v7.3");
writetable(struct2table(curriculumHistory), ...
    fullfile(cfg.resultsDir, lower(algorithm) + "_curriculum.csv"));
fprintf("Saved %s agent and statistics to %s\n", algorithm, destination);
if ~reachedFullTask
    warning("%s did not reach the full curriculum. Report this as a training failure.", algorithm);
end
end
