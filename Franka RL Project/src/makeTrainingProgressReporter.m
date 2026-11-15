function report = makeTrainingProgressReporter(algorithm, model, cfg, agent)
% Supported custom stop callback: display actual steps and retain episode diagnostics.
progressFile = fullfile(cfg.resultsDir, lower(string(algorithm)) + "_progress.csv");
firstReport = true;
if nargin < 4, agent = []; end
lastCheckpointStep = 0;
timer = tic;
fprintf("%s training budget: %d ENVIRONMENT STEPS; up to %d steps per episode.\n", ...
    algorithm, cfg.budgetSteps, cfg.maxSteps);
report = @update;

    function stop = update(stats)
        total = double(stats.TotalAgentSteps(end));
        episode = double(stats.EpisodeIndex(end));
        count = double(stats.EpisodeSteps(end));
        reward = double(stats.EpisodeReward(end));
        info = model.lastStepInfo;
        status = "completed";
        if isfield(info, "status"), status = string(info.status); end
        success = isfield(info, "success") && info.success;
        errors = model.trackingErrors(1:model.stepCount);
        meanError = NaN;
        if ~isempty(errors), meanError = mean(errors); end
        row = table(episode, total, 100*total/cfg.budgetSteps, count, ...
            model.curriculumStage, model.maxTargetSpeed, reward, meanError, ...
            status, success, toc(timer), VariableNames=["Episode", "GlobalSteps", ...
            "PercentComplete", "EpisodeSteps", "CurriculumStage", "MaxTargetSpeed", ...
            "Reward", "MeanTrackingError_M", "Status", "Success", "ElapsedSeconds"]);
        if firstReport
            writetable(row, progressFile);
            firstReport = false;
        else
            writetable(row, progressFile, WriteMode="append", WriteVariableNames=false);
        end
        fprintf("%s | steps %d/%d (%5.2f%%) | episode %d (%d/%d steps) | stage %d/%d | reward %.2f | error %.2f cm | %s | success %d\n", ...
            algorithm, total, cfg.budgetSteps, 100*total/cfg.budgetSteps, ...
            episode, count, cfg.maxSteps, model.curriculumStage, numel(cfg.curriculumSpeeds), ...
            reward, 100*meanError, status, success);
        assert(total == model.totalStepCount, "Agent/environment step counters differ.");
        if ~isempty(agent) && ...
                (total-lastCheckpointStep >= cfg.checkpointIntervalSteps || total >= cfg.budgetSteps)
            % One rolling file, separate from the final, budget-verified agent.
            actualEnvironmentSteps = model.totalStepCount;
            curriculumHistory = model.curriculumHistory;
            rngState = rng;
            checkpointFile = fullfile(cfg.resultsDir, lower(string(algorithm)) + "_checkpoint.mat");
            save(checkpointFile, "agent", "cfg", "actualEnvironmentSteps", ...
                "curriculumHistory", "rngState", "-v7.3");
            lastCheckpointStep = total;
        end
        stop = total >= cfg.budgetSteps;
    end
end
