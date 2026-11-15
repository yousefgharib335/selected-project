function [caseTable, summaryTable] = evaluateComparison(cfg)
% Run only after training/tuning is frozen. Never use these cases for tuning.
if nargin == 0, cfg = teamConfig(); end
models = cell(1, 2);
for k = 1:2
    names = ["td3", "ddpg"];
    path = fullfile(cfg.resultsDir, names(k) + "_agent.mat");
    assert(isfile(path), "Train both algorithms before final evaluation: %s", path);
    models{k} = load(path);
    assert(models{k}.trainingStats.TotalAgentSteps(end) == cfg.budgetSteps && ...
        models{k}.actualEnvironmentSteps == cfg.budgetSteps, ...
        "Saved agent did not complete the configured training budget.");
    fields = ["dt", "maxSteps", "maxIncrement", "box", "posTol", ...
        "maxTargetSpeed", "trainSeed", "evalSeed", "budgetSteps", ...
        "trackingRewardScale", "progressRewardWeight", "discountFactor", ...
        "failurePenalty", "rewardVersion", "networkVersion", "relativePositionNormalization"];
    for field = fields
        assert(isfield(models{k}.cfg, field) && isequal(models{k}.cfg.(field), cfg.(field)), ...
            "Saved training configuration differs: %s", field);
    end
end
[~, model] = createTrackingEnvironment(cfg);
caseFile = fullfile(cfg.resultsDir, "evaluation_cases.mat");
if isfile(caseFile)
    saved = load(caseFile, "cases", "caseConfig");
    assert(isequaln(saved.caseConfig, cfg), "Evaluation case configuration differs.");
    cases = saved.cases;
else
    previousRng = rng;
    restore = onCleanup(@() rng(previousRng));
    rng(cfg.evalSeed, "twister");
    cases = repmat(struct("q", [], "targetStart", [], "targetVelocity", []), cfg.numEvalCases, 1);
    for k = 1:cfg.numEvalCases
        reset(model);
        cases(k) = struct("q", model.q, "targetStart", model.targetStart, ...
            "targetVelocity", model.targetVelocity);
    end
    caseConfig = cfg;
    save(caseFile, "cases", "caseConfig");
    clear restore;
end
rows = cell(3 * cfg.numEvalCases, 1);
traces = cell(3, cfg.numEvalCases);
controllers = ["TD3", "DDPG", "IK"];
for controllerIndex = 1:3
    if controllerIndex <= 2
        frozen = getActor(models{controllerIndex}.agent);
        policy = @(obs, ~) actorAction(frozen, obs);
        trainingSeconds = models{controllerIndex}.trainingWallSeconds;
    else
        solver = inverseKinematics("RigidBodyTree", model.Robot);
        solver.SolverParameters.AllowRandomRestart = false;
        policy = @(obs, state) ikController(obs, state, solver);
        trainingSeconds = 0;
    end
    for caseIndex = 1:cfg.numEvalCases
        [row, traces{controllerIndex, caseIndex}] = ...
            runControllerEpisode(model, cases(caseIndex), policy);
        row.Controller = controllers(controllerIndex);
        row.Case = caseIndex;
        row.TrainingWallSeconds = trainingSeconds;
        row.ReachedFullCurriculum = controllerIndex == 3;
        if controllerIndex <= 2
            row.ReachedFullCurriculum = models{controllerIndex}.reachedFullTask;
        end
        rows{(controllerIndex - 1) * cfg.numEvalCases + caseIndex} = row;
    end
end
caseTable = struct2table(vertcat(rows{:}));
summaryRows = cell(3, 1);
numericFields = ["Steps", "SimulatedSeconds", "WallSeconds", "EpisodeReward", ...
    "FinalWindowMeanError_M", "FinalWindowMaxError_M", "FinalPositionError_M", ...
    "MeanTrackingError_M", "MaxTrackingError_M", "MeanJointIncrement_Rad", ...
    "MaxJointIncrement_Rad", "SumSquaredActionDifferences"];
for index = 1:numel(controllers)
    name = controllers(index);
    subset = caseTable(caseTable.Controller == name, :);
    row = struct("Controller", name, "NumCases", height(subset), ...
        "SuccessRate", mean(subset.Success), ...
        "JointLimitViolations", sum(subset.JointLimitViolation), ...
        "CollisionViolations", sum(subset.CollisionViolation), ...
        "CompleteFinalWindows", sum(subset.FinalWindowComplete), ...
        "TrainingWallSeconds", subset.TrainingWallSeconds(1));
    for field = numericFields
        row.("Mean_"+field) = mean(subset.(field), "omitnan");
        row.("Std_"+field) = std(subset.(field), "omitnan");
        row.("ValidCount_"+field) = sum(isfinite(subset.(field)));
    end
    summaryRows{index} = row;
end
summaryTable = struct2table(vertcat(summaryRows{:}));
% Rank the RL agents by success, then completed-window error. IK is kept beside both.
ranking = summaryTable(1:2, :);
ranking = sortrows(ranking, ["SuccessRate", "Mean_FinalWindowMeanError_M"], ["descend", "ascend"]);
betterRL = ranking.Controller(1);
hardware = hardwareInfo();
writetable(caseTable, fullfile(cfg.resultsDir, "comparison_cases.csv"));
writetable(summaryTable, fullfile(cfg.resultsDir, "comparison_summary.csv"));
save(fullfile(cfg.resultsDir, "comparison.mat"), "caseTable", "summaryTable", ...
    "traces", "cases", "cfg", "hardware", "betterRL");
disp(summaryTable(:, ["Controller", "SuccessRate", "Mean_FinalWindowMeanError_M", ...
    "JointLimitViolations", "CollisionViolations"]));
fprintf("Better RL agent by success then tracking accuracy: %s\n", betterRL);
end

function action = actorAction(actor, obs)
result = getAction(actor, {obs});
action = result{1}(:);
end
