function [agent, trainingStats] = trainTD3()
% Validate the project, then train only TD3 for its full configured budget.
validateProject();
[agent, trainingStats] = trainTrackingAgent("TD3", teamConfig());
end
