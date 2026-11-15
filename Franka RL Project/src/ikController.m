function action = ikController(~, model, solver)
% IK belongs exclusively in the conventional baseline, never in RL training.
desired = eye(4);
desired(1:3, 4) = model.targetStart + ...
    model.targetVelocity * ((model.stepCount + 1) * model.dt);
[solution, ~] = solver(model.EndEffectorName, desired, ...
    [0 0 0 1 1 1], model.q);
increment = solution(1:7).' - model.q(1:7).';
action = min(max(increment, -model.maxJointStep), model.maxJointStep);
end
