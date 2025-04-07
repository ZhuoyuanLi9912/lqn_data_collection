% Directory containing the .mat files
dataDir = "C:\GLQN\data\median_model";  

% Name of the variable inside each .mat file
varName = 'LQN_dataset';  

% Name of the output .mat file
outputFileName = 'overall.mat';

% Get list of .mat files
files = dir(fullfile(dataDir, '*.mat'));

% Initialize result cell array
LQN_dataset = {};  % Use the target variable name directly

% Loop through each file
for k = 1:length(files)
    if strcmp(files(k).name, outputFileName)
        continue;
    end
    filePath = fullfile(dataDir, files(k).name);
    
    % Load specific variable
    data = load(filePath, varName);
    
    % Concatenate into LQN_dataset
    LQN_dataset = [LQN_dataset; data.(varName)];
end

% Save using the correct variable name
save(fullfile(dataDir, outputFileName), 'LQN_dataset');
