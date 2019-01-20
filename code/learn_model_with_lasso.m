function [Mdl, mask] = learn_model_with_lasso(XTrain, yTrain, to_draw, to_cv_model)
%LEARN_MODEL_WITH_LASSO Summary of this function goes here
%   Detailed explanation goes here
if nargin < 4
    to_cv_model = false;
end
[BB, FFitInfo] = lasso(XTrain, yTrain, 'cv', 7);
mask = abs(BB(:, FFitInfo.Index1SE)) > eps;

if sum(mask) == 0
    mask = abs(BB(:, FFitInfo.IndexMinMSE)) > eps;
end
if sum(mask) == 0
    mask = abs(BB(:, FFitInfo.IndexMinMSE-1)) > eps;
end
 
XTrain = XTrain(:, mask);

if to_cv_model
    n = length(yTrain);
    cvp = cvpartition(length(yTrain), 'LeaveOut');
    numvalidsets = cvp.NumTestSets;
    lossvals = zeros(numvalidsets, 1);
    for k = 1:numvalidsets
        X = XTrain(cvp.training(k),:);
        y = yTrain(cvp.training(k),:);
        Xvalid = XTrain(cvp.test(k),:);
        yvalid = yTrain(cvp.test(k),:);

        %LM = fitrsvm(X, y, 'KernelFunction', 'linear');
        LM = fitrlinear(X, y);
        %LM = fitrlinear(X, y);
        %nca = fitrsvm(X,y);
        %[B{k}, FitInfo{k}] = lasso(X, y);

        lossvals(k) = loss(LM, Xvalid, yvalid);
        mseVals(1:2, k) = [yvalid, LM.predict(Xvalid)];
    end
    meanloss = mean(lossvals, 2);
    if ispc
        fprintf('Loss on cross-validated data is %.2f\n', mean(meanloss))
    end
end

%Mdl = fitrsvm(XTrain, yTrain);
Mdl = fitrlinear(XTrain, yTrain);

%%
if to_draw
    figure,
    mask_res = mseVals(1, :) > -20;
    scatter(mseVals(1, mask_res), mseVals(2, mask_res))
    [r, p] = corr(mseVals(1, mask_res)', mseVals(2, mask_res)');
    fprintf('r = %.3f, p = %.2f\n', r, p)
end
end

