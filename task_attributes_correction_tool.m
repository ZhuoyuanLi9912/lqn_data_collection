% Load your dataset
load("C:\GLQN\data\ser_experiment\small_model\4_6models_lqsim_lqns_GNN_input.mat");  % This should load a variable named LQN_dataset

% Iterate over the cells
for i = 1:numel(LQN_dataset)
    attrs = LQN_dataset{i}.task_attributes;
    if size(attrs, 2) == 3
        % Remove the middle column
        LQN_dataset{i}.task_attributes = attrs(:, [1, 3]);
    end
end

% Save the corrected dataset
save("C:\GLQN\data\ser_experiment\small_model\4_6models_lqsim_lqns_GNN_input.mat", 'LQN_dataset');
