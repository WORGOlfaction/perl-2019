%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Supplementary Code for Perl et al. 2019
%%%
%%% This script loads a database containing all behavioral and
%%% physiological (respiratory) data collected during the self-initiation sessions
%%% With 3 types of tasks - spatial, lexical and math.
%%%
%%% Next, to estimate respiratory pattern fluctuations as a function of
%%% trial onset, it calculates the deviation from this expected
%%% pattern by comparing to surrogate randomly selected time-points
%%%
%%% These results correspond to Figure 1 in the manuscript
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all
clear all
Database = 'all_shapes.mat'  %choose a dataset to load
load(Database) %choose a dataset to load

%parameters
num_trials = 25;
testType = DATA(1).name(6:10)
upsampleFactor = 10; %data were sampled at 100Hz. To aid with visualization they were resampled to 1KHz to match with the rest of
% the data collected in this project

PARAM_ITER_FACTOR = 100  %number of iterations for comparison of actual signal with surrogate data
TIMEWINDOW_POOL = [ 100:100:4000 ] ; %instances (delta t is msec) following time zero (i.e., button press) to conduct the statistical analyses
Fs = 1000 %target sampling rate
respBlocks = [] ;
wind_in_sec = 5*Fs; %window size (two-sided) to extract respiratory and behavioral signals around
LOW_PASS_THRESH = 100; %low pass (optional)

repsCh = 2 %channel for respiratory  data
buttonCh = 4 %channel for initiation button press
buttonAnswerCh = 5 %channel for answering button press
AUC_window = 1500;

whitebg('w')
boot_iter_num_withinSubj = 3
close all

%%
%go over subjects in MAT file
for SUBJ =1:length(DATA)   %:size(DATA,2)
    close all
    SUBJ
    
    %resample
    dataPerSubj = DATA(SUBJ).data;
    dataPerSubj = resample(dataPerSubj,upsampleFactor,1);
    
    %low pass filtering (optional)
    resp_unfiltered = dataPerSubj(:,repsCh);
    freq=linspace(0,Fs,length(resp_unfiltered));
    respFFT=(fft(resp_unfiltered));
    myWindow=zeros(1,length(freq));
    myWindow(freq<LOW_PASS_THRESH)=1;
    filteredSignal=respFFT.*myWindow';
    dataPerSubj(:,repsCh)=ifft(filteredSignal,'symmetric');
    
    respTrace = dataPerSubj(:,repsCh);
    
    %define respiratory signal
    resp(SUBJ).trace =  zscore(respTrace);
    resp(SUBJ).phase = angle(hilbert( resp(SUBJ).trace ));
    resp(SUBJ).trace_z =  zscore(resp(SUBJ).trace);
    
    % digitize triggers
    % trial start and end signal
    for i = 1:length(dataPerSubj)
        if abs(dataPerSubj(i,buttonCh)) >= 0.05; %predefind voltage threshold
            dataPerSubj(i,buttonCh) = 1;
        else
            dataPerSubj(i,buttonCh) = 0;
        end
    end
    
    trig(SUBJ).trace = dataPerSubj(:,buttonCh);
    
    % subject response
    for i = 1:length(dataPerSubj)
        if abs(dataPerSubj(i,buttonAnswerCh)) >= 0.01;
            dataPerSubj(i,buttonAnswerCh) = 1;
        else
            dataPerSubj(i,buttonAnswerCh) = 0;
        end
    end
    
    disp('digitize OK')
    
    % find peaks (triggers)
    MINPEAKDISTANCE = 5000;
    if strcmp(Database(5:9), 'words')
        MINPEAKDISTANCE = 1000;
    end
    
    [temp,trials]= findpeaks(dataPerSubj(:,4),'MINPEAKDISTANCE', MINPEAKDISTANCE );
    [temp,answerTime]= findpeaks(dataPerSubj(:,5), 'MINPEAKDISTANCE', MINPEAKDISTANCE);
    trials_endTime = trials(2:2:end);
    trials_startsTime = trials(1:2:end);
    answerTime(answerTime < trials_startsTime(1)) = [];
    answerTime(diff(answerTime) < 2000) = [];
    
    CheckpointNumOfTrialsAnswered(SUBJ) = numel(answerTime);
    
    %checkpoint
    if length(trials_startsTime) ~= num_trials ;
        disp('# of trials is not 25!')
        disp('but')
        disp(length(trials_startsTime));
    end
    
    trials_requested(SUBJ).idx = trials_startsTime;
    trials_answered(SUBJ).idx = answerTime;
    disp('findPeaks OK')
    %
    
    for j = 1:num_trials
        respBlocks(:,j,SUBJ) =  resp(SUBJ).trace(trials_requested(SUBJ).idx(j)-wind_in_sec:...
            trials_requested(SUBJ).idx(j)+wind_in_sec-1);
        respBlocks_z(:,j,SUBJ) =  resp(SUBJ).trace_z(trials_requested(SUBJ).idx(j)-wind_in_sec:...
            trials_requested(SUBJ).idx(j)+wind_in_sec-1);
        trigBlocks(:,j,SUBJ) =  trig(SUBJ).trace(trials_requested(SUBJ).idx(j)-wind_in_sec:...
            trials_requested(SUBJ).idx(j)+wind_in_sec-1);
    end
    
    dataPerSubj_std(:,SUBJ) =  std(respBlocks(:,:,SUBJ),0,2);
    dataPerSubj_se(:,SUBJ) =  std(respBlocks(:,:,SUBJ),0,2) / sqrt(size(respBlocks,2) -  1);
    
    hold all
    stem(wind_in_sec,-300 , 'k')
    stem(wind_in_sec,300 , 'k')
    
    plot(respBlocks(:,:,SUBJ),'color' , [0 0 0 0.5] , 'linewidth' , 1)
    plot(trigBlocks(:,:,SUBJ).*100,'b'  ,  'linewidth' , 1)
    
    ttl = title(DATA(SUBJ).name);
    set(ttl, 'interpreter' , 'none');
    
    plot(mean(respBlocks(:,:,SUBJ),2) +  dataPerSubj_se(:,SUBJ),'color' , [0.9 0.2 0 0.5] , 'linewidth' , 1)
    plot(mean(respBlocks(:,:,SUBJ),2) -  dataPerSubj_se(:,SUBJ),'color' , [0.9 0.2 0 0.5] , 'linewidth' , 1)
    plot(mean(respBlocks(:,:,SUBJ),2), 'r', 'linewidth' , 2)
    
    surr_resp_bad_zone = 0;
    
    %get sniff volume at trial onset
    for j = 1:num_trials
        AUC_trialstart(SUBJ,j) = (sum(sign(resp(SUBJ).trace_z(trials_requested(SUBJ).idx(j)+500:trials_requested(SUBJ).idx(j)+AUC_window+500))));
    end
    
    %
    p = [];
    for boot_iter=  1:boot_iter_num_withinSubj;
        boot_iter;
        AUC_SURR_trialstart = [] ;
        
        for surrtrial = 1:num_trials
            Surr =  randi(length(resp(SUBJ).trace_z) - AUC_window*2);
            
            resp(SUBJ).trace_z_circshifted  = circshift(resp(SUBJ).trace_z, Surr);
            aux1 = resp(SUBJ).trace_z_circshifted(trials_requested(SUBJ).idx(surrtrial):trials_requested(SUBJ).idx(surrtrial)+AUC_window);
            
            AUC_SURR_trialstart(surrtrial) = (sum(sign(aux1)));
        end
        
        [h p(boot_iter) ci stat ]  = ttest2( AUC_trialstart(SUBJ,:), AUC_SURR_trialstart);
    end
    
end

%%
% This section applies statistical tests
% Statistical analysis of respiratory signal. The obtained distribution of real
% events was compared with surrogate data obtained from random windows of the same
% size along the respiratory trace

close all
f44 =figure(44)

sp = subplot(121)
hold all

f44.Color = [1 1 1]
set(gca,'fontsize', 18)
set(gca,'FontName', 'Calibri')

xlabel('Time (s)')
ylabel('Norm. airflow')
set(gca,'Xtick',0:1000:wind_in_sec*2,'XTickLabel',{ '-5', '-4' '-3', '-2' '-1', '0' '1', '2', '3', '4', '5' })
hold all

for iter_factor = PARAM_ITER_FACTOR
    h = [];
    p = [];
    ci = [];
    
    wind_in_sec_including_before_trig = 5000;
    
    stem(wind_in_sec,-3 , 'k')
    stem(wind_in_sec,3 , 'k')
    
    boot_iter_num_acrossSubj = iter_factor;
    
    storage = [];
    
    for SUBJ = 1:size(resp,2)
        storage=  [storage mean(respBlocks_z(:,:,SUBJ),2)] ;
    end
    
    %plot individual mean event-related respiratory responses locked around the moment of
    %trial initiation by button press
    for SUBJ = 1:size(resp,2)
        plot(mean(respBlocks_z(:,:,SUBJ),2), 'color'  , [ 0 0 0  0.5 ] , 'linewidth' , 0.5)
    end
    
    %plot grandmean event-related respiratory response locked around the moment of
    %trial initiation by button press
    plot(mean(storage,2), 'color', [ 0.4  0.6 1 0.8] ,  'linewidth' , 3)
    plot(mean(storage,2)+std(storage,0,2)/(size(storage,2)-1)^0.5, 'color', [ 0  0.4 1 0.7 ] ,  'linewidth' , 1.5)
    plot(mean(storage,2)-std(storage,0,2)/(size(storage,2)-1)^0.5, 'color', [ 0  0.4 1  0.7] ,  'linewidth' , 1.5)
    
    hold all
    ylim([-1 2 ]);
    xlabel('Time (sec)');
    ylabel('Norm. Airflow');
    
    for TIMEWINDOW = 1:length(TIMEWINDOW_POOL) %go over incrementally increrasing time window
        TIMEWINDOW
        sumsign_meanOfSubj = [];
        tic
        
        %ACTUAL
        for SUBJ = 1:size(resp,2) % go over subjects' real data
            aux_sign_propo   = (sign(storage(wind_in_sec_including_before_trig:wind_in_sec_including_before_trig+TIMEWINDOW_POOL(TIMEWINDOW)-1,SUBJ))) ;
            
            aux_sign_propo(aux_sign_propo == -1 ) = NaN; %how many points were positive out of the trace in the window extracted?
            sumsign_meanOfSubj(SUBJ) = nansum(aux_sign_propo)./ length(aux_sign_propo);
        end
        
        %VS.
        %SURROGATE
        for SUBJ = 1:size(resp,2)
            SUBJ;
            %   tic;
            Surr_overallRespRatioOfvector = nan(boot_iter_num_acrossSubj,1); %preallocate
            
            for ITR_SURR = 1:boot_iter_num_acrossSubj %number of iterations for permutation
                Surr =  randi(length(resp(SUBJ).trace)); %draw a random index
                resp(SUBJ).trace_circshifted  = circshift(resp(SUBJ).trace, Surr); %circshift resp. data but retain places of triggers
                
                for j = 1:num_trials % generate a vector the length of trial number in the actual data (25)
                    aux_propo_surr =[];
                    aux_propo_surr = sign(resp(SUBJ).trace_circshifted(trials_requested(SUBJ).idx(j):trials_requested(SUBJ).idx(j)+TIMEWINDOW_POOL(TIMEWINDOW)-1));
                    
                    aux_propo_surr(aux_propo_surr == -1 ) = NaN; ; %how many points were positive out of the trace in the window extracted?
                    AUC_SURR_trialstart(j) = nansum(aux_propo_surr)./ length(aux_propo_surr) ;
                end
                
                aux_Surr_AUC_SURR_trialstart = mean(AUC_SURR_trialstart); %collapse over trials
                Surr_overallRespRatioOfvector(ITR_SURR) = aux_Surr_AUC_SURR_trialstart; %hold the collapsed result of this iteration
            end
            overallRespRatioOfvector_mean(SUBJ) = nanmean(Surr_overallRespRatioOfvector);
        end
        
        [h p(TIMEWINDOW)  ci stat]  =  ttest(sumsign_meanOfSubj, overallRespRatioOfvector_mean); %
        all_ci(TIMEWINDOW).vals = ci;
        all_stat(TIMEWINDOW).vals = stat;
             
        sp121= subplot(121)
        xlim([1000 9000])
        ylim([-1 1])
        hold all
        sc7 =  scatter(TIMEWINDOW_POOL(TIMEWINDOW)+wind_in_sec_including_before_trig,p(TIMEWINDOW) , 10 , [ 1 0.4 0  ], 'filled');
        
        toc
        drawnow
    end
    
    hold all
    plot(TIMEWINDOW_POOL(1:length(p))+wind_in_sec_including_before_trig,p, 'color' , [ 1 0.4  0 ],  'linewidth' , 2)
    
    clearvars y filteredSignal respFFT freq myWindow resp_unfiltered
end
