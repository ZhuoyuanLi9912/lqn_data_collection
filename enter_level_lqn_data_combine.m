% Directory containing the .mat files
dataDir = "C:\GLQN\data";  

% Name of the variable inside each .mat file
varName = 'LQN_dataset';  

% Name of the output .mat file
outputFileName = 'overall.mat';

% Get list of .mat files
files = dir(fullfile(dataDir, '*.mat'));

% Initialize result cell array
combinedCell = {};

% Loop through each file
for k = 1:length(files)
    if strcmp(files(k).name, outputFileName)
        continue;
    end
    filePath = fullfile(dataDir, files(k).name);
    
    % Load specific variable
    data = load(filePath, varName);
    
    % Concatenate
    combinedCell = [combinedCell; data.(varName)];
end

% Save the combined cell array back to the same folder
save(fullfile(dataDir, outputFileName), 'combinedCell');
