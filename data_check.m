% Load the dataset
load("C:\GLQN\data\ser_experiment\3_5_models\overall.mat");  % <-- Replace with your actual file

% Confirm LQN_dataset is loaded
if ~exist('LQN_dataset', 'var')
    error('LQN_dataset not found in the loaded file.');
end

% Target fields
targetFields = {
    'processor_attributes', 
    'entry_queue_lengths', 
    'entry_response_times', 
    'entry_throughputs'
};

% Initialize storage
fieldData = struct();
for i = 1:numel(targetFields)
    fieldData.(targetFields{i}) = [];
end

% Collect data from all cells
for c = 1:numel(LQN_dataset)
    s = LQN_dataset{c};
    
    for i = 1:numel(targetFields)
        fname = targetFields{i};
        
        if isfield(s, fname)
            data = s.(fname);
            
            if isnumeric(data) && iscolumn(data)
                fieldData.(fname) = [fieldData.(fname); data];
            else
                warning('Field "%s" in cell %d is not a numeric column vector, skipping.', fname, c);
            end
        else
            warning('Field "%s" not found in cell %d.', fname, c);
        end
    end
end

% Analyze each field
threshold = 1e-6;
fprintf('\n--- Normalization Summary ---\n');

for i = 1:numel(targetFields)
    fname = targetFields{i};
    data = fieldData.(fname);
    
    if isempty(data)
        fprintf('Field: %s -> No data collected.\n', fname);
        continue;
    end

    % Compute global min, max
    dataMin = min(data);
    dataMax = max(data);
    range = dataMax - dataMin;
    
    % Min-max normalization
    if range == 0
        normData = zeros(size(data));
    else
        normData = (data - dataMin) / range;
    end
    
    % Count and find index
    belowCount = sum(normData < threshold);
    totalCount = numel(normData);
    belowIdx = find(normData < threshold, 1, 'first');

    % Output
    fprintf('Field: %s\n', fname);
    fprintf('  Global Min: %.6f\n', dataMin);
    fprintf('  Global Max: %.6f\n', dataMax);
    fprintf('  Values < 1e-6: %d out of %d (%.4f%%)\n', ...
        belowCount, totalCount, 100 * belowCount / totalCount);

    if ~isempty(belowIdx)
        fprintf('  First index where normalized value < 1e-6: %d\n', belowIdx);
    else
        fprintf('  No values found below 1e-6.\n');
    end
end
