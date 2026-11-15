function [casesTable, summary] = validateCalibrationPolicy(agent, cfg, outputDir, forceMaximumSpeed)
% Reusable frozen-policy calibration cases. Never uses the final evaluation seed.
previousRng = rng;
if nargin < 4, forceMaximumSpeed = false; end
restoreRng = onCleanup(@() rng(previousRng));
[~, model] = createTrackingEnvironment(cfg);
actor = getActor(agent);
speeds = [0 0.003 0.01];
rows = cell(15, 1);
taskCases = cell(3, 5);
for speedIndex = 1:numel(speeds)
    model.maxTargetSpeed = speeds(speedIndex);
    for caseIndex = 1:5
        rng(cfg.validationSeed + 100*speedIndex + caseIndex, "twister");
        valid = false;
        for attempt = 1:1000
            reset(model);
            if forceMaximumSpeed && speeds(speedIndex) > 0
                model.targetVelocity = speeds(speedIndex) * model.targetVelocity / ...
                    max(norm(model.targetVelocity), eps);
            end
            endpoint = model.targetStart + model.targetVelocity * (cfg.maxSteps * cfg.dt);
            if model.isInsideTargetWorkspace(endpoint)
                valid = true;
                break;
            end
        end
        assert(valid, "Could not sample a valid calibration path.");
        taskCase = struct("q", model.q, "targetStart", model.targetStart, ...
            "targetVelocity", model.targetVelocity);
        taskCases{speedIndex, caseIndex} = taskCase;
        [row, ~] = runControllerEpisode(model, taskCase, @policy);
        row.SpeedLimit = speeds(speedIndex);
        row.TargetSpeed = norm(taskCase.targetVelocity);
        row.Case = caseIndex;
        rows{(speedIndex-1)*5+caseIndex} = row;
    end
end
casesTable = struct2table(vertcat(rows{:}));
summaryRows = cell(3, 1);
for index = 1:numel(speeds)
    selected = casesTable(casesTable.SpeedLimit == speeds(index), :);
    summaryRows{index} = struct("SpeedLimit", speeds(index), ...
        "Successes", sum(selected.Success), "Cases", height(selected), ...
        "Violations", sum(selected.JointLimitViolation | selected.CollisionViolation), ...
        "MeanError_M", mean(selected.MeanTrackingError_M, "omitnan"), ...
        "FinalWindowMeanError_M", mean(selected.FinalWindowMeanError_M, "omitnan"));
end
summary = struct2table(vertcat(summaryRows{:}));
writetable(casesTable, fullfile(outputDir, "validation_cases.csv"));
writetable(summary, fullfile(outputDir, "validation_summary.csv"));
save(fullfile(outputDir, "validation_cases.mat"), "taskCases", "casesTable", "summary", ...
    "cfg", "forceMaximumSpeed");
disp(summary);
fprintf("Calibration-only validation, not the reserved final evaluation.\n");
    function action = policy(obs, ~)
        result = getAction(actor, {obs});
        action = result{1}(:);
    end
end
