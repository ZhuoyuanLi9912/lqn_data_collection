function decimals = generateOnePlaceDecimalsProbability(n)
% generateOnePlaceDecimals generates n one-place decimals that sum to 1.
%   decimals = generateOnePlaceDecimals(n) returns an n-by-1 vector of 
%   decimals (with one digit after the decimal point) whose sum equals 1.
%
%   Input:
%       n - An integer between 2 and 9.
%
%   Output:
%       decimals - An n-by-1 double vector of one-place decimals.

    % Validate input
    if n < 1 || n > 9 || floor(n) ~= n
        error('n must be an integer between 2 and 9.');
    end

    total = 10; % Because we want the sum to be 1 (i.e., 10/10)

    % Randomly select n-1 distinct cut points from 1 to total-1 (i.e. 1 to 9)
    cutPoints = sort(randperm(total-1, n-1));

    % Calculate the parts by taking differences between consecutive cut points,
    % including the start (0) and the end (total).
    parts = [cutPoints, total] - [0, cutPoints];

    % Convert the parts to one-place decimals by dividing by 10
    decimals = (parts / 10);

end
