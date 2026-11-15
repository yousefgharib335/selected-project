function summary = calibrateTD3(name, steps, settings)
% Short, separately labelled calibration runs. Full-run budget stays in teamConfig.
if nargin < 1, name = "conservative"; end
if nargin < 2, steps = 12000; end
cfg = teamConfig();
cfg.budgetSteps = steps;
cfg.learningFrequency = 1;
cfg.maxMiniBatchPerEpoch = 1;
cfg.actorLearnRate = 1e-5;
cfg.criticLearnRate = 3e-4;
cfg.gradientThreshold = 1;
cfg.warmStartSteps = 3000;
cfg.td3PolicyUpdateFrequency = 10;
if nargin >= 3
    fields = fieldnames(settings);
    for index = 1:numel(fields)
        assert(isfield(cfg, fields{index}), "Unknown calibration setting: %s", fields{index});
        cfg.(fields{index}) = settings.(fields{index});
    end
end
cfg.resultsDir = fullfile(cfg.projectRoot, "results", "diagnostics", "td3_" + name);
assert(~isfolder(cfg.resultsDir), "Preserve existing calibration results: %s", cfg.resultsDir);
[agent, ~] = trainTrackingAgent("TD3", cfg);
[~, summary] = validateCalibrationPolicy(agent, cfg, cfg.resultsDir);
end
