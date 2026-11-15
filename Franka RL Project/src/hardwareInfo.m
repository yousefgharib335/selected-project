function info = hardwareInfo()
if ispc
    [status, cpu] = system('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name"');
elseif ismac
    [status, cpu] = system('sysctl -n machdep.cpu.brand_string');
else
    status = 1;
    cpu = "";
    if isfile("/proc/cpuinfo")
        model = regexp(fileread("/proc/cpuinfo"), ...
            "(?m)^model name\s*:\s*([^\r\n]+)", "tokens", "once");
        if ~isempty(model)
            cpu = model{1};
            status = 0;
        end
    end
end
if status ~= 0 || strlength(strtrim(cpu)) == 0
    cpu = computer;
end
info = struct("computer", computer, "cpu", strtrim(cpu), ...
    "matlab", version, "toolboxes", ver, "trainingDevice", "CPU", ...
    "computeThreads", maxNumCompThreads);
end
