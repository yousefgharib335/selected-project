function [env, model] = createTrackingEnvironment(cfg)
% rlFunctionEnv explicitly carries task state through LoggedSignals.
model = MovingTargetTrackingEnv(cfg.maxIncrement, ...
    cfg.trackingRewardScale, cfg.progressRewardWeight);
model.dt = cfg.dt;
model.maxEpisodeSteps = cfg.maxSteps;
model.targetWorkspaceLower = cfg.box(:, 1);
model.targetWorkspaceUpper = cfg.box(:, 2);
model.tolerance = cfg.posTol;
model.finalWindowSteps = cfg.finalWindowSteps;
model.maxTargetSpeed = cfg.maxTargetSpeed;
model.rewardDiscountFactor = cfg.discountFactor;
model.failurePenalty = cfg.failurePenalty;
env = rlFunctionEnv(getObservationInfo(model), getActionInfo(model), ...
    @advance, @initialize);

    function [observation, LoggedSignals] = initialize()
        observation = reset(model);
        LoggedSignals = struct("Environment", model, "Info", struct());
    end

    function [observation, reward, done, LoggedSignals] = advance(action, LoggedSignals)
        [observation, reward, done, info] = step(LoggedSignals.Environment, action);
        LoggedSignals.Info = info;
        model.lastStepInfo = info;
    end
end
