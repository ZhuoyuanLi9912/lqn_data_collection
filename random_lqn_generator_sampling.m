results = parse_csv_file();
function results = parse_csv_file()
    % Load Sobol sample CSV
    sobol = readmatrix("C:\Users\lizhu\OneDrive - Imperial College London\TEMP\sampling_data\chunk_01.csv"); % Update path if needed
    
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
        service_time_start_idx = idx;
    
        % 8. Pattern selectors (only first 'num_entries')
        pattern_ids = row(idx+640 : idx+640+num_entries-1);
    
        % 9. Analyze pattern IDs
        num_service_times_needed = 0;
        calls_per_entry = zeros(1, num_entries);
        probabilities = cell(1, num_entries);

        for e = 1:num_entries
            pid = pattern_ids(e);  % Now this is just a row index
            if pid >= 1 && pid <= size(lookup, 1)
                weights = lookup(pid, :);  % Just get the row directly
            else
                weights = zeros(1, size(lookup, 2));  % fallback to all zeros
            end
        
            nonzero = weights > 0;
            calls_per_entry(e) = sum(nonzero);
            probabilities{e} = weights;
            num_service_times_needed = num_service_times_needed + calls_per_entry(e)+1;
        end

    
        % 10. Extract service times
        service_times = row(service_time_start_idx : service_time_start_idx + num_service_times_needed - 1);
    
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
        'activity_attributes',                  zeros(0, 2), ...
        'activity_on_entry_edges',              zeros(2, 0), ...
        'activity_activity_edges',              zeros(2, 0), ...
        'activity_activity_edge_attributes',    zeros(0, 2), ...
        'activity_call_entry_edges',            zeros(2, 0), ...
        'activity_call_entry_edge_attributes',  zeros(0, 2), ...
        'entry_queue_lengths',                  zeros(0, 1), ...
        'entry_response_times',                 zeros(0, 1), ...
        'entry_throughputs',                    zeros(0, 1) ...
    );
    N = size(results, 2);
    LQN(1:N) = template;
    for n = 1:N
        result = results(i);
        num_of_processor = result.processor_count;
        num_of_task = size(result.multiplicity,2);
        num_of_entry = size(result.pattern_ids,2);
        num_of_activity = size(result.service_times,2);
        num_of_calls = num_of_activity - num_of_entry;
        task_attributes = zeros(num_of_task, 2);
        task_on_processor_edges = zeros(2,num_of_task);
        entry_on_task_edges = zeros(2,num_of_entry);
        activity_attributes = zeros(num_of_activity,1);
        activity_on_entry_edges = zeros(2,num_of_activity);
        activity_activity_edges = zeros(2,num_of_calls);
        activity_activity_edge_attributes = zeros(num_of_calls,1);
        activity_call_entry_edges = zeros(2,num_of_calls);
        activity_call_entry_edge_attributes = zeros(num_of_calls,1);

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
                task_attributes(task_index,:) = [multiplicity,think_time];
                if i == 1
                    sched_strategy = SchedStrategy.REF; % First processor
                else
                    sched_strategy = SchedStrategy.FCFS; % Other processors
                end
                tasks{task_index} = Task(model, ['T', num2str(task_index)], multiplicity, sched_strategy).on(processors{i});
                tasks{task_index}.setThinkTime(Exp.fitMean(think_time));
                task_on_processor_edges(:,task_index) = [task_index;i];
            end
        end
        entry_index = 0;
        activity_index = 0;
        % Create entries and their primary activities
        for i = 1:num_of_task
            for j = 1:result.entries_per_task(i)
                entry_index = entry_index+1;
                activity_index = activity_index+1;
                entries{entry_index} = Entry(model, ['E', num2str(entry_index)]).on(tasks{i});
                % Create primary activity for this entry
                activities{activity_index} = Activity(model, ['A', num2str(activity_index)], Exp.fitMean(result.service_times(activity_index))) ...
                    .on(tasks{i}).boundTo(entries{entry_index});
                activity_attributes(activity_index) = result.service_times(activity_index);
                entry_on_task_edges(:,entry_index) = [entry_index;i];
                activity_on_entry_edges(:,activity_index)=[activity_index;entry_index];
            end
        end
    
        for i = 1:size(LQN.entry_attributes, 1)
            % Check if this entry makes any calls
            outgoing_call_indices = find(LQN.entry_call_entry_edges(1, :) == i); % Find all calls originating from this entry
            task_id = LQN.entry_on_task_edges(2, i); % Get task ID for this entry
            is_top_layer_task = (LQN.task_on_processor_edges(2, task_id) == 1); % Check if this task is on the top layer
    
            if isempty(outgoing_call_indices) % Bottom layer: no calls
                activities{i}.repliesTo(entries{i});
            else
                % This entry makes calls: create call activities and an OrFork
                target_activities = {};
                probabilities = [];
                call_activity{i} = cell(length(outgoing_call_indices), 1); % Initialize call activities for this entry
    
                for j = 1:length(outgoing_call_indices)
                    call_index = outgoing_call_indices(j);
                    target_entry = LQN.entry_call_entry_edges(2, call_index); % Target entry index
                    probability = LQN.entry_call_entry_edge_attributes(call_index, 1); % Call probability
                    mean_number_of_calls = LQN.entry_call_entry_edge_attributes(call_index, 2); % Mean number of calls
                    mean_call_time = LQN.entry_call_entry_edge_attributes(call_index, 3); % Mean call time
                    scv_call_time = LQN.entry_call_entry_edge_attributes(call_index, 4); % SCV of call time
    
                    % Create a call activity with a unique name and appropriate attributes
                    call_name = ['Call', num2str(global_call_counter)];
                    if is_top_layer_task
                        % Do not include repliesTo for top-layer tasks
                        call_activity{i}{j} = Activity(model, call_name, APH.fitMeanAndSCV(mean_call_time, scv_call_time)) ...
                            .on(tasks{task_id}).synchCall(entries{target_entry}, mean_number_of_calls);
                    else
                        % Include repliesTo for other tasks
                        call_activity{i}{j} = Activity(model, call_name, APH.fitMeanAndSCV(mean_call_time, scv_call_time)) ...
                            .on(tasks{task_id}).synchCall(entries{target_entry}, mean_number_of_calls).repliesTo(entries{i});
                    end
    
                    % Increment the global call counter
                    global_call_counter = global_call_counter + 1;
    
                    % Store the call activity and its probability
                    target_activities{end + 1} = call_activity{i}{j}; % Add to target activities
                    probabilities(end + 1) = probability; % Add to probabilities
                end
                if isscalar(probabilities)
                    tasks{task_id}.addPrecedence(ActivityPrecedence.Serial(activities{i}, target_activities{1}));
                else
                    % Add OrFork precedence for this entry using the provided probabilities
    
                    tasks{task_id}.addPrecedence(ActivityPrecedence.OrFork(activities{i}, target_activities, round(probabilities, 1)));
                end
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
       
    
    
        % Store metrics in a struct
        entry_metrics = struct();
        entry_metrics.queue_lengths = mean_queue_lengths;
        entry_metrics.response_times = mean_response_times;
        entry_metrics.throughputs = mean_throughputs;
    end
end


