% Create an empty cell array for 2 structures (you can change the size)
cellOfStructs = cell(1, 1);

% === Structure 1 ===
S1.processor_attributes = [3;2;2;1;1];
S1.task_attributes = [6,0;6,0;6,0;5,0;5,0;3,0;2,0;2,0;1,0];
S1.task_on_processor_edges = [1,2,3,4,5,6,7,8,9;1,1,1,2,3,4,4,5,5];
S1.entry_on_task_edges = [1,2,3,4,5,6,7,8,9,10,11,12,13,14;1,2,3,4,5,5,5,6,6,6,7,7,8,9];
S1.activity_attributes = [0.5,1;1,1;2,1;1.2,1;0.1,1;0.1,1;0.1,1;2.1,1;3.1,1;0.1,1;0.1,1;0.1,1;3.7,1;0.1,1;0.1,1;4.4,1;3.6,1;4.8,1;1.9,1;2.2,1;2.2,1;1.3,1];
S1.activity_on_entry_edges = [1,1;2,2;3,3;4,4;5,4;6,4;7,4;8,5;9,6;10,6;11,6;12,6;13,7;14,7;15,7;16,8;17,9;18,10;19,11;20,12;21,13;22,14]';
S1.activity_activity_edges = [4,5;4,6;4,7;9,10;9,11;9,12;13,14;13,15]';
S1.activity_activity_edge_attributes = [0.4;0.3;0.3;0.3;0.3;0.4;0.5;0.5];
S1.activity_call_entry_edges = [1,4;2,4;3,4;5,5;6,6;7,7;10,8;11,9;12,10;14,11;15,12;16,13;17,13;18,13;19,14;20,14]';
S1.activity_call_entry_edge_attributes = [1;1;1;0.5;0.5;0.5;3;3;3;1;1;1;1;1];

% Assign to cell
cellOfStructs{1} = S1;

% Rename the cell array to LQN_dataset
LQN_dataset = cellOfStructs;

% Save to a .mat file
save('Microsystem_GNN.mat', 'LQN_dataset');
