% Load the dataset
load("C:\GLQN\data\ser_experiment\small_model\LQN_dataset_cleaned.mat");  % <-- Replace with actual file name

if ~exist('LQN_dataset', 'var')
    error('LQN_dataset not found in the loaded file.');
end

% Target fields for filtering
filterFields = {
    'entry_queue_lengths', 
    'entry_response_times', 
    'entry_throughputs'
};

% First, gather all values for filtering
allFieldValues = struct();
for i = 1:numel(filterFields)
    allFieldValues.(filterFields{i}) = [];
end

% Collect all values across dataset
for c = 1:numel(LQN_dataset)
    s = LQN_dataset{c};
    for i = 1:numel(filterFields)
        fname = filterFields{i};
        if isfield(s, fname)
            v = s.(fname);
            if isnumeric(v) && iscolumn(v)
                allFieldValues.(fname) = [allFieldValues.(fname); v];
            end
        end
    end
end

% Calculate thresholds
thresholds = struct();
for i = 1:numel(filterFields)
    fname = filterFields{i};
    values = allFieldValues.(fname);
    thresholds.(fname).low = prctile(values, 0.5);
    thresholds.(fname).high = prctile(values, 99.5);
end

% Filter out samples with extreme values
filteredDataset = {};
for c = 1:numel(LQN_dataset)
    s = LQN_dataset{c};
    discard = false;

    for i = 1:numel(filterFields)
        fname = filterFields{i};
        if isfield(s, fname)
            data = s.(fname);
            low = thresholds.(fname).low;
            high = thresholds.(fname).high;
            if any(data < low) || any(data > high)
                discard = true;
                break;
            end
        end
    end

    if ~discard
        filteredDataset{end+1} = s; %#ok<AGROW>
    end
end

% Report retention
fprintf('\nRetained %d out of %d samples after trimming extremes.\n', ...
    numel(filteredDataset), numel(LQN_dataset));

% Save filtered dataset to new .mat file
LQN_dataset = filteredDataset;  % Overwrite variable for convenience
save('LQN_dataset_filtered.mat', 'LQN_dataset');
fprintf('Filtered dataset saved to "LQN_dataset_filtered.mat"\n');

% Analyze stats for remaining data
threshold = 1e-6;

for i = 1:numel(filterFields)
    fname = filterFields{i};
    allData = [];

    for c = 1:numel(LQN_dataset)
        s = LQN_dataset{c};
        if isfield(s, fname)
            v = s.(fname);
            if isnumeric(v) && iscolumn(v)
                allData = [allData; v];
            end
        end
    end

    if isempty(allData)
        fprintf('Field: %s -> No data remaining.\n', fname);
        continue;
    end

    % Min-max normalization
    dataMin = min(allData);
    dataMax = max(allData);
    range = dataMax - dataMin;

    if range == 0
        normData = zeros(size(allData));
    else
        normData = (allData - dataMin) / range;
    end

    belowCount = sum(normData < threshold);
    belowIdx = find(normData < threshold, 1, 'first');

    fprintf('\nField: %s (Post-filtered)\n', fname);
    fprintf('  Global Min: %.6f\n', dataMin);
    fprintf('  Global Max: %.6f\n', dataMax);
    fprintf('  Values < 1e-6: %d out of %d (%.4f%%)\n', ...
        belowCount, numel(normData), 100 * belowCount / numel(normData));
    if ~isempty(belowIdx)
        fprintf('  First index where normalized value < 1e-6: %d\n', belowIdx);
    else
        fprintf('  No values found below 1e-6.\n');
    end
end
