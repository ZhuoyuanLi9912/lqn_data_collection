%% clean_all_mat_files.m
% Remove fully‑empty structure elements in every *.mat file of a folder.
% ----------------------------------------------------------------------
% HOW TO RUN:
%   • Put this script anywhere on your MATLAB path.
%   • Edit dirPath below (or prompt for it).
%   • run clean_all_mat_files
%
% Assumptions
%   • Each .mat file contains one or more structure arrays.
%   • A structure element is “empty” when *all* its fields are empty.
%   • You are OK with overwriting the same .mat file (make a backup first!).

clear, clc

% ---------- 1. folder to process ---------------------------------------
dirPath = uigetdir(pwd,'Pick the folder with your MAT files');   % GUI prompt
if dirPath == 0,  return,  end                                   % user cancelled

% ---------- 2. find the *.mat files (skip *_log and others) ------------
matFiles = dir(fullfile(dirPath, '*.mat'));

% ---------- 3. iterate through each file -------------------------------
for k = 1:numel(matFiles)
    f = fullfile(matFiles(k).folder, matFiles(k).name);
    fprintf('\n>>> %s\n', matFiles(k).name);

    % Peek inside the file without loading everything
    vars = whos('-file', f);

    changed = false;

    % ---------- 4. process every variable that is a structure ----------
    for v = 1:numel(vars)
        if ~strcmp(vars(v).class, 'struct'),  continue,  end   % skip non‑structs

        data = load(f, vars(v).name);                % load just this variable
        S = data.(vars(v).name);                     % the structure array

        emptyElem = arrayfun(@(x) all(structfun(@isempty,x)), S);

        if any(emptyElem)
            S(emptyElem) = [];                       % delete the empties
                % ---- add these two lines ------------------------------------------
            eval([vars(v).name ' = S;']);            % or use assignin
            save(f, vars(v).name, '-append');        % no more "not found"
            % -------------------------------------------------------------------
            save(f, vars(v).name, '-append');        % overwrite only this var
            fprintf('    %s: removed %d empty elements\n', vars(v).name, sum(emptyElem));
            changed = true;
        else
            fprintf('    %s: no empties found\n', vars(v).name);
        end
    end

    if ~changed
        fprintf('    (file unchanged)\n');
    end
end

fprintf('\nAll done – checked %d MAT files in "%s".\n', numel(matFiles), dirPath);
