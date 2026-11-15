function stability = plotLearningCurves(cfg)
% Compare training stability using training data only, never final evaluation.
if nargin == 0, cfg = teamConfig(); end
names = ["TD3", "DDPG"];
fig = figure("Visible", "off");
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 1);
rows = cell(2, 1);
for index = 1:2
    data = load(fullfile(cfg.resultsDir, lower(names(index)) + "_agent.mat"));
    reward = double(data.trainingStats.EpisodeReward(:));
    steps = cumsum(double(data.trainingStats.EpisodeSteps(:)));
    window = min(25, numel(reward));
    ax = nexttile(layout);
    plot(ax, steps, reward, "Color", [0.75 0.75 0.75]); hold(ax, "on");
    plot(ax, steps, movmean(reward, [window-1 0]), "LineWidth", 1.5);
    if isfield(data, "curriculumHistory")
        for stage = 2:numel(data.curriculumHistory)
            xline(ax, data.curriculumHistory(stage).startStep, "--", "Stage " + stage);
        end
    end
    xlabel(ax, "Cumulative environment steps"); ylabel(ax, "Episode reward");
    title(ax, names(index)); grid(ax, "on");
    tail = reward(max(1, end-49):end);
    rows{index} = struct("Controller", names(index), "Episodes", numel(reward), ...
        "TotalSteps", steps(end), "FinalRewardSampleCount", numel(tail), ...
        "FinalRewardMean", mean(tail), "FinalRewardStd", std(tail), ...
        "TrainingWallSeconds", data.trainingWallSeconds, ...
        "ReachedFullCurriculum", data.reachedFullTask);
end
stability = struct2table(vertcat(rows{:}));
exportgraphics(fig, fullfile(cfg.resultsDir, "learning_curves.png"), Resolution=150);
savefig(fig, fullfile(cfg.resultsDir, "learning_curves.fig"));
writetable(stability, fullfile(cfg.resultsDir, "learning_stability.csv"));
end
