function [agent, trainingStats] = trainDDPG()
% Validate the project, then train only DDPG for its full configured budget.
validateProject();
[agent, trainingStats] = trainTrackingAgent("DDPG", teamConfig());
end
