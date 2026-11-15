classdef TestMovingTargetTrackingEnv < matlab.unittest.TestCase
    properties
        Env
    end

    methods (TestClassSetup)
        function createEnvironment(testCase)
            projectDir = fileparts(fileparts(mfilename("fullpath")));
            addpath(fullfile(projectDir, "src"));
            testCase.Env = MovingTargetTrackingEnv(0.01, 50, 1);
        end
    end

    methods (TestMethodSetup)
        function resetEnvironment(testCase)
            testCase.Env.maxEpisodeSteps = 400;
            testCase.Env.finalWindowSteps = 100;
            testCase.Env.maxTotalSteps = Inf;
            testCase.Env.totalStepCount = 0;
            rng(2029, "twister");
            reset(testCase.Env);
        end
    end

    methods (Test)
        function resetIsRepeatableAndProducesValidCases(testCase)
            env = testCase.Env;
            rng(6029, "twister");
            obsA = reset(env);
            qA = env.q;
            startA = env.targetStart;
            velocityA = env.targetVelocity;

            rng(6029, "twister");
            obsB = reset(env);
            testCase.verifyEqual(obsB, obsA);
            testCase.verifyEqual(env.q, qA);
            testCase.verifyEqual(env.targetStart, startA);
            testCase.verifyEqual(env.targetVelocity, velocityA);

            lower = env.targetWorkspaceLower;
            upper = env.targetWorkspaceUpper;
            for caseIndex = 1:5
                reset(env);
                eePosition = tform2trvec( ...
                    getTransform(env.Robot, env.q, env.EndEffectorName)).';
                targetEnd = env.targetStart + env.targetVelocity * ...
                    (env.maxEpisodeSteps * env.dt);

                testCase.verifyTrue(env.isJointStateValid(env.q(1:7)));
                testCase.verifyFalse(checkCollision(env.Robot, env.q, ...
                    "SkippedSelfCollisions", env.skippedSelfCollisionPairs));
                testCase.verifyGreaterThanOrEqual(eePosition, lower);
                testCase.verifyLessThanOrEqual(eePosition, upper);
                testCase.verifyGreaterThanOrEqual(env.targetStart, lower);
                testCase.verifyLessThanOrEqual(env.targetStart, upper);
                testCase.verifyGreaterThanOrEqual(targetEnd, lower);
                testCase.verifyLessThanOrEqual(targetEnd, upper);
                testCase.verifyLessThanOrEqual(norm(env.targetVelocity), ...
                    env.maxTargetSpeed + 1e-12);
                testCase.verifyGreaterThanOrEqual( ...
                    norm(env.targetStart - eePosition), 0.01 - 1e-12);
                testCase.verifyLessThanOrEqual( ...
                    norm(env.targetStart - eePosition), 0.02 + 1e-12);
                testCase.verifySize(env.getObservation(), [24 1]);
            end
        end

        function stepClipsActionsToTheConfiguredIncrement(testCase)
            env = testCase.Env;
            qBefore = env.q;
            requestedAction = zeros(7, 1);
            requestedAction(1) = 2 * env.maxJointStep;

            [~, ~, isDone, info] = step(env, requestedAction);

            expectedAppliedAction = zeros(7, 1);
            expectedAppliedAction(1) = env.maxJointStep;
            testCase.verifyFalse(isDone);
            testCase.verifyTrue(info.actionClipped);
            testCase.verifyEqual(info.requestedAction, requestedAction);
            testCase.verifyEqual(info.appliedAction, expectedAppliedAction);
            testCase.verifyEqual(env.q(1:7).', ...
                qBefore(1:7).' + expectedAppliedAction, "AbsTol", 1e-12);
            testCase.verifyLessThanOrEqual( ...
                abs(env.q(1:7).' - qBefore(1:7).'), ...
                env.maxJointStep + 1e-12);
        end

        function jointLimitViolationEndsEpisodeWithoutApplyingAction(testCase)
            env = testCase.Env;
            env.q(1) = env.jointUpperLimit(1) - 0.005;
            qBefore = env.q;
            action = zeros(7, 1);
            action(1) = env.maxJointStep;

            [~, reward, isDone, info] = step(env, action);

            testCase.verifyTrue(isDone);
            testCase.verifyEqual(reward, -env.failurePenalty);
            testCase.verifyEqual(info.status, "joint-limit-violation");
            testCase.verifyEqual(env.q, qBefore);
            testCase.verifyEqual(env.stepCount, 0);
            testCase.verifyEqual(env.totalStepCount, 1);
        end

        function selfCollisionViolationEndsEpisodeWithoutApplyingAction(testCase)
            env = testCase.Env;
            qStart = [0, -0.785, 0, -2.356, 0, 1.571, 0.785, 0.04, 0.04];
            qColliding = [0, 0, 0, -1.57, 0, 0, 0, 0.04, 0.04];
            testCase.verifyFalse(checkCollision(env.Robot, qStart, ...
                "SkippedSelfCollisions", env.skippedSelfCollisionPairs));
            testCase.verifyTrue(checkCollision(env.Robot, qColliding, ...
                "SkippedSelfCollisions", env.skippedSelfCollisionPairs));

            previousQ = qStart;
            collisionReached = false;
            for sampleIndex = 1:300
                candidateQ = qStart + (sampleIndex / 300) * (qColliding - qStart);
                if checkCollision(env.Robot, candidateQ, ...
                        "SkippedSelfCollisions", env.skippedSelfCollisionPairs)
                    collisionReached = true;
                    break;
                end
                previousQ = candidateQ;
            end
            testCase.verifyTrue(collisionReached);

            env.q = previousQ;
            action = candidateQ(1:7).' - previousQ(1:7).';
            testCase.verifyLessThanOrEqual(abs(action), ...
                env.maxJointStep + 1e-12);
            qBefore = env.q;
            [~, reward, isDone, info] = step(env, action);

            testCase.verifyTrue(isDone);
            testCase.verifyEqual(reward, -env.failurePenalty);
            testCase.verifyEqual(info.status, "self-collision");
            testCase.verifyEqual(env.q, qBefore);
            testCase.verifyEqual(env.stepCount, 0);
        end

        function rewardMatchesTrackingProgressAndActionTerms(testCase)
            env = testCase.Env;
            initialError = env.previousTrackingError;
            nextTarget = env.targetStart + env.targetVelocity * env.dt;
            eePosition = tform2trvec( ...
                getTransform(env.Robot, env.q, env.EndEffectorName)).';
            nextError = norm(eePosition - nextTarget);
            margins = min(env.q(1:7).' - env.jointLowerLimit, ...
                env.jointUpperLimit - env.q(1:7).');
            nearLimitPenalty = 0.01 * any(margins < 0.1);
            nextCost = (env.trackingRewardScale * nextError) / ...
                (1 + env.trackingRewardScale * nextError);
            initialCost = (env.trackingRewardScale * initialError) / ...
                (1 + env.trackingRewardScale * initialError);
            expectedReward = -nextCost ...
                + env.progressRewardWeight * ...
                (initialCost - env.rewardDiscountFactor * nextCost) ...
                - nearLimitPenalty;

            [~, reward, isDone, info] = step(env, zeros(7, 1));

            testCase.verifyFalse(isDone);
            testCase.verifyEqual(reward, expectedReward, "AbsTol", 1e-10);
            testCase.verifyEqual(env.targetPosition, nextTarget, "AbsTol", 1e-12);
            testCase.verifyEqual(info.trackingError, nextError, "AbsTol", 1e-12);
        end

        function successRequiresTheWholeFinalWindowWithinTolerance(testCase)
            env = testCase.Env;
            env.maxEpisodeSteps = 2;
            env.finalWindowSteps = 2;
            reset(env);
            eePosition = tform2trvec( ...
                getTransform(env.Robot, env.q, env.EndEffectorName)).';
            env.targetStart = eePosition;
            env.targetPosition = eePosition;
            env.targetVelocity = zeros(3, 1);
            env.previousTrackingError = 0;

            [~, ~, firstDone] = step(env, zeros(7, 1));
            [~, ~, secondDone, info] = step(env, zeros(7, 1));

            testCase.verifyFalse(firstDone);
            testCase.verifyTrue(secondDone);
            testCase.verifyTrue(info.success);
            testCase.verifyEqual(info.finalWindowMeanError, 0, "AbsTol", 1e-12);
            testCase.verifyEqual(info.finalWindowMaxError, 0, "AbsTol", 1e-12);
        end

        function boundedRewardDoesNotFavorConstraintTermination(testCase)
            env = testCase.Env;
            % Each bounded tracking cost <1; normalized action change costs <=0.28;
            % near-limit costs <=0.01. Potential shaping adds at most one to
            % this conservative worst-case discounted cost bound.
            worstValidCost = (1 + 0.01 * 7 * 2^2 + 0.01) / ...
                (1 - env.rewardDiscountFactor) + env.progressRewardWeight;
            testCase.verifyGreaterThan(env.failurePenalty, worstValidCost);
            env.targetStart = env.targetStart + [10; 0; 0];
            env.targetPosition = env.targetStart;
            env.previousTrackingError = 10;
            [~, reward, done] = step(env, zeros(7, 1));
            testCase.verifyFalse(done);
            testCase.verifyGreaterThan(reward, -2.29);
            testCase.verifyLessThan(reward, 0);
        end

        function smoothnessRewardUsesNormalizedActionChanges(testCase)
            env = testCase.Env;
            env.targetVelocity = zeros(3, 1);
            action = [0.001; zeros(6, 1)];
            step(env, action);
            previousError = env.previousTrackingError;
            [~, reward, ~, info] = step(env, -action);
            scaled = env.trackingRewardScale * info.trackingError;
            previousScaled = env.trackingRewardScale * previousError;
            cost = scaled / (1 + scaled);
            previousCost = previousScaled / (1 + previousScaled);
            margins = min(env.q(1:7).' - env.jointLowerLimit, ...
                env.jointUpperLimit - env.q(1:7).');
            expected = -cost + env.progressRewardWeight * ...
                (previousCost - env.rewardDiscountFactor * cost) ...
                - 0.01 * sum(((-2 * action) / env.maxJointStep).^2) ...
                - 0.01 * any(margins < 0.1);
            testCase.verifyEqual(reward, expected, AbsTol=1e-10);
        end

        function stepBudgetCountsEarlyFailuresAndStopsMidEpisodeExactly(testCase)
            env = testCase.Env;
            env.setStepBudget(3);

            env.q(1) = env.jointUpperLimit(1) - 0.005;
            violatingAction = zeros(7, 1);
            violatingAction(1) = env.maxJointStep;
            [~, ~, failureDone] = step(env, violatingAction);
            testCase.verifyTrue(failureDone);
            testCase.verifyEqual(env.totalStepCount, 1);

            reset(env);
            testCase.verifyEqual(env.totalStepCount, 1);
            [~, ~, secondDone] = step(env, zeros(7, 1));
            testCase.verifyFalse(secondDone);
            [~, ~, budgetDone, info] = step(env, zeros(7, 1));

            testCase.verifyTrue(budgetDone);
            testCase.verifyEqual(info.status, "training-step-budget-reached");
            testCase.verifyTrue(info.stepBudgetReached);
            testCase.verifyEqual(env.totalStepCount, 3);
            testCase.verifyEqual(info.globalStepCount, 3);
            testCase.verifyLessThan(env.stepCount, env.maxEpisodeSteps);
            testCase.verifyTrue(isnan(info.finalWindowMeanError));
            testCase.verifyFalse(info.success);
            testCase.verifyError(@() step(env, zeros(7, 1)), ...
                "MovingTargetTrackingEnv:StepBudgetExhausted");
        end

        function reinforcementLearningTrainingHonorsTheExactStepBudget(testCase)
            env = testCase.Env;
            budget = 3;
            env.setStepBudget(budget);
            agent = rlTD3Agent(getObservationInfo(env), getActionInfo(env));
            agent.AgentOptions.NumWarmStartSteps = 100;
            options = rlTrainingOptions( ...
                "MaxEpisodes", budget, ...
                "MaxStepsPerEpisode", env.maxEpisodeSteps, ...
                "StopTrainingCriteria", "GlobalStepCount", ...
                "StopTrainingValue", budget, ...
                "ScoreAveragingWindowLength", 2, ...
                "Verbose", false, ...
                "Plots", "none", ...
                "UseParallel", false, ...
                "SimulationStorageType", "none");

            trainingStats = train(agent, env, options);

            testCase.verifyEqual(trainingStats.TotalAgentSteps, budget);
            testCase.verifyEqual(env.totalStepCount, budget);
        end
    end
end
