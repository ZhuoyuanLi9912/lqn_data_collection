function Random_LQN_generator_complex(num_LQNs, output_file, syc_call_only,config)
    % Generate a dataset of LQN models and their simulated metrics using LQNS
    %
    % Args:
    %   num_LQNs (int): Number of LQN models to generate
    %   output_file (string): Output file name to save the dataset
    %   config (struct): Configuration for random ranges
    %
    % Returns:
    %   Saves the dataset in a .mat file

    % Default configuration if not provided
    if nargin < 3
        syc_call_only = false;
    end

    if nargin < 4
        config = struct( ...
            'num_processors', [3, 4], ...  % Range for number of processors
            'tasks_per_processor', [1, 4], ... % Range for tasks per processor
            'entries_per_task', [1, 3], ... % Range for entries per task
            'calls_per_entry', [1, 4]); % Range for entry calls
    end

    % Initialize cell array to store successfully generated LQN models
    LQN_dataset = cell(num_LQNs, 1);

    % Counter for successfully processed LQNs
    successful_count = 0;

    i = 0; % Loop counter for total attempts
    while successful_count < num_LQNs

            i = i + 1; 

            LQN = generate_random_lqn(syc_call_only, config);

            entry_metrics = simulate_lqn_lqns(LQN);


            % Step 3: Store the metrics in the LQN struct
            LQN.entry_queue_lengths = entry_metrics.queue_lengths;
            LQN.entry_response_times = entry_metrics.response_times;
            LQN.entry_throughputs = entry_metrics.throughputs;
            % Step 4: Save the LQN model with metrics
            successful_count = successful_count + 1; % Increment successful count
            LQN_dataset{successful_count} = LQN; % Store the LQN
            
            % Display progress
            disp(['Generated and simulated LQN ', num2str(successful_count), ' of ', num2str(num_LQNs)]);

    end

    % Save the dataset to a .mat file
    save(output_file, 'LQN_dataset');
    disp(['LQN dataset saved to ', output_file]);
    disp(['Totally tried ', num2str(i)]);
end



function LQN = generate_random_lqn(syc_call_only, config)
    % Generate a random LQN model with processors, tasks, entries, and activities
    %
    % Args:
    %   config (struct): Configuration for random ranges
    %
    % Returns:
    %   LQN (struct): A struct representing the LQN model

    % Randomly determine the number of processors
    num_processors = randi(config.num_processors);
    processor_attributes = randi([1, 10], num_processors, 1);  % Processor Multiplicity 1-10

    % Initialize tasks and entries
    tasks = [];
    entries = [];
    task_on_processor_edges = [];
    activities = [];
    activity_on_entry_edges = [];
    activity_flow_activity_edges = [];
    activity_call_entry_edges = [];
    entry_on_task_edges = [];
    entry_call_entry_edges = [];
    activity_flow_edge_attributes = [];
    activity_call_entry_edge_attributes = [];
    or_join_entry_probability={};

    % Step 1: Create Layers, Tasks, and Entries
    layer_entries = cell(num_processors, 1); % Track entries in each processor layer
    for p = 1:num_processors
        % Determine number of tasks for this processor
        num_tasks = randi(config.tasks_per_processor);

        % Store the tasks and entries for this processor
        processor_tasks = [];
        processor_entries = [];

        for t = 1:num_tasks
            % Add task (including multiplicity as the third column)
            think_time = round(rand(1) * 2.9 + 0.1, 1); % Mean think time: 0.1 to 3.0
            multiplicity = randi([1, 10]); % Random multiplicity between 1 and 5
            tasks = [tasks; think_time, multiplicity];
            processor_tasks = [processor_tasks; size(tasks, 1)];

            % Determine number of entries for this task
            num_entries = randi(config.entries_per_task);

            for e = 1:num_entries
                % Add entry
                if syc_call_only
                    if_sync_call = 1;
                else
                    if_sync_call = randi([0,1]);
                end
                activity_pattern = randi([1,3]);
                entries = [entries;if_sync_call,activity_pattern];
                processor_entries = [processor_entries; size(entries, 1)];
                entry_on_task_edges = [entry_on_task_edges, [size(entries, 1); size(tasks, 1)]];
            end

            % Map task to the processor
            task_on_processor_edges = [task_on_processor_edges, [size(tasks, 1); p]];
        end

        % Store entries for this layer
        layer_entries{p} = processor_entries;
    end

    % Step 2: Add Calls Between Layers
    for p = 1:(num_processors - 1) % No calls from the last layer
        current_layer_entries = layer_entries{p};
        next_layer_entries = layer_entries{p + 1};

        % Precompute the number of outgoing calls for each entry in the current layer
        min_calls = config.calls_per_entry(1);
        max_calls = config.calls_per_entry(2);
        
        % Initialize: random calls from min to max for all
        current_layer_call_limits = randi([min_calls, max_calls], size(current_layer_entries));
        
        % Get types of current layer entries
        entry_types = entries(current_layer_entries, 2);
        
        % Find indices of type 2 or 3
        special_idx = entry_types == 2 | entry_types == 3;
        
        % If 1 is not allowed, and min_calls == 1, we need to avoid it
        if min_calls == 1 && max_calls > 1
            % Re-roll for special types using [2, max_calls]
            current_layer_call_limits(special_idx) = randi([2, max_calls], sum(special_idx), 1);
        elseif min_calls == 1 && max_calls == 1
            error('Cannot avoid 1 for types 2 and 3 if config.calls_per_entry is [1, 1].');
        end     
        current_layer_assigned_calls = zeros(size(current_layer_entries)); % Track assigned calls

        % Track assigned edges to avoid duplicates
        existing_edges = containers.Map();

        % Pre-check: Ensure total available call slots can cover next layer entries
        while sum(current_layer_call_limits - current_layer_assigned_calls) < length(next_layer_entries)
            % Increment the call limit for the entry with the fewest remaining slots
            [~, idx] = min(current_layer_call_limits - current_layer_assigned_calls);
            if current_layer_call_limits(idx) == config.calls_per_entry(2)
                error('Exceeded numbers of class per entry.');
            end
            current_layer_call_limits(idx) = current_layer_call_limits(idx) + 1;
        end

        % Determine the limit based on the length of next_layer_entries
        limit = length(next_layer_entries);

        % Replace values in current_layer_call_limits that exceed the limit
        current_layer_call_limits(current_layer_call_limits > limit) = limit;

        % Ensure every entry in the next layer has at least one incoming call
        for e = 1:length(next_layer_entries)
            target_entry = next_layer_entries(e);

            % Randomly select a source entry with available call slots
            available_indices = find(current_layer_assigned_calls < current_layer_call_limits);
            source_entry_idx = available_indices(randi(length(available_indices)));
            source_entry = current_layer_entries(source_entry_idx);

            % Record the assigned edge
            edge_key = sprintf('%d-%d', source_entry, target_entry);
            existing_edges(edge_key) = true;

            % Add the call to the edge list
            entry_call_entry_edges = [entry_call_entry_edges, [source_entry; target_entry]];


            % Update the assigned call count and probability
            current_layer_assigned_calls(source_entry_idx) = current_layer_assigned_calls(source_entry_idx) + 1;
            
        end

        % Add remaining calls for entries in the current layer that have not reached their limit
        for e = 1:length(current_layer_entries)
            source_entry = current_layer_entries(e);

            % Determine how many more calls this entry can make
            remaining_calls = current_layer_call_limits(e) - current_layer_assigned_calls(e);

            if remaining_calls > 0
                % Assign remaining calls
                for c = 1:remaining_calls
                    max_retries = 100; % Set a limit on retries
                    retry_count = 0;

                    % Randomly select a target entry
                    target_entry = next_layer_entries(randi(length(next_layer_entries)));
                    edge_key = sprintf('%d-%d', source_entry, target_entry);

                    % Retry if the edge already exists
                    while isKey(existing_edges, edge_key)
                        retry_count = retry_count + 1;

                        % Break out of the loop if max retries are reached
                        if retry_count > max_retries
                            error('Exceeded maximum retries when finding unique target entry.');
                        end

                        % Retry with a new target entry
                        target_entry = next_layer_entries(randi(length(next_layer_entries)));
                        edge_key = sprintf('%d-%d', source_entry, target_entry);
                    end

                    % Record the assigned edge
                    existing_edges(edge_key) = true;

                    % Add the call to the edge list
                    entry_call_entry_edges = [entry_call_entry_edges, [source_entry; target_entry]];

                    % Update the assigned call count and probability
                    current_layer_assigned_calls(e) = current_layer_assigned_calls(e) + 1;
                end
            end

            % add activities
            target_entries = find(entry_call_entry_edges(1, :) == source_entry);
            switch entries(source_entry,2)
                case {1}
                    for i = 1:length(target_entries)
                        activity_service_time_mean = round(0.1 + (3 - 0.1) * rand(1),1);
                        activity_service_time_scv = round(0.1 + (3 - 0.1) * rand(1),1);
                        activities = [activities;activity_service_time_mean,activity_service_time_scv];
                        activity_on_entry_edges = [activity_on_entry_edges,[size(activities,1);source_entry]];
                        if i~=1
                            activity_flow_activity_edges = [activity_flow_activity_edges,[size(activities,1)-1;size(activities,1)]];
                            activity_flow_edge_attributes = [activity_flow_edge_attributes;1];
                        end
                        mean_number_of_calls = round(rand(1) * 2.9 + 0.1, 1); % Random mean: 0.1 to 3.0
                        activity_call_entry_edges = [activity_call_entry_edges, [size(activities,1); target_entries(i)]];
                        activity_call_entry_edge_attributes = [activity_call_entry_edge_attributes; mean_number_of_calls];
                    end
                case {2}
                        activity_service_time_mean = round(0.1 + (3 - 0.1) * rand(1),1);
                        activity_service_time_scv = round(0.1 + (3 - 0.1) * rand(1),1);
                        activities = [activities;activity_service_time_mean,activity_service_time_scv];
                        prime_activities = size(activities,1);
                        activity_on_entry_edges = [activity_on_entry_edges,[size(activities,1);source_entry]];
                    for i = 1:length(target_entries)
                        activity_service_time_mean = round(0.1 + (3 - 0.1) * rand(1),1);
                        activity_service_time_scv = round(0.1 + (3 - 0.1) * rand(1),1);
                        activities = [activities;activity_service_time_mean,activity_service_time_scv];
                        activity_flow_activity_edges = [activity_flow_activity_edges,[prime_activities;size(activities,1)]];
                        activity_on_entry_edges = [activity_on_entry_edges,[size(activities,1);source_entry]];
                        mean_number_of_calls = round(rand(1) * 2.9 + 0.1, 1); % Random mean: 0.1 to 3.0
                        activity_call_entry_edges = [activity_call_entry_edges, [size(activities,1); target_entries(i)]];
                        activity_call_entry_edge_attributes = [activity_call_entry_edge_attributes; mean_number_of_calls];
                    end
                        or_join_entry_probability{source_entry} = generateOnePlaceDecimalsProbability(length(target_entries));
                        activity_flow_edge_attributes = [activity_flow_edge_attributes;or_join_entry_probability{source_entry}']; 
                case {3}
                        activity_service_time_mean = round(0.1 + (3 - 0.1) * rand(1),1);
                        activity_service_time_scv = round(0.1 + (3 - 0.1) * rand(1),1);
                        activities = [activities;activity_service_time_mean,activity_service_time_scv];
                        prime_activities = size(activities,1);
                        activity_on_entry_edges = [activity_on_entry_edges,[size(activities,1);source_entry]];
                        activity_service_time_mean = round(0.1 + (3 - 0.1) * rand(1),1);
                        activity_service_time_scv = round(0.1 + (3 - 0.1) * rand(1),1);
                        activities = [activities;activity_service_time_mean,activity_service_time_scv];
                        last_activities = size(activities,1);
                        activity_on_entry_edges = [activity_on_entry_edges,[size(activities,1);source_entry]];
                    for i = 1:length(target_entries)
                        activity_service_time_mean = round(0.1 + (3 - 0.1) * rand(1),1);
                        activity_service_time_scv = round(0.1 + (3 - 0.1) * rand(1),1);
                        activities = [activities;activity_service_time_mean,activity_service_time_scv];
                        activity_on_entry_edges = [activity_on_entry_edges,[size(activities,1);source_entry]];
                        activity_flow_activity_edges = [activity_flow_activity_edges,[prime_activities;size(activities,1)]];
                        activity_flow_edge_attributes = [activity_flow_edge_attributes;1];
                        activity_flow_activity_edges = [activity_flow_activity_edges,[size(activities,1);last_activities]];
                        activity_flow_edge_attributes = [activity_flow_edge_attributes;1];
                        mean_number_of_calls = round(rand(1) * 2.9 + 0.1, 1); % Random mean: 0.1 to 3.0
                        activity_call_entry_edges = [activity_call_entry_edges, [size(activities,1); target_entries(i)]];
                        activity_call_entry_edge_attributes = [activity_call_entry_edge_attributes; mean_number_of_calls];                        
                    end
                        

            end
        
        end        
    end

    % Create the LQN struct
    LQN = struct();
    LQN.processor_attributes = processor_attributes;
    LQN.task_attributes = tasks;
    LQN.entry_attributes = entries;
    LQN.task_on_processor_edges = task_on_processor_edges;
    LQN.entry_on_task_edges = entry_on_task_edges;
    LQN.entry_call_entry_edges = entry_call_entry_edges;
    LQN.activities = activities;
    LQN.activity_flow_activity_edges = activity_flow_activity_edges;
    LQN.activity_call_entry_edges = activity_call_entry_edges;
    LQN.activity_on_entry_edges = activity_on_entry_edges;
    LQN.activity_flow_edge_attributes = activity_flow_edge_attributes;
    LQN.activity_call_entry_edge_attributes = activity_call_entry_edge_attributes;
    LQN.or_join_entry_probability = or_join_entry_probability;
end




function entry_metrics = simulate_lqn_lqns(LQN)
    % Simulate the LQN and extract metrics for each entry using LQNS
    %
    % Args:
    %   LQN (struct): The LQN model
    %
    % Returns:
    %   entry_metrics (struct): Struct containing queue lengths, response times, and throughputs for each entry

    % Create the LayeredNetwork model
    model = LayeredNetwork('LQN');

    % Step 1: Create processors, tasks, and entries (no calls yet)
    processors = cell(size(LQN.processor_attributes, 1), 1);
    tasks = cell(size(LQN.task_attributes, 1), 1);
    entries = cell(size(LQN.entry_attributes, 1), 1);
    activities = cell(size(LQN.entry_attributes, 1), 1); % Store primary activities

    % Create processors
    for i = 1:size(LQN.processor_attributes, 1)
        processors{i} = Processor(model, ['P', num2str(i)], LQN.processor_attributes(i), SchedStrategy.PS);
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
        entry_activity = LQN.activity_on_entry_edges(1, LQN.activity_on_entry_edges(2,:) == i); 
        called_entries = LQN.entry_call_entry_edges(2, LQN.entry_call_entry_edges(1, :) == i);
        switch LQN.entry_attributes(i,2)
            case {1}
                for e = 1:size(entry_activity)
                    activities{i}{e} = Activity(model,['A',num2str(entry_activity(e))], ...
                        APH.fitMeanAndSCV(LQN.activities(entry_activity(e),1),LQN.activities(entry_activity(e),2))).on(task_id).synchCall(called_entries(e));
                    if e == 1
                        activities{i}{e}.boundTo(entries{i});
                    end
                    if e == size(entry_activity)
                        activities{i}{e}.repliesTo(entries{i});
                    end
                    if e ~=1
                        tasks{task_id}.addPrecedence(ActivityPrecedence.Serial(activities{i}{e-1}, activities{i}{e}));
                    end
                end

            case {2}
                target_activities = {};
                for e = 1:size(entry_activity)
                    activities{i}{e} = Activity(model,['A',num2str(entry_activity(e))], ...
                        APH.fitMeanAndSCV(LQN.activities(entry_activity(e),1),LQN.activities(entry_activity(e),2))).on(task_id);
                    if e == 1
                        activities{i}{e}.boundTo(entries{i});
                    end
                    if e ~= 1
                        tasks{task_id}.synchCall(called_entries(e-1)).repliesTo(entries{i});
                        target_activities{end+1} = activities{i}{e};
                    end
                end
                tasks{task_id}.addPrecedence(ActivityPrecedence.OrFork(activities{i}{1}, target_activities, LQN.or_join_entry_probability{i}));
            case {3}
                target_activities = {};
                for e = 1:size(entry_activity)
                    activities{i}{e} = Activity(model,['A',num2str(entry_activity(e))], ...
                        APH.fitMeanAndSCV(LQN.activities(entry_activity(e),1),LQN.activities(entry_activity(e),2))).on(task_id);
                    if e == 1
                        activities{i}{e}.boundTo(entries{i});
                    end
                    if e == 2
                        activities{i}{e}.repliesTo(entries{i});
                    end
                    if e > 2
                        tasks{task_id}.synchCall(called_entries(e-2)).repliesTo(entries{i});
                        target_activities{end+1} = activities{i}{e};
                    end
                end
        end
    end

    % Solve the model using LQNS
    options = SolverLQNS.defaultOptions;
    options.method = 'lqns';
    solver = SolverLQNS(model, options);


    % Extract metrics for entries
    avg_table = solver.getAvgTable();

    % Calculate row range for entries
    num_processors = size(LQN.processor_attributes, 1);
    num_tasks = size(LQN.task_attributes, 1);
    num_entries = size(LQN.entry_attributes, 1);

    entry_start_row = num_processors + num_tasks + 1;
    entry_end_row = entry_start_row + num_entries - 1;

    % Extract relevant rows for entries
    entry_rows = avg_table(entry_start_row:entry_end_row, :);

    % Extract queue lengths, response times, and throughputs
    queue_lengths = table2array(entry_rows(:, 3));   % 3rd column: queue length
    response_times = table2array(entry_rows(:, 5)); % 5th column: response time
    throughputs = table2array(entry_rows(:, 7));    % 7th column: throughput

    % Store metrics in a struct
    entry_metrics = struct();
    entry_metrics.queue_lengths = queue_lengths;
    entry_metrics.response_times = response_times;
    entry_metrics.throughputs = throughputs;
end


