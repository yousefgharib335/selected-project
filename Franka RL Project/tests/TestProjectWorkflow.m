classdef TestProjectWorkflow < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(mfilename("fullpath")));
            addpath(root);
            setupProject();
        end
    end
    methods (Test)
        function configurationMatchesStarter(testCase)
            cfg = teamConfig();
            testCase.verifyEqual(cfg.dt, 0.05);
            testCase.verifyEqual(cfg.maxSteps, 400);
            testCase.verifyEqual(cfg.maxIncrement, 0.01);
            testCase.verifyEqual(cfg.finalWindowSteps, 100);
            testCase.verifyEqual(cfg.budgetSteps, 300000);
            testCase.verifyEqual(cfg.numEvalCases, 30);
            testCase.verifyNotEqual(cfg.trainSeed, cfg.evalSeed);
            maximumValidCost = (1 + 0.01*7*2^2 + 0.01) / ...
                (1-cfg.discountFactor) + cfg.progressRewardWeight;
            testCase.verifyGreaterThan(cfg.failurePenalty, maximumValidCost);
        end
        function functionEnvironmentAndBothAgentsTrain(testCase)
            cfg = teamConfig();
            cfg.budgetSteps = 6;
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg.resultsDir = fixture.Folder;
            for name = ["TD3", "DDPG"]
                rng(cfg.validationSeed, "twister");
                [env, model] = createTrackingEnvironment(cfg);
                validateEnvironment(env);
                agent = makeAgent(name, env, cfg);
                % Exercise actual gradient updates as well as the adapters.
                agent.AgentOptions.MiniBatchSize = 2;
                agent.AgentOptions.NumWarmStartSteps = 2;
                model.setStepBudget(6);
                model.configureCurriculum(cfg);
                reporter = makeTrainingProgressReporter(name, model, cfg);
                options = rlTrainingOptions("MaxEpisodes", 6, ...
                    "MaxStepsPerEpisode", cfg.maxSteps, ...
                    "StopTrainingCriteria", "Custom", "StopTrainingValue", reporter, ...
                    "Verbose", false, "Plots", "none", "UseParallel", false, ...
                    "SaveAgentCriteria", "none", "SimulationStorageType", "none");
                stats = train(agent, env, options);
                testCase.verifyEqual(stats.TotalAgentSteps, 6);
                testCase.verifyEqual(model.totalStepCount, 6);
                progress = readtable(fullfile(cfg.resultsDir, lower(name) + "_progress.csv"));
                testCase.verifyEqual(progress.GlobalSteps(end), 6);
                testCase.verifyEqual(progress.PercentComplete(end), 100);
                testCase.verifyEqual(string(progress.Status(end)), "training-step-budget-reached");
            end
        end
        function initialActorsDoNotIntroduceLargeJointDrift(testCase)
            cfg = teamConfig();
            rng(cfg.validationSeed);
            [env, model] = createTrackingEnvironment(cfg);
            [scale, bias] = observationScaling(cfg);
            testCase.verifySize(scale, [24 1]);
            testCase.verifySize(bias, [24 1]);
            normalized = scale .* model.getObservation() + bias;
            testCase.verifyTrue(all(isfinite(normalized)));
            for name = ["TD3", "DDPG"]
                agent = makeAgent(name, env, cfg);
                action = getAction(getActor(agent), {model.getObservation()});
                testCase.verifyEqual(double(action{1}), zeros(7, 1), AbsTol=1e-12);
                critics = getCritic(agent);
                for index = 1:numel(critics)
                    initialValue = getValue(critics(index), {model.getObservation()}, {zeros(7, 1)});
                    testCase.verifyEqual(double(initialValue), cfg.criticInitialValue, AbsTol=1e-12);
                end
            end
        end
        function rewardPrefersAMovementTowardTheTarget(testCase)
            cfg = teamConfig();
            rng(cfg.validationSeed);
            [~, model] = createTrackingEnvironment(cfg);
            qBase = model.q;
            action = [0.001; zeros(6, 1)];
            qTarget = qBase;
            qTarget(1:7) = qBase(1:7) + action.';
            target = tform2trvec(getTransform(model.Robot, qTarget, model.EndEffectorName)).';
            initial = tform2trvec(getTransform(model.Robot, qBase, model.EndEffectorName)).';
            model.targetStart = target;
            model.targetPosition = target;
            model.targetVelocity = zeros(3, 1);
            model.previousTrackingError = norm(initial-target);
            [~, towardReward] = step(model, action);
            model.q = qBase;
            model.stepCount = 0;
            model.previousAction = zeros(7, 1);
            model.targetPosition = target;
            model.previousTrackingError = norm(initial-target);
            [~, awayReward] = step(model, -action);
            testCase.verifyGreaterThan(towardReward, 0);
            testCase.verifyLessThan(awayReward, 0);
            testCase.verifyGreaterThan(towardReward, awayReward);
        end
        function multipleEpisodesSaveFinalAgentAndRollingCheckpoint(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = teamConfig();
            cfg.resultsDir = fixture.Folder;
            cfg.maxSteps = 2;
            cfg.finalWindowSteps = 1;
            cfg.budgetSteps = 6;
            cfg.miniBatchSize = 2;
            cfg.warmStartSteps = 2;
            cfg.checkpointIntervalSteps = 2;
            [~, stats] = trainTrackingAgent("TD3", cfg);
            testCase.verifyEqual(numel(stats.TotalAgentSteps), 3);
            testCase.verifyEqual(double(stats.TotalAgentSteps(end)), 6);
            saved = load(fullfile(cfg.resultsDir, "td3_agent.mat"));
            testCase.verifyEqual(saved.actualAgentSteps, 6);
            testCase.verifyEqual(saved.actualEnvironmentSteps, 6);
            checkpoint = load(fullfile(cfg.resultsDir, "td3_checkpoint.mat"));
            testCase.verifyEqual(checkpoint.actualEnvironmentSteps, 6);
            action = getAction(getActor(checkpoint.agent), {zeros(24, 1)});
            testCase.verifySize(action{1}, [7 1]);
            testCase.verifyTrue(all(isfinite(action{1})));
        end
        function curriculumRequiresStableTrainingEpisodes(testCase)
            cfg = teamConfig();
            cfg.curriculumMinSteps = [1 1 0];
            cfg.curriculumWindow = 2;
            [~, model] = createTrackingEnvironment(cfg);
            model.configureCurriculum(cfg);
            model.totalStepCount = 2;
            model.recordCurriculumResult(false);
            model.recordCurriculumResult(false);
            reset(model);
            testCase.verifyEqual(model.curriculumStage, 1);
            model.recordCurriculumResult(true);
            model.recordCurriculumResult(true);
            reset(model);
            testCase.verifyEqual(model.curriculumStage, 2);
            testCase.verifyEqual(model.maxTargetSpeed, 0.003);
        end
        function partialFinalWindowWithViolationCannotSucceed(testCase)
            cfg = teamConfig();
            rng(cfg.validationSeed);
            [~, model] = createTrackingEnvironment(cfg);
            taskCase = struct("q", model.q, "targetStart", model.targetStart, ...
                "targetVelocity", zeros(3, 1));
            model.maxEpisodeSteps = 3;
            model.finalWindowSteps = 2;
            [metrics, ~] = runControllerEpisode(model, taskCase, @lateFailure);
            testCase.verifyFalse(metrics.Success);
            testCase.verifyFalse(metrics.FinalWindowComplete);
            testCase.verifyTrue(metrics.JointLimitViolation);
            testCase.verifyTrue(isnan(metrics.FinalWindowMeanError_M));
            function action = lateFailure(~, state)
                action = zeros(7, 1);
                if state.stepCount == 2
                    state.q(1) = state.jointUpperLimit(1) - 0.005;
                    action(1) = 0.01;
                end
            end
        end
        function completeWindowAndSmoothnessAreScored(testCase)
            cfg = teamConfig();
            rng(cfg.validationSeed);
            [~, model] = createTrackingEnvironment(cfg);
            model.maxEpisodeSteps = 3;
            model.finalWindowSteps = 2;
            position = tform2trvec(getTransform(model.Robot, model.q, model.EndEffectorName)).';
            taskCase = struct("q", model.q, "targetStart", position, ...
                "targetVelocity", zeros(3, 1));
            [metrics, ~] = runControllerEpisode(model, taskCase, @(~, ~) zeros(7, 1));
            testCase.verifyTrue(metrics.Success);
            testCase.verifyEqual(metrics.SimulatedSeconds, 0.15, AbsTol=1e-12);
            testCase.verifyEqual(metrics.SumSquaredActionDifferences, 0);
        end
        function ikUsesSameIncrementLimit(testCase)
            cfg = teamConfig();
            rng(cfg.validationSeed);
            [~, model] = createTrackingEnvironment(cfg);
            solver = inverseKinematics("RigidBodyTree", model.Robot);
            solver.SolverParameters.AllowRandomRestart = false;
            action = ikController([], model, solver);
            testCase.verifySize(action, [7 1]);
            testCase.verifyLessThanOrEqual(abs(action), cfg.maxIncrement + 1e-12);
        end
        function evaluationExportsAllControllersOnSharedValidationCases(testCase)
            cfg = teamConfig();
            cfg.numEvalCases = 2;
            cfg.maxSteps = 4;
            cfg.finalWindowSteps = 2;
            cfg.budgetSteps = 6;
            cfg.evalSeed = cfg.validationSeed + 1; % Never consume final cases in tests.
            cfg.resultsDir = tempname;
            mkdir(cfg.resultsDir);
            cleanup = onCleanup(@() rmdir(cfg.resultsDir, "s"));
            rng(cfg.validationSeed);
            [env, ~] = createTrackingEnvironment(cfg);
            trainingStats = struct("TotalAgentSteps", cfg.budgetSteps, ...
                "EpisodeReward", [-1; -0.5], "EpisodeSteps", [3; 3]);
            actualEnvironmentSteps = cfg.budgetSteps;
            trainingWallSeconds = 0;
            reachedFullTask = true;
            for name = ["TD3", "DDPG"]
                agent = makeAgent(name, env, cfg);
                save(fullfile(cfg.resultsDir, lower(name) + "_agent.mat"), ...
                    "agent", "cfg", "trainingStats", "actualEnvironmentSteps", ...
                    "trainingWallSeconds", "reachedFullTask");
            end
            [cases, summary] = evaluateComparison(cfg);
            testCase.verifyEqual(height(cases), 6);
            testCase.verifyEqual(height(summary), 3);
            testCase.verifyEqual(cases.Case, [1; 2; 1; 2; 1; 2]);
            testCase.verifyTrue(isfile(fullfile(cfg.resultsDir, "comparison.mat")));
            testCase.verifyTrue(isfile(fullfile(cfg.resultsDir, "comparison_summary.csv")));
            saved = load(fullfile(cfg.resultsDir, "evaluation_cases.mat"));
            [repeat, ~] = evaluateComparison(cfg);
            savedAgain = load(fullfile(cfg.resultsDir, "evaluation_cases.mat"));
            testCase.verifyEqual(savedAgain.cases, saved.cases);
            testCase.verifyEqual(repeat.Success, cases.Success);
            stability = plotLearningCurves(cfg);
            testCase.verifyEqual(stability.TotalSteps, [6; 6]);
            testCase.verifyTrue(isfile(fullfile(cfg.resultsDir, "learning_curves.png")));
            clear cleanup;
        end
    end
end
