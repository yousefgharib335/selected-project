function [metrics, trace] = runControllerEpisode(model, taskCase, controller)
% Every controller uses exactly the same step, constraint, and scoring logic.
model.maxTotalSteps = Inf;
reset(model);
model.q = taskCase.q;
model.targetStart = taskCase.targetStart;
model.targetPosition = taskCase.targetStart;
model.targetVelocity = taskCase.targetVelocity;
model.previousAction = zeros(7, 1);
initialPosition = tform2trvec(getTransform(model.Robot, model.q, model.EndEffectorName)).';
model.previousTrackingError = norm(initialPosition - model.targetPosition);
obs = model.getObservation();
errors = nan(model.maxEpisodeSteps, 1);
actions = zeros(model.maxEpisodeSteps, 7);
requested = zeros(model.maxEpisodeSteps, 7);
rewards = zeros(model.maxEpisodeSteps, 1);
rewardSum = 0;
status = "completed";
done = false;
steps = 0;
timer = tic;
while ~done && steps < model.maxEpisodeSteps
    steps = steps + 1;
    action = controller(obs, model);
    requested(steps, :) = action(:).';
    [obs, reward, done, info] = step(model, action);
    rewardSum = rewardSum + reward;
    rewards(steps) = reward;
    actions(steps, :) = info.appliedAction.';
    if isfield(info, "trackingError"), errors(steps) = info.trackingError; end
    if isfield(info, "status"), status = string(info.status); end
end
wallSeconds = toc(timer);
complete = status == "completed" && model.stepCount == model.maxEpisodeSteps;
window = errors(model.maxEpisodeSteps-model.finalWindowSteps+1:end);
windowComplete = complete && all(isfinite(window));
finalMean = NaN; finalMax = NaN;
if windowComplete
    finalMean = mean(window);
    finalMax = max(window);
end
validErrors = errors(isfinite(errors));
meanError = NaN; maxError = NaN; finalError = NaN;
if ~isempty(validErrors)
    meanError = mean(validErrors); maxError = max(validErrors); finalError = validErrors(end);
end
actions = actions(1:steps, :);
differences = diff([zeros(1, 7); actions], 1, 1);
metrics = struct("Status", status, "Steps", steps, ...
    "ValidMotionSteps", model.stepCount, "SimulatedSeconds", steps * model.dt, ...
    "WallSeconds", wallSeconds, "EpisodeReward", rewardSum, ...
    "Success", windowComplete && finalMax <= model.tolerance, ...
    "JointLimitViolation", status == "joint-limit-violation", ...
    "CollisionViolation", status == "self-collision", ...
    "FinalWindowComplete", windowComplete, "FinalWindowMeanError_M", finalMean, ...
    "FinalWindowMaxError_M", finalMax, "FinalPositionError_M", finalError, ...
    "MeanTrackingError_M", meanError, "MaxTrackingError_M", maxError, ...
    "MeanJointIncrement_Rad", mean(abs(actions(:))), ...
    "MaxJointIncrement_Rad", max(abs(actions(:))), ...
    "SumSquaredActionDifferences", sum(differences.^2, "all"));
trace = struct("trackingErrors", errors(1:steps), "appliedActions", actions, ...
    "requestedActions", requested(1:steps, :), "rewards", rewards(1:steps));
end
