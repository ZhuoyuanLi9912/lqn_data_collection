function LQN = build_LQN_from_Sobol(sobolCSV, lookupCSV, outputMATname, logfileName)
    basePath = "C:\GLQN\data\3_10_layer_data";
    [~, fname, ext] = fileparts(sobolCSV);
    fname = fname + ext;  % e.g. "samples_P10_T3_E3_part01.csv"
    % sscanf will scan according to the format and return a numeric vector
    nums = sscanf(fname, 'samples_P%d_T%d_E%d_part%d.csv');

    P = nums(1);
    T = nums(2);
    E = nums(3);
    

    % Build full paths
    outputMAT = fullfile(basePath, outputMATname);
    logfile = fullfile(basePath, logfileName);

    % Add necessary code folders
    addpath(genpath("C:\GLQN"));

    % Start logging
    diary(logfile);

    % Main logic
    results = parse_csv_file(sobolCSV, lookupCSV,P,T,E);
    r = results(1);  % Store into a temporary variable
    disp(r);
    LQN = simulate_lqn_lqns(results);

    % Save output
    save(outputMAT, 'LQN');

    % Stop logging
    diary off; 
end

function results = parse_csv_file(sobolCSV, lookupCSV,P,T,E)
    sobol = readmatrix(sobolCSV);
    lookup = readmatrix(lookupCSV);


    % Struct template with all fields
    template = struct( ...
        'processor_count', zeros(1, 0), ...
        'entries_per_task',zeros(1, 0), ...
        'tasks_per_proc',  zeros(1, 0), ...
        'pattern_ids',     zeros(1, 0),...
        'think_time',      zeros(1, 0), ...
        'task_multiplicity',    zeros(1, 0), ...
        'calls_per_entry', zeros(1, 0), ...
        'probabilities',   {cell(1, 0)}, ...
        'service_times_mean',   zeros(1, 0), ...
        'service_times_scv',   zeros(1, 0), ...
        'num_of_task',     zeros(1,0),...
        'num_of_entry',     zeros(1,0),...
        'num_of_call_entry', zeros(1,0), ...
        'processor_multiplicity',zeros(1,0));  

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
        idx = idx + P;
    
        % 3. Entries per task (only first 'total_tasks')
        total_tasks = sum(tasks_per_proc);
        total_server_task = total_tasks - row(2);
        entries_per_task = [ones(1, row(2)), row(idx:idx+total_server_task-1)]; 
        idx = idx + (P-1)*T;

        % 5. Total number of entries
        num_entries = sum(entries_per_task);
        num_last_layer_task = tasks_per_proc(end);
        num_last_layer_entry = sum(entries_per_task(end-num_last_layer_task+1:end));
        pattern_ids = row(idx:idx+num_entries-num_last_layer_entry-1);
        idx = idx + (P-1)*T*E;
        % 4. Processor multiplicity
        processor_multiplicity = row(idx:idx+row(1)-1);
        idx = idx+P;
        % 4. Task multiplicity and think time (only first 'total_tasks')
        task_multiplicity = row(idx:idx+total_tasks-1);
        idx = idx+P*T;
        think_time= row(idx:idx+row(2)-1);
        idx = idx +T;

        % 9. Analyze pattern IDs
        calls_per_entry = zeros(1, length(pattern_ids));

        probabilities = cell(1,length(pattern_ids));
        
        for e = 1:length(pattern_ids)
            pid = pattern_ids(e);  
            if pid >= 1 && pid <= size(lookup, 1)
                weights = lookup(pid, :);  
            else
                weights = zeros(1, size(lookup, 2));
            end
        
            nonzero = weights > 0;
            calls_per_entry(e) = sum(nonzero);
            % Find the last non-zero element
            trimmed_weights = weights(weights ~= 0);
            probabilities{e} = trimmed_weights;
        end

    
        % 10. Extract service times
        service_times_mean = row(idx:idx+P * T * E * 4-1);
        idx = idx+P * T * E * 4;
        service_times_scv = row(idx:idx+P * T * E * 4-1);
        idx = idx+P * T * E * 4;
        call_times = row(idx:idx+P * T * E * 3-1);
    
        % 11. Store into result struct
        results(i).processor_count = processor_count;
        results(i).tasks_per_proc = tasks_per_proc;
        results(i).task_multiplicity = task_multiplicity;
        results(i).think_time = think_time;
        results(i).entries_per_task = entries_per_task;
        results(i).pattern_ids = pattern_ids;
        results(i).calls_per_entry = calls_per_entry;
        results(i).probabilities = probabilities;
        results(i).service_times_mean = service_times_mean;
        results(i).service_times_scv = service_times_scv;
        results(i).call_times = call_times;
        results(i).num_of_task = total_tasks;
        results(i).num_of_entry = num_entries;
        results(i).num_of_call_entry = num_entries-num_last_layer_entry;
        results(i).processor_multiplicity = processor_multiplicity;
    end
end



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
        'processor_attributes',                       zeros(0, 1), ...
        'task_attributes',                       zeros(0, 2), ...
        'task_on_processor_edges',              zeros(2, 0), ...
        'entry_on_task_edges',                  zeros(2, 0), ...
        'activity_attributes',                  zeros(0, 2), ...
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
    successful_count = 0;
    for n = 1:N
        try
            result = results(n);
            num_of_processor = result.processor_count;
            num_of_task = result.num_of_task;
            num_of_entry = result.num_of_entry;
            num_of_call_entry = result.num_of_call_entry;
            
            processor_attributes = zeros(num_of_processor,1);
            task_attributes = zeros(num_of_task, 2);
            task_on_processor_edges = zeros(2,num_of_task);
            entry_on_task_edges = zeros(2,num_of_entry);
    
            model = LayeredNetwork('LQN');
  
            % Step 1: Create processors, tasks, and entries (no calls yet)
            processors = cell(result.processor_count, 1);
            tasks = cell(sum(result.tasks_per_proc), 1);
            entries = cell(sum(result.entries_per_task), 1);
            
        
            % Create processors
            for i = 1:num_of_processor
                processors{i} = Processor(model, ['P', num2str(i)], result.processor_multiplicity(i), SchedStrategy.PS);
                processor_attributes(i) = result.processor_multiplicity(i);
            end
            task_index = 0;
            % Create tasks
            for i = 1:num_of_processor
                for j = 1:result.tasks_per_proc(i)
                    task_index = task_index+1;
                    multiplicity = result.task_multiplicity(task_index);
                    if i == 1
                        sched_strategy = SchedStrategy.REF; % First processor
                        think_time = result.think_time(task_index);
                        task_attributes(task_index,:) = [multiplicity,round(think_time,1)];
                    else
                        sched_strategy = SchedStrategy.FCFS; % Other processors
                        task_attributes(task_index,:) = [multiplicity,0];
                    end
                    tasks{task_index} = Task(model, ['T', num2str(task_index)], multiplicity, sched_strategy).on(processors{i});
                    if i == 1
                        tasks{task_index}.setThinkTime(Exp.fitMean(round(think_time,1)));
                    end
                    task_on_processor_edges(:,task_index) = [task_index;i];
                end
            end
            % Build fast task-to-processor lookup array
            max_task = max(task_on_processor_edges(1, :));
            task_to_proc = zeros(1, max_task);
            task_to_proc(task_on_processor_edges(1, :)) = task_on_processor_edges(2, :);
            entry_index = 0;
            activity_index = 0;
            entry_on_second_layer=0;
            % Create entries
            for i = 1:num_of_task
                for j = 1:result.entries_per_task(i)
                    entry_index = entry_index+1;
                    entries{entry_index} = Entry(model, ['E', num2str(entry_index)]).on(tasks{i});
                    entry_on_task_edges(:,entry_index) = [entry_index;i];
                end
            end
            entry_on_task_edges = entry_on_task_edges(:, any(entry_on_task_edges, 1));

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
                    if result.calls_per_entry(entry)>5
                        error('Cannot fit a LQN on this data');
                    end
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
            activities = cell(num_of_activity, 1); 
    
            if length(result.service_times_mean) < num_of_activity
                error('Cannot fit a LQN on this data, no enough data');
            end
            activity_attributes = zeros(num_of_activity,2);
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
                activities{activity_index} = Activity(model, ['A', num2str(activity_index)], APH.fitMeanAndSCV(round(result.service_times_mean(activity_index),1),round(result.service_times_scv(activity_index),1))) ...
                    .on(tasks{parent_task_index}).boundTo(entries{i});
                activity_attributes(activity_index,:) = [round(result.service_times_mean(activity_index),1),round(result.service_times_scv(activity_index),1)];
                activity_on_entry_edges(:,activity_index)=[activity_index;i];
                % Check if this entry makes any calls
                if i <= num_of_call_entry
                    current_processor = entry_to_processor_edges(2, find(entry_to_processor_edges(1,:) == i, 1));
                    next_layer_entries = entry_to_processor_edges(1, entry_to_processor_edges(2,:) == current_processor + 1);
                    if_called_by_this = zeros(1,length(next_layer_entries));
                    for c = 1:result.calls_per_entry(i)
                        subset = if_called(next_layer_entries);
                        if all(subset == 1)
                            idx = randsample(find(~if_called_by_this), 1);
                            selected = next_layer_entries(idx);  % random pick
                            if_called_by_this(idx)=1;
                        else
                            idx = find(subset ~= 1, 1);                   % first not-1
                            selected = next_layer_entries(idx);           % map back to entry index
                            if_called(selected) = 1;                      % mark it as called
                            if_called_by_this(idx)=1;
                        end
                        
                        activity_index = activity_index+1;
                        call_index = call_index+1;
                        activities{activity_index} = Activity(model, ['A', num2str(activity_index)], APH.fitMeanAndSCV(round(result.service_times_mean(activity_index),1),round(result.service_times_scv(activity_index),1))) ...
                                .on(tasks{parent_task_index}).synchCall(entries{selected}, round(result.call_times(call_index),1));
                        activity_attributes(activity_index,:) = [round(result.service_times_mean(activity_index),1),round(result.service_times_scv(activity_index),1)];
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
    
            
            % Get model structure sizes
            num_processors = num_of_processor;
            num_tasks = num_of_task;
            num_entries = num_of_entry;
                        
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
            queue_lengths = table2array(entry_rows(:, 3));   % Queue lengths
            response_times = table2array(entry_rows(:, 5));  % Response times
            throughputs = table2array(entry_rows(:, 7));     % Throughputs

            
            % Compute averages across replications
            successful_count = successful_count + 1;
            LQN(successful_count).task_attributes                      = task_attributes;
            LQN(successful_count).processor_attributes                      = processor_attributes;
            LQN(successful_count).task_on_processor_edges             = task_on_processor_edges;
            LQN(successful_count).entry_on_task_edges                 = entry_on_task_edges;
            LQN(successful_count).activity_attributes                 = activity_attributes;
            LQN(successful_count).activity_on_entry_edges             = activity_on_entry_edges;
            LQN(successful_count).activity_activity_edges             = activity_activity_edges;
            LQN(successful_count).activity_activity_edge_attributes   = activity_activity_edge_attributes;
            LQN(successful_count).activity_call_entry_edges           = activity_call_entry_edges;
            LQN(successful_count).activity_call_entry_edge_attributes = activity_call_entry_edge_attributes;
            LQN(successful_count).entry_queue_lengths                 = queue_lengths;
            LQN(successful_count).entry_response_times                = response_times;
            LQN(successful_count).entry_throughputs                   = throughputs;
            fprintf('Finished %d-th loop\n', n);
            fprintf('Total successful models: %d\n', successful_count);
        catch ME
           fprintf('Error in iteration %d: %s\n', n, ME.message);
           continue;  % Skip to next iteration
        end

    end
end



