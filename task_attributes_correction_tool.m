% Load your dataset
load("C:\GLQN\data\ser_experiment\small_model\overall.mat");  % This should load a variable named LQN_dataset

% Iterate over the cells
for i = 1:numel(LQN_dataset)
    attrs = LQN_dataset{i}.task_attributes;
    if size(attrs, 2) == 3
        % Remove the middle column
        LQN_dataset{i}.task_attributes = attrs(:, [1, 3]);
    end
end

% Save the corrected dataset
save('LQN_dataset_cleaned.mat', 'LQN_dataset');
