function [X_in, X_ex, IN_columns] = preprocess_input(X)
%PREPROCESS_ Summary of this function goes here
%   Detailed explanation goes here
    IN_columns = ~cellfun('isempty', regexp(X.Properties.VariableNames, 'IN_.*'));
    EX_columns = cellfun('isempty', regexp(X.Properties.VariableNames, 'IN_.*'));
    
    X_in = table2array(X(:, IN_columns));
    X_ex = table2array(X(:, EX_columns));
    
    %mask = 1:size(X_in, 2); %[25:48, 97:120]
    mask = 1:size(X_in, 2);
    %mask = (mod(mask, 6) >= 2 ) & (mod(mask, 6) <= 3);
    %mask = (mod(mask, 30) <=6) | (mod(mask, 30) > 12);
    %mask(1:24) = 0;
    %mask(49:72) = 0;
    %mask(97:120) = 0;
    X_in = zscore(X_in(:, mask));
    X_ex = zscore(X_ex(:, mask));
    IN_columns = X.Properties.VariableNames(IN_columns);
    IN_columns = IN_columns(mask);
    %for ii = 1:floor(size(X_in, 2) / 6)
    %    X_in_2(:, ii) = mean(X_in(:, 6*(ii-1) + 1:6*ii), 2);
    %    X_ex_2(:, ii) = mean(X_in(:, 6*(ii-1) + 1:6*ii), 2);
    %end
    %X_in = X_in_2;
    %X_ex = X_ex_2;
    %
    for ii = 1:2:size(X_in, 2)
        idx = floor((ii-1)/2 + 1);
        X_in_2(:, idx) = (X_in(:, ii) + X_in(:, ii + 1))/2;
        X_ex_2(:, idx) = (X_ex(:, ii) + X_ex(:, ii + 1))/2;
    end
    X_in = X_in_2;
    X_ex = X_ex_2;
    IN_columns = IN_columns(2:2:end);
end

