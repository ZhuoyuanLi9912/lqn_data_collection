function entry_level_to_activity_level_converter(input_file, output_file)
    % Load existing LQN dataset
    load(input_file, 'LQN_dataset');

    % Loop over all LQN instances in the dataset
    for i = 1:length(LQN_dataset)
        LQN = LQN_dataset{i}; % Extract current LQN

        % === Keep Unchanged Fields ===
        new_LQN.processor_attributes = LQN.processor_attributes;
        new_LQN.task_attributes = LQN.task_attributes;
        new_LQN.task_on_processor_edges = LQN.task_on_processor_edges;
        new_LQN.entry_on_task_edges = LQN.entry_on_task_edges;

        % === Initialize New Activity-Level Fields ===
        activities = [];  % Store all activities
        activity_on_entry_edges = []; % Activity → Entry edges (containment)
        activity_activity_edges = []; % Activity → Activity edges (routing inside entry)
        activity_activity_edge_attributes = []; % Routing probabilities
        activity_call_entry_edges = []; % Activity → Entry call edges
        activity_call_entry_edge_attributes = []; % Call attributes

        % === 1️⃣ Convert entry_attributes to activity level ===
        num_entries = size(LQN.entry_attributes, 1);

        % New labels at the activity level


        for e = 1:num_entries
            % Create main activity using entry service time & SCV
            activities = [activities; LQN.entry_attributes(e, :)]; % Store mean & SCV

            % Record edge from entry → main activity (containment)
            activity_on_entry_edges = [activity_on_entry_edges, [e; e]]; % Direct mapping: first activity == entry index

        end

        % === 2️⃣ Convert entry_call_entry_edges to activity-level ===
        num_calls = size(LQN.entry_call_entry_edges, 2);

        for c = 1:num_calls
            % Read source and target entry IDs
            source_entry = LQN.entry_call_entry_edges(1, c);
            target_entry = LQN.entry_call_entry_edges(2, c);

            % Extract call attributes
            routing_probability = LQN.entry_call_entry_edge_attributes(c, 1);
            times_of_call = LQN.entry_call_entry_edge_attributes(c, 2);
            mean_service_time = LQN.entry_call_entry_edge_attributes(c, 3);
            scv_service_time = LQN.entry_call_entry_edge_attributes(c, 4);

            % Create new call activity inside the source entry
            call_activity_id = size(activities, 1) + 1;
            activities = [activities; mean_service_time, scv_service_time];

            % Record edge from entry → call activity (containment)
            activity_on_entry_edges = [activity_on_entry_edges, [call_activity_id; source_entry]];

            % ✅ FIX: Connect **main activity** → call activity (with routing probability)
            source_main_activity = source_entry; % Direct index matching
            activity_activity_edges = [activity_activity_edges, [source_main_activity; call_activity_id]];
            activity_activity_edge_attributes = [activity_activity_edge_attributes; routing_probability];

            % ✅ FIX: Connect call activity → target entry (with times_of_call)
            activity_call_entry_edges = [activity_call_entry_edges, [call_activity_id; target_entry]];
            activity_call_entry_edge_attributes = [activity_call_entry_edge_attributes; times_of_call];
        end

        % === Store Modified Data in New Struct ===
        new_LQN.activity_attributes = activities;
        new_LQN.activity_on_entry_edges = activity_on_entry_edges;
        new_LQN.activity_activity_edges = activity_activity_edges;
        new_LQN.activity_activity_edge_attributes = activity_activity_edge_attributes; % ✅ FIXED
        new_LQN.activity_call_entry_edges = activity_call_entry_edges;
        new_LQN.activity_call_entry_edge_attributes = activity_call_entry_edge_attributes; % ✅ FIXED
        new_LQN.entry_queue_lengths = LQN.entry_queue_lengths;
        new_LQN.entry_response_times = LQN.entry_response_times;
        new_LQN.entry_throughputs = LQN.entry_throughputs;
        % Store modified LQN back in dataset
        LQN_dataset{i} = new_LQN;
    end

    % Save updated dataset
    save(output_file, 'LQN_dataset');
    disp(['Updated LQN dataset saved to ', output_file]);
end
