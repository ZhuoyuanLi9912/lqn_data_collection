% Set path to your .mat file
matFilePath = "C:\GLQN\data\small_model\overall.mat"; % <-- Change to your actual file

% Load the .mat file
data = load(matFilePath);

% Check if 'LQN_dataset' exists
if isfield(data, 'LQN_dataset')
    full_dataset = data.LQN_dataset;
    
    % Define number of samples to extract
    n = 170000; % <-- Set your desired number of samples
    
    % Ensure n does not exceed the number of available samples
    n = min(n, numel(full_dataset));
    
    % Extract the first n samples
    LQN_dataset = full_dataset(244000:245000);
    
    
    % Save to a new .mat file with the same variable name
    save('LQN_test.mat', 'LQN_dataset');
else
    error('LQN_dataset not found in the loaded .mat file.');
end
