function agent = makeAgent(algorithm, env, cfg)
% Both deterministic actors and all critics start with two 128-unit ReLU layers.
algorithm = upper(string(algorithm));
assert(any(algorithm == ["TD3", "DDPG"]), "Choose TD3 or DDPG.");
obs = getObservationInfo(env);
act = getActionInfo(env);
[observationScale, observationBias] = observationScaling(cfg);
layers = [featureInputLayer(obs.Dimension(1), Name="observation")
    scalingLayer(Name="actor_normalize", Scale=observationScale, Bias=observationBias)
    fullyConnectedLayer(cfg.hiddenUnits, Name="actor_fc1")
    reluLayer(Name="actor_relu1")
    fullyConnectedLayer(cfg.hiddenUnits, Name="actor_fc2")
    reluLayer(Name="actor_relu2")
    fullyConnectedLayer(7, Name="actor_output", ...
        WeightsInitializer="zeros", BiasInitializer="zeros")
    tanhLayer(Name="actor_tanh")
    scalingLayer(Name="actor_scale", Scale=cfg.maxIncrement)];
actor = rlContinuousDeterministicActor(dlnetwork(layers), obs, act);
c1 = critic("critic1");
if algorithm == "TD3"
    agent = rlTD3Agent(actor, [c1 critic("critic2")]);
    agent.AgentOptions.ExplorationModel.StandardDeviationMin = cfg.explorationStdMin;
    agent.AgentOptions.ExplorationModel.StandardDeviation = cfg.explorationStd;
    agent.AgentOptions.ExplorationModel.StandardDeviationDecayRate = 1e-5;
    agent.AgentOptions.TargetPolicySmoothModel.StandardDeviationMin = 0.001;
    agent.AgentOptions.TargetPolicySmoothModel.StandardDeviation = 0.001;
    agent.AgentOptions.TargetPolicySmoothModel.LowerLimit = -0.002;
    agent.AgentOptions.TargetPolicySmoothModel.UpperLimit = 0.002;
    agent.AgentOptions.PolicyUpdateFrequency = cfg.td3PolicyUpdateFrequency;
    agent.AgentOptions.TargetUpdateFrequency = 2;
else
    options = rlDDPGAgentOptions;
    options.NoiseOptions = rl.option.GaussianActionNoise;
    options.NoiseOptions.StandardDeviationMin = cfg.explorationStdMin;
    options.NoiseOptions.StandardDeviation = cfg.explorationStd;
    options.NoiseOptions.StandardDeviationDecayRate = 1e-5;
    agent = rlDDPGAgent(actor, c1, options);
end
agent.AgentOptions.SampleTime = cfg.dt;
agent.AgentOptions.DiscountFactor = cfg.discountFactor;
agent.AgentOptions.ExperienceBufferLength = 1e6;
agent.AgentOptions.MiniBatchSize = cfg.miniBatchSize;
agent.AgentOptions.NumWarmStartSteps = cfg.warmStartSteps;
agent.AgentOptions.LearningFrequency = cfg.learningFrequency;
agent.AgentOptions.MaxMiniBatchPerEpoch = cfg.maxMiniBatchPerEpoch;
agent.AgentOptions.NumEpoch = 1;
agent.AgentOptions.TargetSmoothFactor = 5e-3;
agent.AgentOptions.ActorOptimizerOptions.LearnRate = cfg.actorLearnRate;
agent.AgentOptions.ActorOptimizerOptions.GradientThreshold = cfg.gradientThreshold;
for index = 1:numel(agent.AgentOptions.CriticOptimizerOptions)
    agent.AgentOptions.CriticOptimizerOptions(index).LearnRate = cfg.criticLearnRate;
    agent.AgentOptions.CriticOptimizerOptions(index).GradientThreshold = cfg.gradientThreshold;
end

    function value = critic(prefix)
        outputLayer = fullyConnectedLayer(1, Name=prefix+"_q");
        if isfinite(cfg.criticInitialValue)
            initialValue = cfg.criticInitialValue;
            outputLayer.WeightsInitializer = "zeros";
            outputLayer.BiasInitializer = @(sz) initialValue * ones(sz, "single");
        end
        g = layerGraph;
        g = addLayers(g, featureInputLayer(obs.Dimension(1), Name=prefix+"_obs"));
        g = addLayers(g, featureInputLayer(7, Name=prefix+"_act"));
        g = addLayers(g, scalingLayer(Name=prefix+"_obs_normalize", ...
            Scale=observationScale, Bias=observationBias));
        g = addLayers(g, scalingLayer(Name=prefix+"_act_normalize", Scale=1/cfg.maxIncrement));
        g = addLayers(g, [concatenationLayer(1, 2, Name=prefix+"_cat")
            fullyConnectedLayer(cfg.hiddenUnits, Name=prefix+"_fc1")
            reluLayer(Name=prefix+"_relu1")
            fullyConnectedLayer(cfg.hiddenUnits, Name=prefix+"_fc2")
            reluLayer(Name=prefix+"_relu2")
            outputLayer]);
        g = connectLayers(g, prefix+"_obs", prefix+"_obs_normalize");
        g = connectLayers(g, prefix+"_obs_normalize", prefix+"_cat/in1");
        g = connectLayers(g, prefix+"_act", prefix+"_act_normalize");
        g = connectLayers(g, prefix+"_act_normalize", prefix+"_cat/in2");
        value = rlQValueFunction(dlnetwork(g), obs, act, ...
            ObservationInputNames=prefix+"_obs", ActionInputNames=prefix+"_act");
    end
end
