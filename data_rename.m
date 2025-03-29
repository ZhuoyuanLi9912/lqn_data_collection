% Load the .mat file
load("C:\GLQN\data\overall.mat", 'combinedCell');

% Rename the variable
LQN_dataset = combinedCell;

% Save only the renamed variable
save('yourfile.mat', 'LQN_dataset');
