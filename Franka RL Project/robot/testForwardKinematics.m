function T = testForwardKinematics(robot, q, label)
if nargin < 3, label = "End-effector"; end
T = getTransform(robot, q, "panda_hand");
fprintf("\n%s joint configuration:\n", label); disp(q);
fprintf("panda_hand transform:\n"); disp(T);
fprintf("Position [m]:\n"); disp(tform2trvec(T));
fprintf("Rotation matrix:\n"); disp(tform2rotm(T));
end
