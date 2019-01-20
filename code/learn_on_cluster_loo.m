%% Script intended to predict performance in cognitive tasks according to inhale / exhale trace
%% Set up and initialization
function [r, masks] = learn_on_cluster_loo(rep)
fnames = 'net3_MOREPARAMS_mod_betassplit_12165_16524_mod.xlsx';
% subjnames = {'alsp5',
%     'amdu21',
%     'asma2',
%     'asya20',
%     'beco17',
%     'bele13',
%     'caho11',
%     'eish22',
%     'etma23',
%     'gugl14',
%     'guma29',
%     'heha26',
%     'irha19',
%     'isot12',
%     'itme3',
%     'ittz18',
%     'mago7',
%     'nots4',
%     'orba30',
%     'paru31',
%     'raez27',
%     'roge8',
%     'saly9',
%     'sasi6',
%     'shdu16',
%     'shha25',
%     'takr15',
%     'yaat24',
%     'yakr28',
%     };
%rmv = [9, 15, 17, 26];
%rmv =  [1 2 3 9  13 15 16 17 18 21 22 23 24 25 29 ] % back ot original set

rmv = 17;
%subjnames(rmv) = [];
%%
Y = readtable('net3_subj_perf.xlsx', 'ReadRowNames', true);
Y(rmv,:) = [];
y_in = Y.in;
y_ex = Y.ex;
%y_delta = Y.delta;
%y_avg = Y.avg;

%%
f_name = fnames;
X = readtable(f_name, 'ReadRowNames', false);
X(rmv, :) = [];
[X_in, X_ex, ~] = preprocess_input(X);
%%
XX = X_in - X_ex;
yy = zscore(zscore(y_in) - zscore(y_ex));
y_to_use = yy;
rng(rep)
if rep == 1
    yy = y_to_use;
else
    yy = y_to_use(randperm(length(yy)));
end
Nperms = length(yy);
mse_vec = zeros(1, Nperms);
pred = zeros(1, Nperms);
masks = zeros(Nperms, size(X_in, 2));
for ii = 1:Nperms
    test_idx = ii;
    train_idx = [1:(ii-1) ii+1:length(yy)];

    x1 = XX(train_idx, :);
    y1 = yy(train_idx); y2 = yy(test_idx);
    [Mdl, mask] = learn_model_with_lasso(x1, y1, false, false);

    x2 = XX(test_idx, mask);
    mse_vec(ii) = mean((Mdl.predict(x2) - y2).^2);
    pred(ii) = Mdl.predict(x2);
    masks(ii, :) = mask;
end
r = corr(pred(:), yy(:));
%save(sprintf('outputs/x_in-x_ex_%d_%d.mat', rep, Nperms), 'masks', 'pred', 'mse_vec', 'r')