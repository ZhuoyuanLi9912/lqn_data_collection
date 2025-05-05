% combine_LQN_structs.m
% Adjust 'dataFolder' to your folder containing the .mat files.

dataFolder = "C:\Users\lizhu\OneDrive - Imperial College London\datafile\Sobol_samller\lqn_data";
outFile    = fullfile(dataFolder, 'CombinedLQN.mat');

% 1. Find all .mat files
files = dir(fullfile(dataFolder, '*.mat'));

allLQN = [];  % will grow to 1 x N_combined

for f = 1:numel(files)
    S = load(fullfile(dataFolder, files(f).name), 'LQN');
    if ~isfield(S, 'LQN')
        warning('File %s has no LQN variable – skipping.', files(f).name);
        continue;
    end
    % 2. Concatenate
    allLQN = [allLQN, S.LQN];  %#ok<AGROW>
end

% 3. Remove entirely empty structs
isEmptyStruct = false(1, numel(allLQN));
for k = 1:numel(allLQN)
    fn = fieldnames(allLQN);
    emptyFlags = cellfun(@(f) isempty(allLQN(k).(f)), fn);
    isEmptyStruct(k) = all(emptyFlags);
end
allLQN(isEmptyStruct) = [];

% 4. Remove structs with NaNs in entry_queue_lengths or entry_response_times
hasNaN = false(1, numel(allLQN));
for k = 1:numel(allLQN)
    eql = allLQN(k).entry_queue_lengths;
    ert = allLQN(k).entry_response_times;
    if any(isnan(eql(:))) || any(isnan(ert(:)))
        hasNaN(k) = true;
    end
end
allLQN(hasNaN) = [];

isOutOfBounds = false(1, numel(allLQN));
for k = 1:numel(allLQN)
    eql = allLQN(k).entry_queue_lengths(:);
    ert = allLQN(k).entry_response_times(:);
    thp = allLQN(k).entry_throughputs(:);
    
    % any queue length < 0.001?
    cond1 = any(eql < 0.001);
    % any response time < 0.001 or > 500?
    cond2 = any(ert < 0.001) || any(ert > 500);
    % any throughput < 0.001 or > 0.99?
    cond3 = any(thp < 0.001) || any(thp > 0.99);
    
    if cond1 || cond2 || cond3
        isOutOfBounds(k) = true;
    end
end

% Remove them
allLQN(isOutOfBounds) = [];

% 5. Save the cleaned, combined array
LQN = allLQN; %#ok<NASGU>
save(outFile, 'LQN');
fprintf('Saved combined and cleaned LQN array (%d elements) to:\n  %s\n', numel(LQN), outFile);

% --- after saving CombinedLQN.mat, replace the old “gather vectors” block with this ---

% 6. Gather and flatten all values for plotting
eql_cells = arrayfun(@(s) s.entry_queue_lengths(:), LQN, 'UniformOutput', false);
all_eql   = vertcat(eql_cells{:});          % [M×1] vector of all queue lengths

ert_cells = arrayfun(@(s) s.entry_response_times(:), LQN, 'UniformOutput', false);
all_ert   = vertcat(ert_cells{:});          % [N×1] vector of all response times

thp_cells = arrayfun(@(s) s.entry_throughputs(:), LQN, 'UniformOutput', false);
all_thp   = vertcat(thp_cells{:});          % [P×1] vector of all throughputs

% Plot distributions
figure;
subplot(3,1,1);
histogram(all_eql);
xlabel('Entry Queue Length');
ylabel('Count');
title('Distribution of Entry Queue Lengths');

subplot(3,1,2);
histogram(all_ert);
xlabel('Entry Response Time');
ylabel('Count');
title('Distribution of Entry Response Times');

subplot(3,1,3);
histogram(all_thp);
xlabel('Entry Throughput');
ylabel('Count');
title('Distribution of Entry Throughputs');

% 7. Compute and print global min/max
fprintf('\nStatistics:\n');
fprintf('Entry Queue Lengths:   min = %.3g, max = %.3g\n', min(all_eql), max(all_eql));
fprintf('Entry Response Times:  min = %.3g, max = %.3g\n', min(all_ert), max(all_ert));
fprintf('Entry Throughputs:     min = %.3g, max = %.3g\n', min(all_thp), max(all_thp));

