% Load the .mat file
load("C:\GLQN\data\small_model\overall.mat", 'combinedCell');

% Rename the variable
LQN_dataset = combinedCell;

% Save only the renamed variable
save('overall.mat', 'LQN_dataset');
