% Load the .mat file
load("C:\GLQN\GLQN experiment\lqns_lqsim.mat");  % Loads LQN_dataset

% Initialize array to hold means
numEntries = numel(LQN_dataset);
queue_means = zeros(numEntries, 1);

% Loop through the cell array and calculate the mean of queue_lengths_mare
for i = 1:numEntries
    dataStruct = LQN_dataset{i};
    if isfield(dataStruct, 'queue_lengths_mare') && ~isempty(dataStruct.queue_lengths_mare)
        queue_means(i) = mean(dataStruct.queue_lengths_mare);
    else
        queue_means(i) = NaN;
    end
end

% Remove NaNs
queue_means = queue_means(~isnan(queue_means));

% Compute statistics
median_val = median(queue_means);
percentile95 = prctile(queue_means, 95);

% Plot the CDF
figure;
cdfplot(queue_means);
xlabel('Mean of queue\_lengths\_mare');
ylabel('Cumulative Probability');
title('CDF of Mean queue\_lengths\_mare');
grid on;
hold on;

% Annotate the median and 95th percentile
xline(median_val, '--r', ['Median = ' num2str(median_val, '%.4f')], 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');
xline(percentile95, '--b', ['95% = ' num2str(percentile95, '%.4f')], 'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'right');

legend('Empirical CDF', 'Median', '95th Percentile', 'Location', 'best');
