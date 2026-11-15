function results = validateProject()
cfg = teamConfig();
if ~isfolder(cfg.resultsDir), mkdir(cfg.resultsDir); end
results = runtests(fullfile(cfg.projectRoot, "tests"));
save(fullfile(cfg.resultsDir, "validation.mat"), "results");
resultTable = table(string({results.Name}).', [results.Passed].', ...
    [results.Failed].', [results.Incomplete].', [results.Duration].', ...
    VariableNames=["Name", "Passed", "Failed", "Incomplete", "Duration"]);
writetable(resultTable, fullfile(cfg.resultsDir, "validation.csv"));
assertSuccess(results);
end
