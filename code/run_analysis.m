%% Script intended to predict performance in cognitive tasks according to inhale / exhale trace
% 1 alsp5__156
% 2 amdu21_335
% 3 asma2__382
% 4 asya20_339
% 5 beco17_370
% 6 bele13_482
% 7 caho11_587
% 8 eish22_379
% 9 etma23_366
% 10 gugl14_293
% 11 guma29_395
% 12 heha26_436
% 13 irha19_395
% 14 isot12_504
% 15 itme3__414
% 16 ittz18_409
% 17 mago7__426
% 18 nots4__413
% 19 orba30_562
% 20 paru31_382
% 21 raez27_479
% 22 roge8__572
% 23 saly9__359
% 24 sasi6__378
% 25 shdu16_472
% 26 shha25_508
% 27 takr15_703
% 28 yaat24_620
% 29 yakr28_264

%% Set up and initialization
clear
close all
fnames = 'net3_MOREPARAMS_mod_betassplit_12165_16524_mod.xlsx';
subjnames = {'alsp5',
    'amdu21',
    'asma2',
    'asya20',
    'beco17',
    'bele13',
    'caho11',
    'eish22',
    'etma23',
    'gugl14',
    'guma29',
    'heha26',
    'irha19',
    'isot12',
    'itme3',
    'ittz18',
    'mago7',
    'nots4',
    'orba30',
    'paru31',
    'raez27',
    'roge8',
    'saly9',
    'sasi6',
    'shdu16',
    'shha25',
    'takr15',
    'yaat24',
    'yakr28',
    };
%rmv = [9, 15, 17, 26];
rmv = 17;
%rmv =  [1 2 3 9  13 15 16 17 18 21 22 23 24 25 29 ] % back ot original set
subjnames(rmv) = [];
Y = readtable('net3_subj_perf.xlsx', 'ReadRowNames', true);
Y(rmv,:) = [];
y_in = Y.in;
y_ex = Y.ex;
y_delta = Y.delta;
y_avg = Y.avg;

%%
f_name = fnames;

X = readtable(f_name, 'ReadRowNames', false);
X(rmv, :) = [];
[X_in, X_ex, variable_names] = preprocess_input(X);
%%
Nperms = 400;
%XX = X_in - X_ex;
%yy = zscore(zscore(y_in) - zscore(y_ex));
XX = X_in + X_ex;
yy = zscore(y_avg);
y_to_use = yy;
reps = 500;
mse_vec = zeros(reps, Nperms);
r_vec = zeros(reps, Nperms);
masks = zeros(reps, Nperms, size(X_in, 2));
for jj = 1:reps
    if jj == 1
        yy = y_to_use
    else
        yy = y_to_use(randperm(length(yy)));
    end
    parfor ii = 1:Nperms
        %yy = y_to_ues(randperm(length(y_to_ues)));
        test_idx = randperm(length(subjnames), 10);
        train_idx = setdiff(1:length(subjnames), test_idx);

        x1 = XX(train_idx, :);
        y1 = yy(train_idx); y2 = yy(test_idx);
        [Mdl, mask] = learn_model_with_lasso(x1, y1, false);

        x2 = XX(test_idx, mask);
        mse_vec(jj, ii) = mean((Mdl.predict(x2) - y2).^2);
        r_vec(jj, ii) = corr(Mdl.predict(x2), y2);
        masks(jj, ii, :) = mask;
    end
    disp('##################################################################')
end
save(sprintf('x_in-x_ex_%d_%d_sum.mat', reps, Nperms), 'masks', 'r_vec', 'mse_vec')
%%
%%
figure, 
subplot(2,2,1)
d = diag(corr(randn(10, 10000), randn(10, 10000)));
hold on; 
histogram(d); histogram(fisherz(r_vec(1,:)));
ylabel('occurance')
title('compare with random data')
subplot(2,2,2)
hold on; histogram(fisherz(r_vec(2:end-1,:)), 'normalization', 'pdf'); histogram(fisherz(r_vec(1,:)), 'normalization', 'pdf')
ylabel('pdf')
title('compare with shuffeled data')
subplot(2,2,3)
hold on; histogram(mean(fisherz(r_vec(2:end-1,:)), 2), -0.6:0.1:0.6, 'normalization', 'probability'); 
plot(mean(fisherz(r_vec(1,:))), 0, 'r*')
title('shuffeled data results')
subplot(2,2,3)
hold on; histogram(mean(fisherz(r_vec(2:end-1,:)), 2), -0.6:0.1:0.6, 'normalization', 'probability'); 
plot(mean(fisherz(r_vec(1,:))), 0, 'r*')
title('shuffeled data results')
subplot(2,2,4)
bar(sum(squeeze(masks(1, : ,:))));
a = gca;
a.XTick = 1:180;
a.XTickLabel = variable_names;
a.XTickLabelRotation = 45;
a.FontSize = 4;