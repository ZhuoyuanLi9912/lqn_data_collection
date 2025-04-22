results = parse_csv_file();
LQN = simulate_lqn_lqns(results);
save('LQN_dataset_test.mat', 'LQN');
function results = parse_csv_file()
    % Load Sobol sample CSV
    sobol = readmatrix("C:\Users\lizhu\OneDrive - Imperial College London\TEMP\sampling_data\chunk_001.csv"); % Update path if needed
    
    % Load weight lookup table
    lookup = readmatrix("C:\Users\lizhu\OneDrive - Imperial College London\TEMP\custom_balanced_pattern.csv");


    % Struct template with all fields
    template = struct( ...
        'processor_count', zeros(1, 0), ...
        'tasks_per_proc',  zeros(1, 0), ...
        'multiplicity',    zeros(1, 0), ...
        'think_time',      zeros(1, 0), ...
        'entries_per_task',zeros(1, 0), ...
        'pattern_ids',     zeros(1, 0), ...
        'calls_per_entry', zeros(1, 0), ...
        'probabilities',   {cell(1, 0)}, ...
        'service_times',   zeros(1, 0) ...
    );

    results(1:size(sobol, 1)) = template;

    % Loop over each row (sample)
    for i = 1:size(sobol, 1)
        row = sobol(i, :);
        idx = 1;
    
        % 1. Processor count
        processor_count = row(idx);
        idx = idx + 1;
    
        % 2. Tasks per processor (only first 'processor_count')
        tasks_per_proc = row(idx:idx+processor_count-1);
        idx = idx + 8;
    
        % 3. Task multiplicity and think time (only first 'total_tasks')
        total_tasks = sum(tasks_per_proc);
        multiplicity = row(idx:2:idx + 2*total_tasks - 1);
        think_time = row(idx+1:2:idx + 2*total_tasks - 1);
        idx = idx + 64;
    
        % 4. Entries per task (only first 'total_tasks')
        entries_per_task = row(idx:idx+total_tasks-1);
        idx = idx + 32;
    
        % 5. Total number of entries
        num_entries = sum(entries_per_task);
    
        % 6. Skip activities per entry
        idx = idx + 128;
    
        % 7. Service time start index
        num_of_last_layer_entry = sum(entries_per_task(end - tasks_per_proc(end) + 1 : end));
    
        % 8. Pattern selectors (only first 'num_entries')
        pattern_ids = row(idx+640 : idx+640+num_entries-1);
    
        % 9. Analyze pattern IDs
        calls_per_entry = zeros(1, num_entries);
        probabilities = cell(1, num_entries);
        
        for e = 1:num_entries-num_of_last_layer_entry
            pid = pattern_ids(e);  % Now this is just a row index
            if pid >= 1 && pid <= size(lookup, 1)
                weights = lookup(pid, :);  % Just get the row directly
            else
                weights = zeros(1, size(lookup, 2));  % fallback to all zeros
            end
        
            nonzero = weights > 0;
            calls_per_entry(e) = sum(nonzero);
            % Find the last non-zero element
            last_nonzero = find(weights ~= 0, 1, 'last');
            
            % Trim the array
            if isempty(last_nonzero)
                trimmed_weights = [];  % All zeros
            else
                trimmed_weights = weights(1:last_nonzero);
            end
            probabilities{e} = trimmed_weights;
        end

    
        % 10. Extract service times
        service_times = row(234:873);
        call_times = row(1002:1385);
    
        % 11. Store into result struct
        results(i).processor_count = processor_count;
        results(i).tasks_per_proc = tasks_per_proc;
        results(i).multiplicity = multiplicity;
        results(i).think_time = think_time;
        results(i).entries_per_task = entries_per_task;
        results(i).pattern_ids = pattern_ids;
        results(i).calls_per_entry = calls_per_entry;
        results(i).probabilities = probabilities;
        results(i).service_times = service_times;
        results(i).call_times = call_times;
    end
end

% Example: display first result
r = results(1);  % Store into a temporary variable
disp(r);

function LQN = simulate_lqn_lqns(results)
    % Simulate the LQN and extract metrics for each entry using LQNS
    %
    % Args:
    %   LQN (struct): The LQN model
    %
    % Returns:
    %   entry_metrics (struct): Struct containing queue lengths, response times, and throughputs for each entry

    % Create the LayeredNetwork model
    template = struct( ...
        'task_attributes',                       zeros(0, 2), ...
        'task_on_processor_edges',              zeros(2, 0), ...
        'entry_on_task_edges',                  zeros(2, 0), ...
        'activity_attributes',                  zeros(0, 1), ...
        'activity_on_entry_edges',              zeros(2, 0), ...
        'activity_activity_edges',              zeros(2, 0), ...
        'activity_activity_edge_attributes',    zeros(0, 1), ...
        'activity_call_entry_edges',            zeros(2, 0), ...
        'activity_call_entry_edge_attributes',  zeros(0, 1), ...
        'entry_queue_lengths',                  zeros(0, 1), ...
        'entry_response_times',                 zeros(0, 1), ...
        'entry_throughputs',                    zeros(0, 1) ...
    );
    N = size(results, 2);
    LQN(1:N) = template;
    for n = 1:N
        result = results(n);
        num_of_processor = result.processor_count;
        num_of_task = size(result.multiplicity,2);
        num_of_entry = size(result.pattern_ids,2);
        
        task_attributes = zeros(num_of_task, 2);
        task_on_processor_edges = zeros(2,num_of_task);
        entry_on_task_edges = zeros(2,num_of_entry);



        model = LayeredNetwork('LQN');
    
        % Step 1: Create processors, tasks, and entries (no calls yet)
        processors = cell(result.processor_count, 1);
        tasks = cell(sum(result.tasks_per_proc), 1);
        entries = cell(sum(result.entries_per_task), 1);
        activities = cell(size(result.service_times, 1), 1); % Store primary activities
    
        % Create processors
        for i = 1:num_of_processor
            processors{i} = Processor(model, ['P', num2str(i)], 1, SchedStrategy.PS);
        end
        task_index = 0;
        % Create tasks
        for i = 1:num_of_processor
            for j = 1:result.tasks_per_proc(i)
                task_index = task_index+1;
                multiplicity = result.multiplicity(task_index);
                think_time = result.think_time(task_index);
                task_attributes(task_index,:) = [multiplicity,round(think_time,1)];
                if i == 1
                    sched_strategy = SchedStrategy.REF; % First processor
                else
                    sched_strategy = SchedStrategy.FCFS; % Other processors
                end
                tasks{task_index} = Task(model, ['T', num2str(task_index)], multiplicity, sched_strategy).on(processors{i});
                tasks{task_index}.setThinkTime(Exp.fitMean(round(think_time,1)));
                task_on_processor_edges(:,task_index) = [task_index;i];
            end
        end
        entry_index = 0;
        activity_index = 0;
        % Create entries
        for i = 1:num_of_task
            for j = 1:result.entries_per_task(i)
                entry_index = entry_index+1;
                entries{entry_index} = Entry(model, ['E', num2str(entry_index)]).on(tasks{i});
                entry_on_task_edges(:,entry_index) = [entry_index;i];
                
            end
        end

        % Build fast task-to-processor lookup array
        max_task = max(task_on_processor_edges(1, :));
        task_to_proc = zeros(1, max_task);
        task_to_proc(task_on_processor_edges(1, :)) = task_on_processor_edges(2, :);
        
        % Create entry-to-processor edge matrix
        entry_indices = entry_on_task_edges(1, :);
        task_indices = entry_on_task_edges(2, :);
        processor_indices = task_to_proc(task_indices);
        
        entry_to_processor_edges = [
            entry_indices;
            processor_indices
        ];
        for i = 1:result.processor_count-1
            current_layer_entries = entry_to_processor_edges(1, entry_to_processor_edges(2,:) == i);
            next_layer_entries = entry_to_processor_edges(1, entry_to_processor_edges(2,:) == i+1);
            for e = 1:length(current_layer_entries)
                max_calls = length(next_layer_entries);
                current_calls = result.calls_per_entry(current_layer_entries(e));
            
                if current_calls > max_calls
                    % Trim number of calls
                    result.calls_per_entry(current_layer_entries(e)) = max_calls;
            
                    % Fix probabilities
                    probs = result.probabilities{current_layer_entries(e)};  % 1×original_calls vector
            
                    % Combine the tail into the last allowed slot
                    trimmed_probs = probs(1:max_calls);
                    trimmed_probs(end) = trimmed_probs(end) + sum(probs(max_calls+1:end));
            
                    % Save back
                    result.probabilities{current_layer_entries(e)} = trimmed_probs;
                end
            end
            while sum(result.calls_per_entry(current_layer_entries)) < length(next_layer_entries)
                % Find the entry in current_layer_entries with the least calls
                [~, idx] = min(result.calls_per_entry(current_layer_entries));
                entry = current_layer_entries(idx);
            
                % Increase call count
                result.calls_per_entry(entry) = result.calls_per_entry(entry) + 1;
            
                % Get current probabilities
                probs = result.probabilities{entry};
            
                % Find index of largest probability
                [~, max_idx] = max(probs);
            
                % Reduce it by 0.1 and append a new 0.1 probability
                probs(max_idx) = probs(max_idx) - 0.1;
                probs(end+1) = 0.1;
            
                % Save back
                result.probabilities{entry} = probs;
            end            
        end
        
        
        %creat activities
        num_of_calls = sum(result.calls_per_entry);
        num_of_activity = num_of_entry+num_of_calls;

        if length(result.service_times) < num_of_activity
            shortfall = num_of_activity - length(result.service_times);
            fill_vals = result.service_times(randi(length(result.service_times), 1, shortfall));
            result.service_times(end+1 : num_of_activity) = fill_vals;
        end
        activity_attributes = zeros(num_of_activity,1);
        activity_on_entry_edges = zeros(2,num_of_activity);
        activity_activity_edges = zeros(2,num_of_calls);
        activity_activity_edge_attributes = zeros(num_of_calls,1);
        activity_call_entry_edges = zeros(2,num_of_calls);
        activity_call_entry_edge_attributes = zeros(num_of_calls,1);
        if_called = zeros(1,num_of_entry);
        call_index = 0;
        for i = 1:num_of_entry
            parent_task_index = entry_on_task_edges(2, find(entry_on_task_edges(1,:) == i, 1));
            activity_index = activity_index+1;
            % Create primary activity for this entry
            activities{activity_index} = Activity(model, ['A', num2str(activity_index)], Exp.fitMean(round(result.service_times(activity_index),1))) ...
                .on(tasks{parent_task_index}).boundTo(entries{i});
            activity_attributes(activity_index) = round(result.service_times(activity_index),1);
            activity_on_entry_edges(:,activity_index)=[activity_index;i];
            % Check if this entry makes any calls
            if result.calls_per_entry(i)>0
                current_processor = entry_to_processor_edges(2, find(entry_to_processor_edges(1,:) == i, 1));
                next_layer_entries = entry_to_processor_edges(1, entry_to_processor_edges(2,:) == current_processor + 1);
                for c = 1:result.calls_per_entry(i)
                    subset = if_called(next_layer_entries);
                    if all(subset == 1)
                        selected = next_layer_entries(randi(length(next_layer_entries)));  % random pick
                    else
                        idx = find(subset ~= 1, 1);                   % first not-1
                        selected = next_layer_entries(idx);           % map back to entry index
                        if_called(selected) = 1;                      % mark it as called
                    end
                    activity_index = activity_index+1;
                    call_index = call_index+1;
                    activities{activity_index} = Activity(model, ['A', num2str(activity_index)], Exp.fitMean(round(result.service_times(activity_index),1))) ...
                            .on(tasks{parent_task_index}).synchCall(entries{selected}, round(result.call_times(call_index),1));
                    activity_attributes(activity_index) = round(result.service_times(activity_index),1);
                    activity_on_entry_edges(:,activity_index)=[activity_index;i];
                    activity_call_entry_edges(:,call_index)=[activity_index;selected];
                    activity_call_entry_edge_attributes(call_index)=round(result.call_times(call_index),1);
                    activity_activity_edges(:,call_index) = [activity_on_entry_edges(1, find(activity_on_entry_edges(2,:) == i, 1));activity_index];
                    activity_activity_edge_attributes(call_index) = result.probabilities{i}(c);
                    if current_processor ~=1
                        activities{activity_index}.repliesTo(entries{i});
                    end
                end
                if isscalar(result.probabilities{i})
                    tasks{parent_task_index}.addPrecedence(ActivityPrecedence.Serial(activities{activity_on_entry_edges(1, find(activity_on_entry_edges(2,:) == i, 1))}, activities{activity_index}));
                else
                    target_activities = activities(activity_index - size(result.probabilities{i},2) + 1 : activity_index);
                    tasks{parent_task_index}.addPrecedence(ActivityPrecedence.OrFork(activities{activity_on_entry_edges(1, find(activity_on_entry_edges(2,:) == i, 1))}, target_activities, round(result.probabilities{i}, 1)));
                end
            else
                activities{activity_index}.repliesTo(entries{i});
            end
        end

        % Number of replications
        num_runs = 1;
        
        % Get model structure sizes
        num_processors = size(LQN.processor_attributes, 1);
        num_tasks = size(LQN.task_attributes, 1);
        num_entries = size(LQN.entry_attributes, 1);
        
        % Preallocate result matrices
        all_queue_lengths = zeros(num_entries, num_runs);
        all_response_times = zeros(num_entries, num_runs);
        all_throughputs = zeros(num_entries, num_runs);
        
        % Run the simulation multiple times
        for i = 1:num_runs
            % Create and configure solver using LQSIM
            options = SolverLQNS.defaultOptions;
            options.method = 'lqsim';
            solver = SolverLQNS(model, options);
        
            % Run simulation and extract results
            avg_table = solver.getAvgTable();
        
            % Extract entry rows
            entry_start_row = num_processors + num_tasks + 1;
            entry_end_row = entry_start_row + num_entries - 1;
            entry_rows = avg_table(entry_start_row:entry_end_row, :);
        
            % Store metrics
            all_queue_lengths(:, i) = table2array(entry_rows(:, 3));   % Queue lengths
            all_response_times(:, i) = table2array(entry_rows(:, 5));  % Response times
            all_throughputs(:, i) = table2array(entry_rows(:, 7));     % Throughputs
        end
        
        % Compute averages across replications
        mean_queue_lengths = mean(all_queue_lengths, 2);
        mean_response_times = mean(all_response_times, 2);
        mean_throughputs = mean(all_throughputs, 2);
        LQN(n).task_attributes                      = task_attributes;
        LQN(n).task_on_processor_edges             = task_on_processor_edges;
        LQN(n).entry_on_task_edges                 = entry_on_task_edges;
        LQN(n).activity_attributes                 = activity_attributes;
        LQN(n).activity_on_entry_edges             = activity_on_entry_edges;
        LQN(n).activity_activity_edges             = activity_activity_edges;
        LQN(n).activity_activity_edge_attributes   = activity_activity_edge_attributes;
        LQN(n).activity_call_entry_edges           = activity_call_entry_edges;
        LQN(n).activity_call_entry_edge_attributes = activity_call_entry_edge_attributes;
        LQN(n).entry_queue_lengths                 = mean_queue_lengths;
        LQN(n).entry_response_times                = mean_response_times;
        LQN(n).entry_throughputs                   = mean_throughputs;
    end
end


