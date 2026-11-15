classdef MovingTargetTrackingEnv < rl.env.MATLABEnvironment
    properties
        Robot
        EndEffectorName = "panda_hand"
        dt = 0.05
        maxEpisodeSteps = 400
        stepCount = 0
        maxTotalSteps = Inf
        totalStepCount = 0
        q
        targetStart
        targetVelocity
        targetPosition
        tolerance = 0.02
        maxJointStep = 0.01
        trackingRewardScale = 1
        progressRewardWeight = 0
        rewardDiscountFactor = 0.99
        failurePenalty = 150
        lastStepInfo = struct()
        maxTargetSpeed = 0.01
        trackingErrors
        previousAction
        previousTrackingError = 0
        skippedSelfCollisionPairs
        jointLowerLimit = [-2.8973; -1.7628; -2.8973; -3.0718; -2.8973; -0.0175; -2.8973]
        jointUpperLimit = [2.8973; 1.7628; 2.8973; -0.0698; 2.8973; 3.7525; 2.8973]
        targetWorkspaceLower = [0.30; -0.30; 0.15]
        targetWorkspaceUpper = [0.65; 0.30; 0.60]
        finalWindowSteps = 100
        curriculum = []
        curriculumStage = 1
        curriculumStageStart = 0
        curriculumHistory = struct([])
        recentSuccesses = []
    end

    methods
        function this = MovingTargetTrackingEnv(maxJointStep, trackingRewardScale, progressRewardWeight)
            if nargin < 1
                maxJointStep = 0.01;
            end
            if nargin < 2
                trackingRewardScale = 1;
            end
            if nargin < 3
                progressRewardWeight = 0;
            end
            validateattributes(maxJointStep, {'numeric'}, ...
                {"scalar", "real", "finite", "positive"});
            validateattributes(trackingRewardScale, {'numeric'}, ...
                {"scalar", "real", "finite", "positive"});
            validateattributes(progressRewardWeight, {'numeric'}, ...
                {"scalar", "real", "finite", "nonnegative"});

            maxJointStep = double(maxJointStep);
            trackingRewardScale = double(trackingRewardScale);
            progressRewardWeight = double(progressRewardWeight);
            actionInfo = rlNumericSpec([7 1], ...
                "LowerLimit", -maxJointStep * ones(7, 1), ...
                "UpperLimit",  maxJointStep * ones(7, 1));

            observationInfo = rlNumericSpec([24 1], ...
                "LowerLimit", -Inf * ones(24, 1), ...
                "UpperLimit",  Inf * ones(24, 1));

            this = this@rl.env.MATLABEnvironment(observationInfo, actionInfo);
            this.maxJointStep = maxJointStep;
            this.trackingRewardScale = trackingRewardScale;
            this.progressRewardWeight = progressRewardWeight;
            this.Robot = loadrobot("frankaEmikaPanda");
            this.Robot.DataFormat = "row";

            bodyNames = this.Robot.BodyNames;
            % Exclude connected or model-overlapping meshes; all other body pairs remain checked.
            this.skippedSelfCollisionPairs = cell(11, 2);
            for i = 1:9
                this.skippedSelfCollisionPairs(i, :) = bodyNames(i:i+1);
            end
            this.skippedSelfCollisionPairs(10, :) = {"panda_link7", "panda_hand"};
            this.skippedSelfCollisionPairs(11, :) = {"panda_hand", "panda_rightfinger"};

            this.reset();
        end

        function obs = reset(this)
            this.updateCurriculum();
            this.stepCount = 0;
            this.trackingErrors = zeros(this.maxEpisodeSteps, 1);
            this.previousAction = zeros(7, 1);

            nominalQ = [0, -0.785, 0, -2.356, 0, 1.571, 0.785, 0.04, 0.04];
            resetFound = false;
            for attempt = 1:200
                qCandidate = nominalQ;
                qCandidate(1:7) = this.enforceJointLimits( ...
                    nominalQ(1:7).' + 0.08 * randn(7, 1)).';
                if this.isJointStateValid(qCandidate(1:7)) && ...
                        ~this.hasSelfCollision(qCandidate)
                    T = getTransform(this.Robot, qCandidate, this.EndEffectorName);
                    endEffectorPos = tform2trvec(T).';
                    if ~this.isInsideTargetWorkspace(endEffectorPos)
                        continue;
                    end

                    for targetAttempt = 1:1000
                        offset = randn(3, 1);
                        offset = offset / max(norm(offset), eps) * (0.01 + 0.01 * rand);
                        candidateTargetStart = endEffectorPos + offset;
                        if ~this.isInsideTargetWorkspace(candidateTargetStart)
                            continue;
                        end

                        direction = randn(3, 1);
                        direction = direction / max(norm(direction), eps);
                        speed = this.maxTargetSpeed * rand;
                        candidateTargetVelocity = speed * direction;
                        candidateTargetEnd = candidateTargetStart + ...
                            candidateTargetVelocity * (this.maxEpisodeSteps * this.dt);

                        if this.isInsideTargetWorkspace(candidateTargetEnd)
                            resetFound = true;
                            targetStart = candidateTargetStart;
                            targetVelocity = candidateTargetVelocity;
                            this.q = qCandidate;
                            break;
                        end
                    end
                    if resetFound
                        break;
                    end
                end
            end
            if ~resetFound
                error("MovingTargetTrackingEnv:NoValidTargetPath", ...
                    "Could not sample a valid reset pose and straight target path inside the configured workspace.");
            end

            this.targetStart = targetStart;
            this.targetVelocity = targetVelocity;
            this.targetPosition = targetStart;

            T = getTransform(this.Robot, this.q, this.EndEffectorName);
            initialEndEffectorPosition = tform2trvec(T).';
            this.previousTrackingError = norm(initialEndEffectorPosition - this.targetPosition);

            obs = this.getObservation();
        end

        function setStepBudget(this, stepBudget)
            validateattributes(stepBudget, {'numeric'}, ...
                {"scalar", "real", "finite", "positive", "integer"});
            this.maxTotalSteps = double(stepBudget);
            this.totalStepCount = 0;
        end

        function [nextObs, reward, isDone, info] = step(this, action)
            if numel(action) ~= 7 || any(~isfinite(action(:)))
                error("MovingTargetTrackingEnv:InvalidAction", ...
                    "Action must contain seven finite joint increments.");
            end
            if this.totalStepCount >= this.maxTotalSteps
                error("MovingTargetTrackingEnv:StepBudgetExhausted", ...
                    "The configured environment-step budget has already been reached.");
            end
            this.totalStepCount = this.totalStepCount + 1;

            requestedAction = double(action(:));
            action = max(min(requestedAction, this.maxJointStep), -this.maxJointStep);
            actionClipped = any(action ~= requestedAction);
            qCandidate = this.q;
            qCandidate(1:7) = double(this.q(1:7)) + action.';

            if ~this.isJointStateValid(qCandidate(1:7))
                this.recordCurriculumResult(false);
                reward = -this.failurePenalty;
                isDone = true;
                nextObs = this.getObservation();
                info = struct("status", "joint-limit-violation", ...
                    "requestedAction", requestedAction, ...
                    "appliedAction", zeros(7, 1), ...
                    "actionClipped", actionClipped, ...
                    "actionSafetyClamped", false, ...
                    "globalStepCount", this.totalStepCount, ...
                    "stepBudgetReached", this.totalStepCount >= this.maxTotalSteps, ...
                    "stepCount", this.stepCount);
                return;
            end

            if this.hasSelfCollision(qCandidate)
                this.recordCurriculumResult(false);
                reward = -this.failurePenalty;
                isDone = true;
                nextObs = this.getObservation();
                info = struct("status", "self-collision", ...
                    "requestedAction", requestedAction, ...
                    "appliedAction", zeros(7, 1), ...
                    "actionClipped", actionClipped, ...
                    "actionSafetyClamped", false, ...
                    "globalStepCount", this.totalStepCount, ...
                    "stepBudgetReached", this.totalStepCount >= this.maxTotalSteps, ...
                    "stepCount", this.stepCount);
                return;
            end

            this.q = qCandidate;
            this.stepCount = this.stepCount + 1;

            this.targetPosition = this.targetStart + this.targetVelocity * (this.stepCount * this.dt);

            T = getTransform(this.Robot, this.q, this.EndEffectorName);
            endEffectorPos = tform2trvec(T);
            endEffectorPos = endEffectorPos(:);
            trackingError = norm(endEffectorPos - this.targetPosition);
            this.trackingErrors(this.stepCount) = trackingError;
            actionDifference = action - this.previousAction;

            % Bounded costs keep a long valid episode preferable to a failure.
            scaledError = this.trackingRewardScale * trackingError;
            trackingCost = scaledError / (1 + scaledError);
            previousScaledError = this.trackingRewardScale * this.previousTrackingError;
            previousTrackingCost = previousScaledError / (1 + previousScaledError);
            reward = -trackingCost ...
                - 0.01 * sum((actionDifference / this.maxJointStep).^2);
            if this.progressRewardWeight > 0
                reward = reward + this.progressRewardWeight ...
                    * (previousTrackingCost - this.rewardDiscountFactor * trackingCost);
            end
            
            safetyMargin = 0.1;
            margins = min(this.q(1:7).' - this.jointLowerLimit, ...
                          this.jointUpperLimit - this.q(1:7).');
            nearLimit = any(margins < safetyMargin);
            if nearLimit
                reward = reward - 0.01;
            end
            
            this.previousAction = action;
            this.previousTrackingError = trackingError;

            episodeComplete = this.stepCount >= this.maxEpisodeSteps;
            budgetReached = this.totalStepCount >= this.maxTotalSteps;
            budgetTerminatedEpisode = budgetReached && ~episodeComplete;
            isDone = episodeComplete || budgetReached;

            finalWindowMeanError = NaN;
            finalWindowMaxError = NaN;
            success = false;
            if episodeComplete
                windowStart = this.maxEpisodeSteps - this.finalWindowSteps + 1;
                finalWindowErrors = this.trackingErrors(windowStart:this.maxEpisodeSteps);
                finalWindowMeanError = mean(finalWindowErrors);
                finalWindowMaxError = max(finalWindowErrors);
                success = finalWindowMaxError <= this.tolerance;
                this.recordCurriculumResult(success);
            end

            nextObs = this.getObservation();
            info = struct("endEffectorPosition", endEffectorPos(:), ...
                "targetPosition", this.targetPosition(:), ...
                "trackingError", trackingError, ...
                "stepCount", this.stepCount, ...
                "requestedAction", requestedAction, ...
                "appliedAction", action, ...
                "actionClipped", actionClipped, ...
                "actionSafetyClamped", false, ...
                "globalStepCount", this.totalStepCount, ...
                "stepBudgetReached", budgetReached, ...
                "actionDifferenceSquared", sum(actionDifference.^2), ...
                "success", success, ...
                "finalWindowMeanError", finalWindowMeanError, ...
                "finalWindowMaxError", finalWindowMaxError);
            if budgetTerminatedEpisode
                info.status = "training-step-budget-reached";
            end
        end

        function obs = getObservation(this)
            T = getTransform(this.Robot, this.q, this.EndEffectorName);
            endEffectorPos = tform2trvec(T);
            endEffectorPos = endEffectorPos(:);
            relativePosition = this.targetPosition - endEffectorPos;

            obs = [this.q(1:7).'; ...
                this.targetPosition(:); ...
                this.targetVelocity(:); ...
                relativePosition(:); ...
                this.previousAction(:); ...
                (this.maxEpisodeSteps - this.stepCount) / this.maxEpisodeSteps];
        end

        function configureCurriculum(this, cfg)
            this.curriculum = cfg;
            this.curriculumStage = 1;
            this.curriculumStageStart = this.totalStepCount;
            this.recentSuccesses = [];
            this.maxTargetSpeed = cfg.curriculumSpeeds(1);
            this.curriculumHistory = struct("stage", 1, ...
                "startStep", this.totalStepCount, "maxTargetSpeed", this.maxTargetSpeed, ...
                "seed", cfg.trainSeed, "promotionSuccessRate", NaN);
        end

        function recordCurriculumResult(this, success)
            if isempty(this.curriculum)
                return;
            end
            this.recentSuccesses(end + 1) = double(success);
            this.recentSuccesses = this.recentSuccesses( ...
                max(1, end - this.curriculum.curriculumWindow + 1):end);
        end

        function updateCurriculum(this)
            if isempty(this.curriculum) || ...
                    this.curriculumStage >= numel(this.curriculum.curriculumSpeeds)
                return;
            end
            cfg = this.curriculum;
            stable = numel(this.recentSuccesses) >= cfg.curriculumWindow && ...
                mean(this.recentSuccesses) >= cfg.curriculumSuccessRate;
            enoughSteps = this.totalStepCount - this.curriculumStageStart >= ...
                cfg.curriculumMinSteps(this.curriculumStage);
            if stable && enoughSteps
                rate = mean(this.recentSuccesses);
                this.curriculumStage = this.curriculumStage + 1;
                this.curriculumStageStart = this.totalStepCount;
                this.maxTargetSpeed = cfg.curriculumSpeeds(this.curriculumStage);
                this.curriculumHistory(end + 1) = struct("stage", this.curriculumStage, ...
                    "startStep", this.totalStepCount, "maxTargetSpeed", this.maxTargetSpeed, ...
                    "seed", cfg.trainSeed, "promotionSuccessRate", rate);
                this.recentSuccesses = [];
            end
        end

        function valid = isJointStateValid(this, q)
            q = q(:);
            valid = numel(q) == 7 && all(q >= this.jointLowerLimit) && ...
                all(q <= this.jointUpperLimit);
        end

        function q = enforceJointLimits(this, q)
            q = min(max(q(:), this.jointLowerLimit), this.jointUpperLimit);
        end

        function colliding = hasSelfCollision(this, q)
            colliding = checkCollision(this.Robot, q, ...
                "SkippedSelfCollisions", this.skippedSelfCollisionPairs);
        end

        function inside = isInsideTargetWorkspace(this, position)
            position = position(:);
            inside = numel(position) == 3 && ...
                all(position >= this.targetWorkspaceLower) && ...
                all(position <= this.targetWorkspaceUpper);
        end

    end
end
