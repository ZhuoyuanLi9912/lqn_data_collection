parse_csv_file
function results = parse_csv_file()
    % Load Sobol sample CSV
    sobol = readmatrix("C:\GLQN\python\GLQN\Sobol_sampling\sampling_data\chunk_01.csv"); % Update path if needed
    
    % Load weight lookup table
    lookup = readtable("C:\GLQN\python\GLQN\weight_lookup.csv"); % Update path if needed
    template = struct( ...
    'processor_count', zeros(1, 0), ...
    'tasks_per_proc',  zeros(1, 0), ...
    'multiplicity',    zeros(1, 0), ...
    'think_time',      zeros(1, 0), ...
    'entries_per_task',zeros(1, 0), ...
    'pattern_ids',     zeros(1, 0), ...
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
    
        % 5. Entries per task (only first 'total_tasks')
        entries_per_task = row(idx:idx+total_tasks-1);
        idx = idx + 32;
    
        % 6. Total number of entries
        num_entries = sum(entries_per_task);
    
        % 7. Skip activities per entry
        idx = idx + 128;
    
        % 8. Activity service times (640 floats) — we'll extract later
        service_time_start_idx = idx;
    
        % 9. Pattern selectors (only first 'num_entries')
        pattern_ids = row(idx+640 : idx+640+num_entries-1);
        
        % Lookup how many non-zero weights per pattern
        num_service_times_needed = 0;
        for pid = pattern_ids
            % Find the pattern row in the lookup
            match = lookup.ID == pid;
            weights = table2array(lookup(match, 2:end));
            num_nonzero = sum(weights > 0);
            num_service_times_needed = num_service_times_needed + num_nonzero;
        end
    
        % Extract the correct number of service times
        service_times = row(service_time_start_idx : service_time_start_idx + num_service_times_needed - 1);
    
        % (Optional) Store results in struct
        results{i}.processor_count = processor_count;
        results{i}.tasks_per_proc = tasks_per_proc;
        results{i}.multiplicity = multiplicity;
        results{i}.think_time = think_time;
        results{i}.entries_per_task = entries_per_task;
        results{i}.pattern_ids = pattern_ids;
        results{i}.calls_per_entry = pattern_ids;
        results{i}.service_times = service_times;
    end
end
% Example: display first result
disp(results{1});
function entry_metrics = simulate_lqn_lqns(results)
    % Simulate the LQN and extract metrics for each entry using LQNS
    %
    % Args:
    %   LQN (struct): The LQN model
    %
    % Returns:
    %   entry_metrics (struct): Struct containing queue lengths, response times, and throughputs for each entry

    % Create the LayeredNetwork model
    n = size(results, 2);
    for k = 1:n
        result = results(i);
        model = LayeredNetwork('LQN');
    
        % Step 1: Create processors, tasks, and entries (no calls yet)
        processors = cell(result.processor_count, 1);
        tasks = cell(sum(result.tasks_per_proc), 1);
        entries = cell(sum(result.entries_per_task), 1);
        activities = cell(size(result.service_times, 1), 1); % Store primary activities
    
        % Create processors
        for i = 1:results.processor_count
            processors{i} = Processor(model, ['P', num2str(i)], 1, SchedStrategy.PS);
        end
    
        % Create tasks
        for i = 1:size(LQN.task_attributes, 1)
            multiplicity = LQN.task_attributes(i, 2); % Extract multiplicity
            if LQN.task_on_processor_edges(2, i) == 1
                sched_strategy = SchedStrategy.REF; % First processor
            else
                sched_strategy = SchedStrategy.FCFS; % Other processors
            end
    
            tasks{i} = Task(model, ['T', num2str(i)], multiplicity, sched_strategy).on(processors{LQN.task_on_processor_edges(2, i)});
            tasks{i}.setThinkTime(Exp.fitMean(LQN.task_attributes(i, 1)));
        end
    
        % Create entries and their primary activities
        for i = 1:size(LQN.entry_attributes, 1)
            task_id = LQN.entry_on_task_edges(2, i); % Get task ID for this entry
            entries{i} = Entry(model, ['E', num2str(i)]).on(tasks{task_id});
    
            % Create primary activity for this entry
            activities{i} = Activity(model, ['A', num2str(i)], APH.fitMeanAndSCV(LQN.entry_attributes(i, 1), LQN.entry_attributes(i, 2))) ...
                .on(tasks{task_id}).boundTo(entries{i});
        end
    
        % Step 2: Add calls between entries
        call_activity = cell(size(LQN.entry_attributes, 1), 1); % Store call activities for each entry
        global_call_counter = 1; % Initialize a global call counter
    
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


