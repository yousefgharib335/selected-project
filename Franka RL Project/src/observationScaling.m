function [scale, bias] = observationScaling(cfg)
% Fixed physical scaling, identical in actor/critics and both RL methods.
positionScale = 2 ./ (cfg.box(:, 2) - cfg.box(:, 1));
positionCenter = mean(cfg.box, 2);
scale = [ones(7, 1)/pi; positionScale; ones(3, 1)/cfg.maxTargetSpeed; ...
    ones(3, 1)/cfg.relativePositionNormalization; ones(7, 1)/cfg.maxIncrement; 2];
bias = [zeros(7, 1); -positionScale.*positionCenter; ...
    zeros(3, 1); zeros(3, 1); zeros(7, 1); -1];
end
