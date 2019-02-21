function  data = nanZscore( data, nan_replace )
%NANZSCORE Summary of this function goes here
%   Detailed explanation goes here
if nargin < 2
    nan_replace = false;
end

if nan_replace
    data_median_vals = nanmedian(data);
    for col = 1:size(data, 2)
        x = isnan(data(:, col));
        data(x, col) = data_median_vals(col);
    end
end

s = size(data, 2);
for i = 1:s
    if nanstd(data(:, i)) == 0
        data(:, i) = zeros(size(data, 1), 1);
    else
        data(:, i) = (data(:, i)-nanmean(data(:, i))) / nanstd(data(:, i));
    end
end

end

