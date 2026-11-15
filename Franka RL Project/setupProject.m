function setupProject()
% Add project source, robot, training, and evaluation folders to the path.

projectRoot = fileparts(mfilename("fullpath"));
addpath(projectRoot);
addpath(fullfile(projectRoot, "src"));
addpath(fullfile(projectRoot, "robot"));
addpath(genpath(fullfile(projectRoot, "scripts")));

fprintf("Project paths added. Training, evaluation, and environment functions are ready.\n");
end
