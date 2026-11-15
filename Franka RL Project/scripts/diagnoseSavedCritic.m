function result = diagnoseSavedCritic(checkpointPath, outputDir)
% Compare learned critic estimates with actual frozen-policy discounted returns.
saved = load(checkpointPath);
cfg = saved.cfg;
actor = getActor(saved.agent);
critics = getCritic(saved.agent);
previousRng = rng;
restoreRng = onCleanup(@() rng(previousRng));
[~, model] = createTrackingEnvironment(cfg);
model.maxTargetSpeed = 0;
rows = cell(5, 1);
for caseIndex = 1:5
    rng(cfg.validationSeed + 100 + caseIndex, "twister");
    reset(model);
    taskCase = struct("q", model.q, "targetStart", model.targetStart, ...
        "targetVelocity", model.targetVelocity);
    obs = model.getObservation();
    action = policy(obs, model);
    q1 = double(getValue(critics(1), {obs}, {action}));
    q2 = double(getValue(critics(2), {obs}, {action}));
    [metrics, trace] = runControllerEpisode(model, taskCase, @policy);
    discountedReturn = sum((cfg.discountFactor.^(0:numel(trace.rewards)-1)).' .* trace.rewards);
    rows{caseIndex} = struct("Case", caseIndex, "Q1", q1, "Q2", q2, ...
        "ActualDiscountedReturn", discountedReturn, ...
        "Optimism", min(q1, q2) - discountedReturn, ...
        "InitialMaxAction", max(abs(action)), ...
        "MeanTrackingError_M", metrics.MeanTrackingError_M, "Success", metrics.Success);
end
result = struct2table(vertcat(rows{:}));
if ~isfolder(outputDir), mkdir(outputDir); end
writetable(result, fullfile(outputDir, "critic_diagnostic.csv"));
disp(result);
    function action = policy(obs, ~)
        values = getAction(actor, {obs});
        action = values{1}(:);
    end
end
