clear;
Nperms = 10000;
M = 5000;
r = zeros(M, Nperms);
mask = zeros(M, Nperms, 60);
mse_ = zeros(M, Nperms);
for ii = 1:M
    try
        load(sprintf('Z:/aharonr/20180630/outputs_updated/x_in-x_ex_%d_%d.mat', ii, Nperms), 'masks', 'r_vec', 'mse_vec')
    catch
        fprintf('Error - %d\n', ii);
        continue;
    end
    r(ii, :) = fisherz(r_vec);
    mask(ii, :, :) = masks;
    mse_(ii, :) = mse_vec;
end
%
mse_(mean(r, 2)==0, :) = [];
mask(mean(r, 2)==0, :, :) = [];
r(mean(r, 2)==0, :) = [];
r_mean = mean(r, 2);
save('workspace_no_between', '-v7.3')
%%
figure, hold on ;
histogram(ifisherz(r_mean), 'normalization', 'probability')
plot(ifisherz(r_mean(1)), 0 , 'r*')
%
[a, idx] = sort(r_mean, 'descend');
find(a==r_mean(1))
%%
figure, hold on ;histogram(mse_)
%%
for ii = 2:size(r, 1)
    [~, p, ~, stat] = ttest2(r(1, :), r(ii, :));
    p_vec(ii) = p;
    t_vec(ii) = stat.tstat;
end
%%
myC1 = [1 0.4 0];
myC2 = [0 0.4 1];
myC3 = (myC1 + myC2)/2 - [0 0.1 0];
%%
f = figure;
setFigureA4PDF(f, [21, 21]);

subplot(4,4,1); hold on; 
h1a = histogram(ifisherz(r(1,:))); 
h1b = histogram(ifisherz(r(2,:)));
h1a.EdgeColor = 'w';
h1b.EdgeColor = 'w';
h1a.FaceColor = myC1;
h1b.FaceColor = myC2;
title('Compare correlations on many partitions')
legend({'Real Data', 'Random Shuffeled Data'}, 'Location', 'NW');

subplot(4,4,2); hold on; 
h2a = histogram(ifisherz(r(1,:))); 
h2b = histogram(ifisherz(r(100,:)));
h2a.EdgeColor = 'w';
h2b.EdgeColor = 'w';
h2a.FaceColor = myC1;
h2b.FaceColor = myC2;
title('Compare correlations on many partitions')
legend({'Real Data', 'Random Shuffeled Data'}, 'Location', 'NW');

subplot(4,4,5); hold on; 
h3a= histogram(ifisherz(r(1,:))); 
h3b = histogram(ifisherz(r(idx(1),:)));
title('Compare correlations on many partitions')
legend({'Real Data', 'Best Shuffeled Data'}, 'Location', 'NW');

h3a.EdgeColor = 'w';
h3b.EdgeColor = 'w';
h3a.FaceColor = myC1;
h3b.FaceColor = myC2;

subplot(4,4,6); hold on;
h4a = histogram(ifisherz(r(1,:))); 
h4b = histogram(ifisherz(r(idx(end),:)));
h4a.EdgeColor = 'w';
h4b.EdgeColor = 'w';
h4a.FaceColor = myC1;
h4b.FaceColor = myC2;
title('Compare correlations on many partitions')
legend({'Real Data', 'Worst Shuffeled Data'}, 'Location', 'NW');

subplot(2,2,2); hold on; 
h222a = histogram(ifisherz(r(1,:)), 'normalization', 'pdf');
h222b = histogram(ifisherz(r(:)), 50, 'normalization', 'pdf'); 
%ylabel('occurence')
title('Compare correlations on partitions')
h222a.EdgeColor = 'w';
h222a.FaceColor = myC1;
h222b.EdgeColor = 'w';
h222b.FaceColor = myC2;
legend({'Real Data', 'All Shuffeled Data'}, 'Location', 'NW');

subplot(4,2,5)
hold on;
h425a =  histogram(mean(ifisherz(r(2:end-1,:)), 2), -0.8:0.025:0.8, 'normalization', 'probability'); 
plt = stem(mean(ifisherz(r(1,:))), .08,  'k', 'marker', 'none');
title('Shuffeled data r-values')
h425a.EdgeColor = 'w';
h425a.FaceColor = myC3;

subplot(4,2,7)
h427 = histogram(t_vec, 'normalization', 'probability')
h427.EdgeColor = 'w';
h427.FaceColor = myC3;
title('Shuffled data t values')

subplot(2,2,4)
bargraph = bar(mean(squeeze(mask(1, :, :))), 'FaceColor', myC3, 'EdgeColor', 'none');
title('Feature selected for the model')
a = gca;
a.XTick = 1:length(variable_names);
a.XTickLabel = variable_names;
a.XTickLabelRotation = 90;
a.FontSize = 6;