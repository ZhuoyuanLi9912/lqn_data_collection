function LQN = lqn_parameter_sampling()
    % === Configuration Parameters ===
    processor_range = 2:5;
    processor_mult_range = [1, 10];
    task_mult_range = [1, 10];
    think_time_range = [0.1, 5];
    entry_per_task_range = 1:3;
    service_time_range = [0.1, 5];
    service_scv_range = [0.1, 3];
    calls_per_entry_range = 1:3;
    call_time_range = [0.1, 5];
    call_scv_range = [0.1, 3];
    call_mean_times_range = [0.1, 3];
    dirichlet_alpha = 1;

    % === Random Seed for Reproducibility ===
    rng('shuffle');

    % === Top-Level Structure ===
    num_proc = randsample(processor_range, 1);
    sobol_proc = scramble(sobolset(num_proc), 'MatousekAffineOwen');
    LQN.processors = struct([]);

    for p = 1:num_proc
        % Processor multiplicity
        proc_mult = scale_sobol(net(sobol_proc(p), 1), processor_mult_range);

        % Tasks per processor
        num_tasks = randsample(1:4, 1);
        sobol_tasks = scramble(sobolset(num_tasks), 'MatousekAffineOwen');

        tasks = struct([]);
        for t = 1:num_tasks
            task_mult = scale_sobol(net(sobol_tasks(t), 1), task_mult_range);
            think_time = scale_sobol(net(sobol_tasks(t), 1), think_time_range);
            num_entries = randsample(entry_per_task_range, 1);

            % Entries
            sobol_entries = scramble(sobolset(num_entries), 'MatousekAffineOwen');
            entries = struct([]);
            for e = 1:num_entries
                service_mean = scale_sobol(net(sobol_entries(e), 1), service_time_range);
                service_scv = scale_sobol(net(sobol_entries(e), 1), service_scv_range);
                num_calls = randsample(calls_per_entry_range, 1);

                % Calls
                sobol_calls = scramble(sobolset(num_calls), 'MatousekAffineOwen');
                call_mean_times = scale_sobol(net(sobol_calls, 1), call_mean_times_range);
                call_time_means = scale_sobol(net(sobol_calls, 1), call_time_range);
                call_time_scvs = scale_sobol(net(sobol_calls, 1), call_scv_range);
                call_probs = dirichlet_sample(num_calls, dirichlet_alpha);

                calls = struct([]);
                for c = 1:num_calls
                    calls(c).call_mean_times = call_mean_times(c);
                    calls(c).call_time_mean = call_time_means(c);
                    calls(c).call_time_scv = call_time_scvs(c);
                    calls(c).call_probability = call_probs(c);
                end

                entries(e).service_time_mean = service_mean;
                entries(e).service_time_scv = service_scv;
                entries(e).calls = calls;
            end

            tasks(t).multiplicity = task_mult;
            tasks(t).think_time = think_time;
            tasks(t).entries = entries;
        end

        LQN.processors(p).multiplicity = proc_mult;
        LQN.processors(p).tasks = tasks;
    end
end

% === Helper: Scale Sobol Sample to Range ===
function x = scale_sobol(val, range)
    x = val * (range(2) - range(1)) + range(1);
end

% === Helper: Dirichlet Sample ===
function p = dirichlet_sample(n, alpha)
    raw = gamrnd(alpha * ones(1, n), 1);
    p = raw / sum(raw);
end
