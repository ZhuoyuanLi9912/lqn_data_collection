% --- 1) Load your struct array from disk ---
% Suppose your file is called 'myData.mat' and inside it the variable is named S
data = load("C:\GLQN\GLQN experiment\LQN_final.mat",'LQN');  
LQN = data.LQN;    % now S is your 1×N struct array

% --- 2) Convert 1×N struct S into N×1 cell C ---
LQN_cell = reshape( num2cell(LQN), [], 1 );

% --- Verification (optional) ---
disp(['Original size: ' mat2str(size(LQN))])
disp(['New size:      ' mat2str(size(LQN_cell))])
% --- after converting S into C as above ---
save('LQN_cell.mat','LQN_cell');
