% Set path to your .mat file
matFilePath = "C:\GLQN\matlab\data\small_lqsim\overall_2_60000samples.mat"; % <-- Change to your actual file

% Load the .mat file
data = load(matFilePath);

% Check if 'LQN_dataset' exists
if isfield(data, 'LQN_dataset')
    full_dataset = data.LQN_dataset;
    
    % Define number of samples to extract
    n = 1000; % <-- Set your desired number of samples
    
    % Ensure n does not exceed the number of available samples
    n = min(n, numel(full_dataset));
    
    % Extract the first n samples
    LQN_dataset = full_dataset(55000:60000);
    
    
    % Save to a new .mat file with the same variable name
    save('LQN_dataset_testset.mat', 'LQN_dataset');
else
    error('LQN_dataset not found in the loaded .mat file.');
end
