% Set path to your .mat file
matFilePath = "LQN.mat"; % <-- Change to your actual file

% Load the .mat file
data = load(matFilePath);

% Check if 'LQN_dataset' exists
if isfield(data, 'LQN')
    full_dataset = data.LQN;
    
    % Define number of samples to extract

    n = 120; % <-- Set your desired number of samples

    
    % Ensure n does not exceed the number of available samples
    n = min(n, numel(full_dataset));
    
    % Extract the first n samples

    LQN = full_dataset(1:n);
    
    
    % Save to a new .mat file with the same variable name
    save('LQN_test_toy.mat', 'LQN');

else
    error('LQN_dataset not found in the loaded .mat file.');
end
