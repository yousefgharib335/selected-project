% Robot setup and FK demonstration; does not train.
setupProject();
cfg = teamConfig();
robot = loadrobot("frankaEmikaPanda", "DataFormat", "row");
showdetails(robot);
qHome = homeConfiguration(robot);
qHome(8:9) = 0.04;
% Display the starter's ready pose instead of the colliding model default.
qReady = [0 -0.785 0 -2.356 0 1.571 0.785 0.04 0.04];
rng(cfg.validationSeed, "twister");
[~, model] = createTrackingEnvironment(cfg);
qStart = model.q;
[homeColliding, homeDistances] = checkCollision(robot, qHome, ...
    "SkippedSelfCollisions", model.skippedSelfCollisionPairs, "Exhaustive", "on");
startColliding = checkCollision(robot, qStart, ...
    "SkippedSelfCollisions", model.skippedSelfCollisionPairs, "Exhaustive", "on");
readyColliding = checkCollision(robot, qReady, ...
    "SkippedSelfCollisions", model.skippedSelfCollisionPairs, "Exhaustive", "on");
assert(~readyColliding && model.isJointStateValid(qReady(1:7)), ...
    "The displayed ready pose must be collision-free and within joint limits.");
assert(~startColliding && model.isJointStateValid(qStart(1:7)), ...
    "The task-start pose must be collision-free and within joint limits.");
fprintf("\nModel home self-collision: %d (console FK reference only; not displayed).\n", homeColliding);
fprintf("Starter ready self-collision: %d (Figure 1).\n", readyColliding);
fprintf("Task-start self-collision: %d\n", startColliding);
if homeColliding
    bodyNames = [robot.BodyNames {robot.BaseName}];
    [first, second] = find(triu(isnan(homeDistances), 1));
    for pair = 1:numel(first)
        fprintf("  Home collision: %s <-> %s\n", ...
            bodyNames{first(pair)}, bodyNames{second(pair)});
    end
end
figure("Name", "Collision-free starter ready pose");
show(robot, qReady, "Frames", "off");
title("Starter ready pose: collision-free and within joint limits");
axis equal; xlim([-0.3 0.8]); ylim([-0.6 0.6]); zlim([0 1]); view(135, 25);
figure("Name", "Validated task start");
show(robot, qStart, "Frames", "off");
title("Task start: collision-free and within joint limits");
axis equal; xlim([-0.3 0.8]); ylim([-0.6 0.6]); zlim([0 1]); view(135, 25);
testForwardKinematics(robot, qHome, "Model default home (console reference)");
testForwardKinematics(robot, qReady, "Starter ready (Figure 1)");
testForwardKinematics(robot, qStart, "Task start");
fprintf("End-effector: panda_hand. Run validateProject before training.\n");
