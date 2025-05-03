    tic
    model = LayeredNetwork('LQN');
        
    % first layer
    P1 = Processor(model, 'Layer1', 1, SchedStrategy.PS);
    T1 = Task(model, 'Client1', 10, SchedStrategy.REF).on(P1);
    E1 = Entry(model, 'Browse1').on(T1);
    T2 = Task(model, 'Client2',10, SchedStrategy.REF).on(P1);
    E2 = Entry(model, 'Browse2').on(T2);
    T3 = Task(model, 'Client3',10, SchedStrategy.REF).on(P1);
    E3 = Entry(model, 'Browse3').on(T3);
    T1.setThinkTime(Exp.fitMean(1));
    T2.setThinkTime(Exp.fitMean(2));
    T3.setThinkTime(Exp.fitMean(3));
        
        
    %second layer
    P2 = Processor(model, 'Layer2', 1, SchedStrategy.PS);
    T4 = Task(model, 'Router', 10, SchedStrategy.FCFS).on(P2);
    E4 = Entry(model, 'address').on(T4);

    %third layer
    P3 = Processor(model, 'Layer3', 2, SchedStrategy.PS);
    T5 = Task(model, 'FrontEnd', 5, SchedStrategy.FCFS).on(P3);
    E5 = Entry(model, 'home').on(T5);
    E6 = Entry(model, 'toCart').on(T5);
    E7 = Entry(model, 'toCat').on(T5);

    %fourth layer
    P4 = Processor(model, 'Layer4', 1, SchedStrategy.PS);
    T6 = Task(model, 'Cart', 5, SchedStrategy.FCFS).on(P4);
    E8 = Entry(model, 'add').on(T6);
    E9 = Entry(model, 'delete').on(T6);
    E10 = Entry(model, 'get').on(T6);
    T7 = Task(model, 'Catalog', 5, SchedStrategy.FCFS).on(P4);
    E11 = Entry(model, 'item').on(T7);
    E12 = Entry(model, 'list').on(T7);
    

    %fifth layer
    P5 = Processor(model, 'Layer5', 1, SchedStrategy.PS);
    T8 = Task(model, 'CartDB', 3, SchedStrategy.FCFS).on(P5);
    E13 = Entry(model, 'queryCart').on(T8);
    T9 = Task(model, 'CatDB', 3, SchedStrategy.FCFS).on(P5);
    E14 = Entry(model, 'queryCat').on(T9);


    A1 = Activity(model, 'A1', Exp.fitMean(1)).on(T1).boundTo(E1).synchCall(E4,1);
   
    A2 = Activity(model, 'A2', Exp.fitMean(1)).on(T2).boundTo(E2).synchCall(E4,1);
    
    A3 = Activity(model, 'A3', Exp.fitMean(1)).on(T3).boundTo(E3).synchCall(E4,1);
    
    A4 = Activity(model, 'A4', Exp.fitMean(0.6)).on(T4).boundTo(E4);
    A5 = Activity(model, 'A5', Exp.fitMean(0.6)).on(T4).synchCall(E5,0.5).repliesTo(E4);
    A6 = Activity(model, 'A6', Exp.fitMean(0.6)).on(T4).synchCall(E6,0.5).repliesTo(E4);
    A7 = Activity(model, 'A7', Exp.fitMean(0.6)).on(T4).synchCall(E7,0.5).repliesTo(E4);
    T4.addPrecedence(ActivityPrecedence.OrFork(A4,{A5,A6,A7},[0.4,0.3,0.3]));

    A8 = Activity(model, 'A8', Exp.fitMean(1.2)).on(T5).boundTo(E5).repliesTo(E5);
    
    A9 = Activity(model, 'A9', Exp.fitMean(3)).on(T5).boundTo(E6);
    A10 = Activity(model, 'A10', Exp.fitMean(2.2)).on(T5).synchCall(E8,3).repliesTo(E6);
    A11 = Activity(model, 'A11', Exp.fitMean(2.2)).on(T5).synchCall(E9,3).repliesTo(E6);
    A12 = Activity(model, 'A12', Exp.fitMean(2.2)).on(T5).synchCall(E10,3).repliesTo(E6);
    T5.addPrecedence(ActivityPrecedence.OrFork(A9,{A10,A11,A12},[0.4,0.3,0.3]));

    A13 = Activity(model, 'A13', Exp.fitMean(3)).on(T5).boundTo(E7);
    A14 = Activity(model, 'A14', Exp.fitMean(0.7)).on(T5).synchCall(E11,0.3).repliesTo(E7);
    A15 = Activity(model, 'A15', Exp.fitMean(0.7)).on(T5).synchCall(E12,0.3).repliesTo(E7);
    T5.addPrecedence(ActivityPrecedence.OrFork(A13,{A14,A15},[0.5,0.5]));

    A16 = Activity(model, 'A16', Exp.fitMean(7.4)).on(T6).boundTo(E8).synchCall(E13,1).repliesTo(E8);
    A17 = Activity(model, 'A17', Exp.fitMean(5.6)).on(T6).boundTo(E9).synchCall(E13,1).repliesTo(E9);
    A18 = Activity(model, 'A18', Exp.fitMean(4.8)).on(T6).boundTo(E10).synchCall(E13,1).repliesTo(E10);
    
    A19 = Activity(model, 'A19', Exp.fitMean(1.9)).on(T7).boundTo(E11).synchCall(E14,1).repliesTo(E11);
    A20 = Activity(model, 'A20', Exp.fitMean(2.2)).on(T7).boundTo(E12).synchCall(E14,1).repliesTo(E12);

    A21 = Activity(model,'A21', Exp.fitMean(2.2)).on(T8).boundTo(E13).repliesTo(E13);
    A22 = Activity(model,'A22', Exp.fitMean(1.3)).on(T9).boundTo(E14).repliesTo(E14);

    
    %SolverLN(model,@SolverNN).getAvgTable
    options = SolverLQNS.defaultOptions;
    options.verbose = true;
    options.method = 'lqns';
    lqnssolver = SolverLQNS(model, options);
    AvgTableLQNS = lqnssolver.getAvgTable

    toc

    options2 = SolverLQNS.defaultOptions;
    options2.method = 'lqsim';
    lqnssolver2 = SolverLQNS(model, options2);
    AvgTableLQNS2 = lqnssolver2.getAvgTable

    num_processors = 5;
    num_tasks = 9;
    num_entries = 14;

    entry_start_row = num_processors + num_tasks + 1;
    entry_end_row = entry_start_row + num_entries - 1;

    % Extract relevant rows for entries
    entry_rows = AvgTableLQNS (entry_start_row:entry_end_row, :);

    % Extract queue lengths, response times, and throughputs
    queue_lengths = table2array(entry_rows(:, 3));   % 3rd column: queue length
    response_times = table2array(entry_rows(:, 5)); % 5th column: response time
    throughputs = table2array(entry_rows(:, 7));    % 7th column: throughput

    entry_rows_lqns = AvgTableLQNS2 (entry_start_row:entry_end_row, :);

    % Extract queue lengths, response times, and throughputs
    queue_lengths_lqns = table2array(entry_rows_lqns(:, 3));   % 3rd column: queue length
    response_times_lqns = table2array(entry_rows_lqns(:, 5)); % 5th column: response time
    throughputs_lqns = table2array(entry_rows_lqns(:, 7));    % 7th column: throughput

    queue_lengths_mare = mean(abs(queue_lengths - queue_lengths_lqns) ./ abs(queue_lengths+1e-8))
    response_times_mare = mean(abs(response_times - response_times_lqns) ./ abs(response_times+1e-8))
    throughputs_mare = mean(abs(throughputs - throughputs_lqns) ./ abs(throughputs+1e-8))