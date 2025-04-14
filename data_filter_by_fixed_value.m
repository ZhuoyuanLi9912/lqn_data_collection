% Load the dataset
load("C:\GLQN\matlab\data\ser_exp\small_models\overall.mat");

if ~exist('LQN_dataset', 'var')
    error('LQN_dataset not found in the loaded file.');
end

% Target fields and their thresholds [min, max]
filterFields = {
    'entry_queue_lengths',       [0.001, 9.9];
    'entry_response_times',      [0.01, 300];
    'entry_throughputs',         [0.001, 0.99]
};

% Filter samples
num_LQNs = numel(LQN_dataset);
filteredList = cell(num_LQNs, 1);  % Column cell array
keepCount = 0;

for c = 1:num_LQNs
    s = LQN_dataset{c};
    discard = false;

    for i = 1:size(filterFields, 1)
        fname = filterFields{i, 1};
        range = filterFields{i, 2};

        if isfield(s, fname)
            data = s.(fname);
            if any(data < range(1)) || any(data > range(2))
                discard = true;
                break;
            end
        end
    end

    if ~discard
        keepCount = keepCount + 1;
        filteredList{keepCount} = s;  % Store into filtered list
    end
end

% Trim empty cells
LQN_dataset = filteredList(1:keepCount);

fprintf('\nRetained %d out of %d samples after applying threshold filters.\n', ...
    keepCount, num_LQNs);

% Save filtered dataset as a column cell array
save('LQN_dataset_filtered.mat', 'LQN_dataset');
fprintf('Filtered dataset saved to "LQN_dataset_filtered.mat"\n');

