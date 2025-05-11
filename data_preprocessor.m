% load your data
S = load("C:\Users\lizhu\OneDrive - Imperial College London\datafile\Sobol_samller\lqn_data\CombinedLQN.mat");        % or your filename
LQN = S.LQN;                      % 1×9730 struct
n = numel(LQN);

for i = 1:n
    A  = LQN(i).task_attributes;         % T×2
    Etp = LQN(i).task_on_processor_edges;% 2×#edges
    Ett = LQN(i).entry_on_task_edges;    % 2×#edges
    
    %--- 1) Identify reference vs server tasks ---
    refCols    = find(Etp(2,:) == 1);            % edges to processor #1
    refTasks   = Etp(1, refCols);                % task indices on proc #1
    allTasks   = (1:size(A,1))';
    servTasks  = setdiff(allTasks, refTasks)';   % the rest
    
    %--- 2a) Split task_attributes ---
    LQN(i).reference_task_attributes = A(refTasks, :);      % both cols
    LQN(i).server_task_attributes    = A(servTasks, 1);     % just first col
    
    %--- 2b) Split entry_on_task_edges ---
    isRefE = ismember(Ett(2,:), refTasks);
    cols   = find(isRefE);
    % map original task idx → new 1..#refTasks index
    newIdx = arrayfun(@(t) find(refTasks==t), Ett(2,cols));
    LQN(i).entry_on_reference_task_edges = [ Ett(1,cols); newIdx ];
    
    isServE = ismember(Ett(2,:), servTasks);
    cols    = find(isServE);
    newIdx  = arrayfun(@(t) find(servTasks==t), Ett(2,cols));
    LQN(i).entry_on_server_task_edges = [ Ett(1,cols); newIdx ];
    
    %--- 2c) Split task_on_processor_edges ---
    isRefP = ismember(Etp(1,:), refTasks);
    cols   = find(isRefP);
    newIdx = arrayfun(@(t) find(refTasks==t), Etp(1,cols));
    LQN(i).reference_task_on_processor_edges = [ newIdx; Etp(2,cols) ];
    
    isServP = ismember(Etp(1,:), servTasks);
    cols    = find(isServP);
    newIdx  = arrayfun(@(t) find(servTasks==t), Etp(1,cols));
    LQN(i).server_task_on_processor_edges = [ newIdx; Etp(2,cols) ];

    E = LQN(i).activity_on_entry_edges;  
    entries = unique(E(2,:));           % list of all entries in this model
    
    % preallocate
    numEntries = numel(entries);
    boundE = zeros(2, numEntries);      % will hold the “first” edge per entry
    subE   = [];                        % will accumulate the remainder
    
    % collect bound-vs-sub edges
    for k = 1:numEntries
        e = entries(k);
        idx = find(E(2,:) == e);        % all edges pointing to entry e
        boundE(:,k) = E(:, idx(1));     % the first one → bound-to activity
        if numel(idx) > 1
            subE = [ subE, E(:, idx(2:end)) ];  %#ok<AGROW>
        end
    end
    
    % re-index bound activities 1..numEntries
    oldBoundIdx = boundE(1,:);
    boundMap = containers.Map(oldBoundIdx, 1:numEntries);
    boundE(1,:) = cell2mat( values(boundMap, num2cell(oldBoundIdx)) );
    
    % re-index sub-activities 1..numSub
    oldSubIdx = subE(1,:);
    subU = unique(oldSubIdx);
    numSub = numel(subU);
    subMap = containers.Map(subU, 1:numSub);
    % remap each column of subE
    for j = 1:size(subE,2)
        subE(1,j) = subMap(subE(1,j));
    end
    
    % store the new edge lists
    LQN(i).bound_activity_on_entry_edges = boundE;
    LQN(i).sub_activity_on_entry_edges   = subE;
    
    % now split the attributes and re-index those arrays
    A = LQN(i).activity_attributes;   % assume M×? matrix
    
    % bound-to activity attributes (both columns)
    LQN(i).bound_activity_attributes = A(oldBoundIdx, :);
    
    % sub-activity attributes (same shape as original, but only rows oldSubIdx)
    LQN(i).sub_activity_attributes   = A(oldSubIdx, :);

        % 3) remap activity_activity_edges → bound_to_sub_activity_edges
    Eaa = LQN(i).activity_activity_edges;            % [2×E]
    newEaa = zeros(size(Eaa));
    for k = 1:size(Eaa,2)
        % row 1 was bound-to activity
        newEaa(1,k) = boundMap( Eaa(1,k) );
        % row 2 was subactivity
        newEaa(2,k) = subMap( Eaa(2,k) );
    end
    LQN(i).bound_to_sub_activity_edges                  = newEaa;
    % preserve ordering for its attributes
    LQN(i).bound_to_sub_activity_edge_attributes        = ...
        LQN(i).activity_activity_edge_attributes;

    % 4) remap activity_call_entry_edges → sub_activity_call_entry_edges
    Ece = LQN(i).activity_call_entry_edges;            % [2×C]
    newEce = zeros(size(Ece));
    for k = 1:size(Ece,2)
        % all these activities are sub-activities
        newEce(1,k) = subMap( Ece(1,k) );
        % entry index (row 2) stays the same
        newEce(2,k) = Ece(2,k);
    end
    LQN(i).sub_activity_call_entry_edges                = newEce;
    LQN(i).sub_activity_call_entry_edge_attributes     = ...
        LQN(i).activity_call_entry_edge_attributes;

    sce      = LQN(i).sub_activity_call_entry_edges;            % [2×C]  (subactivity → entry b)
    sce_attr = LQN(i).sub_activity_call_entry_edge_attributes; % [1×C]  (m values)
    b2s      = LQN(i).bound_to_sub_activity_edges;             % [2×E]  (bound→sub)
    b2s_attr = LQN(i).bound_to_sub_activity_edge_attributes;   % [1×E]  (p values)
    soe      = LQN(i).sub_activity_on_entry_edges;             % [2×S]  (sub → entry c)
    
    C = size(sce,2);
    newEdges = zeros(2, C);
    newAttr  = zeros(1, C);
    
    for k = 1:C
        a = sce(1,k);   % subactivity index
        b = sce(2,k);   % target entry
    
        % --- find p: the bound→sub edge attribute for this subactivity ---
        idx_p = find(b2s(2,:) == a, 1);          % should be exactly one
        p     = b2s_attr(idx_p);
    
        % --- get m: the subactivity→entry call attribute ---
        m     = sce_attr(k);
    
        % --- compute new attribute: log(p * m)  ---
        newAttr(k) = log(p * m);
    
        % --- find c: which entry this subactivity is bound to ---
        idx_c = find(soe(1,:) == a, 1);         % again, exactly one
        c     = soe(2, idx_c);
    
        % --- build the new direct entry→entry call edge (c → b) ---
        newEdges(:,k) = [c; b];
    end
    
    % store them
    LQN(i).entry_direct_call_entry_edges               = newEdges;
    LQN(i).entry_direct_call_entry_edge_attributes    = newAttr;

        % 1) how many entries are there?
    numEntries = numel( LQN(i).entry_response_times );  % or length(entry_queue_lengths)

    % 2) pull out your direct edges
    dE = LQN(i).entry_direct_call_entry_edges;   % [2×C] matrix of [source; target]

    % 3) build a MATLAB digraph with exactly numEntries nodes
    G = digraph( dE(1,:), dE(2,:), [], numEntries );

    % 4) compute all‐pairs shortest distances (unweighted = hop count)
    D = distances(G);  % numEntries×numEntries matrix, Inf if no path

    % 5) extract all u→v with 1 ≤ distance < Inf
    [U, V] = find( D>0 & D<Inf );               % column vectors of indices
    Eglob  = [U'; V'];                          % 2×#globalEdges
    dist   = D( sub2ind(size(D), U, V) )';      % 1×#globalEdges

    % 6) store into your struct
    LQN(i).entry_global_call_entry_edges               = Eglob;
    LQN(i).entry_global_call_entry_edge_attributes    = dist;

    orig_p = LQN(i).bound_to_sub_activity_edge_attributes;  
    LQN(i).bound_to_sub_activity_edge_attributes = log(orig_p);

        LQN(i).reference_task_attributes(:,1) = ...
        LQN(i).reference_task_attributes(:,1) / 10;
    LQN(i).reference_task_attributes(:,2) = ...
        LQN(i).reference_task_attributes(:,2) / 3;

    % server_task_attributes: ÷10
    LQN(i).server_task_attributes = ...
        LQN(i).server_task_attributes / 10;

    % sub_activity_attributes: ÷3
    LQN(i).sub_activity_attributes = ...
        LQN(i).sub_activity_attributes / 3;

    % bound_activity_attributes: ÷3
    LQN(i).bound_activity_attributes = ...
        LQN(i).bound_activity_attributes / 3;
end

toRemove = { ...
  'task_attributes', 'task_on_processor_edges', 'entry_on_task_edges', ...
  'activity_attributes', 'activity_on_entry_edges', ...
  'activity_activity_edges', 'activity_activity_edge_attributes', ...
  'activity_call_entry_edges', 'activity_call_entry_edge_attributes', ...
  'sub_activity_call_entry_edges', 'sub_activity_call_entry_edge_attributes'};

% Drop them from the entire struct array in one go:
LQN = rmfield(LQN, toRemove);
save('LQN_final.mat','LQN');
