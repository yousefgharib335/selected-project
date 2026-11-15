function results = diagnoseTrainingStart()
% Training-only sanity check: stationary targets, no training or final cases.
% Compare the zero-initialized actor before learning with its exploration noise.
cfg = teamConfig();
outputDir = fullfile(cfg.projectRoot, "results", "diagnostics");
if ~isfolder(outputDir), mkdir(outputDir); end
previousRng = rng;
restoreRng = onCleanup(@() rng(previousRng));
rng(cfg.validationSeed, "twister");
[~, model] = createTrackingEnvironment(cfg);
model.maxTargetSpeed = 0;
cases = repmat(struct("q", [], "targetStart", [], "targetVelocity", []), 5, 1);
for index = 1:numel(cases)
    reset(model);
    cases(index) = struct("q", model.q, "targetStart", model.targetStart, ...
        "targetVelocity", model.targetVelocity);
end
rows = cell(2 * numel(cases), 1);
labels = ["InitialZeroActor", "InitialZeroActorWithNoise"];
for controllerIndex = 1:2
    for caseIndex = 1:numel(cases)
        rng(cfg.validationSeed + 1000 + caseIndex, "twister");
        if controllerIndex == 1
            policy = @(~, ~) zeros(7, 1);
        else
            policy = @(~, ~) cfg.explorationStd * randn(7, 1);
        end
        [row, ~] = runControllerEpisode(model, cases(caseIndex), policy);
        row.Controller = labels(controllerIndex);
        row.Case = caseIndex;
        rows{(controllerIndex - 1) * numel(cases) + caseIndex} = row;
    end
end
results = struct2table(vertcat(rows{:}));
writetable(results, fullfile(outputDir, "training_start_diagnostic.csv"));
save(fullfile(outputDir, "training_start_diagnostic.mat"), "results", "cases", "cfg");
disp(results(:, ["Controller", "Case", "Steps", "Success", ...
    "MeanTrackingError_M", "JointLimitViolation", "CollisionViolation"]));
fprintf("VALIDATION-ONLY initial-policy diagnostic; not learned-policy performance.\n");
end
