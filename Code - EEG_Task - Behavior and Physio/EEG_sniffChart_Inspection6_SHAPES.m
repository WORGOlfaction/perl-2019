%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Supplementary Code for Perl et al. 2019
%%%
%%% This script loads a database containing all behavioral and
%%% physiological (respiratory) data collected during the EEG sessions.
%%% It goes over the subjects and plots trial onset relative to respiratory
%%% phase in order to remove mis-fired trials. Next it computes accuracy
%%% and RT per subject and for the group
%%%
%%% This script works on two levels: 
%%% 1.Visualization of per-trial data to insepct trigger lock with respiration
%%%  2. Once these were inspected and a trial-exclusion dataset was formed, it can 
%%%  Now be loaded and  this trials will be rejected automatically 
%%% The toggle is 'PreloadedMisfiresFromXLSX'
%%% These results correspond to Figure 3 in the manuscript
%%%
%%% Dependecies: 'sortcell'
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


clear
whitebg('w')

%This is the key for shape answers
% 1 is a possible shape
% 0 is an impossible shape
shapes_key =     [0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,0,0,0,0,1,1,1,1,1,1,0,0,1,1,0,0,1,1,0,0,0,0,1,1,1,1,0,0,1,1,0,0,1,1,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,1,1,1,1,0,0,0,0]

RootDirPath = ('SHAPES')

[PreloadedMisfires1 PreloadedMisfires2 PreloadedMisfires3]= xlsread('shapes_removed_misfires.xlsx');

close all
%RootDirPath = 'F:\Dropbox\EEG\imp_EEG 2\RealSubj\WORDS\'
%RootDir = dir(RootDirPath); RootDir = RootDir(3:end)
cd(RootDirPath)
listxlsx = dir('*.xlsx');
listmat = dir('*.mat');

toSaveImages = 0 %toggle
PreloadedMisfiresFromXLSX = 1 %toggle. This toggles between first-time inspection of trials
%for the referees for visual removal of trials that were not presented
%locked with inhalation or exhalation.

removeFirstTrialAnyway = 1 %toggle

%%
for SUBJ =  1:size(listxlsx,1) %go over all xlx files in folder 
    
    tic    
    %verify each subjects has both types of files
    if  strcmp(listxlsx(SUBJ).name(1:5), listmat(SUBJ).name(1:5))
        disp('Match OK')
    else
        disp('Match PROBLEM:')
        disp(strcat(listxlsx(SUBJ).name, '////', listmat(SUBJ).name, '////', listmarkers(SUBJ).name))
    end
    
    close all
    %cleaning 
    clearvars -except SUBJ A testtype listmat listxlsx  listmarkers RootDir RootDirPath shapes_key toSaveImages PreloadedMisfiresFromXLSX removeFirstTrialAnyway PreloadedMisfires1 PreloadedMisfires2 PreloadedMisfires3
    
    subjfilename = listxlsx(SUBJ).name


    %paramm. init. 
    pathName = pwd;
    fs = 1000; %sampling rate
    allocation =2500 * (fs ./ 1000); %size of window to extract and save 
    middle = 2500 %middle of window (half of 'allocation' size
    num_trials = 160; 
    
    %read Psyscope results
    [xls1 xls2 xls3] = xlsread(strcat(subjfilename)); %load XLSX psyscope
    
    %index for columns of xls_log
    column_idx =1;
    column_stimulus =3;
    column_resp_cond =6;
    column_rt =15;
    column_input =16;
    
    % some of the data in the PsyscopeX logs is not needed. We create a
    % smaller log according to this order of columns:
    XLS_log = xls3(:,[column_idx  column_stimulus column_resp_cond column_rt column_input]);
    
    %change 'response' or 'input' column to 'in' or 'ex'
    %%%% NOTE THAT THE SCRIPT CHANGES THE TRIAL TYPE SET BY PSYSCOPE
    %%% BECAUSE IT IS FOR SOME REASON THE OPPOSITE OF WHAT SHOULD BE
    for i = 1:length(XLS_log)
        if strcmp(XLS_log{i,3}, 'response_i')
            XLS_log{i,3} = 'ex';  %<----------
        elseif strcmp(XLS_log{i,3}, 'response_e')
            XLS_log{i,3} = 'in';    %<---------- 
        end
    end
    
    %shift trial idx by 1
    aux=([XLS_log{:,column_idx}] - 1)';
    for trial = 1:length(XLS_log)
        XLS_log{trial,column_idx}  =aux(trial);
    end
    
    %trials without response have no entry in log. Therefore we go over it
    %and generate a row per such
    %find missing trials
    missing_trials = find(~ismember(1:num_trials,aux ))
    if size(missing_trials,2) >0
        %generate "NaN" data for these trials
        for trial = 1:length(missing_trials)
            missing_trial_line(trial,:) = [{missing_trials(trial)} {NaN} {'unknown'} {NaN} {'no_ans'}];
        end
        % add missing values (subject did not supply input)
        XLS_log = [XLS_log ; missing_trial_line];
        %sort again with NaN values
        XLS_log = sortcell(XLS_log, 1);
    end
    
    %
    %parameters:
    %preallocation
    block_trials = nan(allocation*2, num_trials);
    resp_blocks = nan(allocation*2, num_trials);
    
    from = nan(num_trials, 1);
    to = nan(num_trials, 1);
    
    %load MAT file of LabChart physiological recording
    disp('loading:')
    disp(listmat(SUBJ).name)
    load(listmat(SUBJ).name)
    
    
    resp = C3B1; resp = zscore(resp) ; %respiration data 
    trig1 = C9B1; 
    trig2 = C10B1;
    
    clearvars C2B1 C1B1 C4B1 C5B1 C6B1 C3B1 C7B1 C8B1 C9B1 C10B1 %cleanup
    
    disp('importing data from Chart ---> OK')
    
    %
    %digitize response user input
    digitize_thresh = mean(trig1)./2;
    for trial = 1:length(trig1)
        if trig1(trial) < digitize_thresh    %flatten jagged voltage increase
            trig1(trial) = 1;
        else
            trig1(trial) = 0 ;
        end
    end
    for trial = 1:length(trig2)
        if trig2(trial) < digitize_thresh    %flatten jagged voltage increase
            trig2(trial) = 1;
        else
            trig2(trial) = 0 ;
        end
    end
    
    % find Trials
    [triggers_y1 triggers_x1] = findpeaks...
        (trig1, 'minpeakdistance',100, 'minpeakheight' , 0.9);
    [triggers_y2 triggers_x2] = findpeaks...
        (trig2, 'minpeakdistance',100, 'minpeakheight' , 0.9);
    
    triggers_x = sort([triggers_x1; triggers_x2]);
    trialStart = triggers_x;
    
    sessionTime = (trialStart(end) - trialStart(1) ) ./ (60 * fs); %calculate session time (in minutes)
    
    %checkpoint1
    if numel(triggers_x) == num_trials...
        disp 'detection of trials ---- > OK  '
    else
        disp 'detection of trials or answers ---- > ERROR?!  '
    end
    
    %%
    %division into blocks of trials and extraction of all physio channels
    %around trial onset window
    t = [];
    for trial = 1:num_trials
        
        if triggers_x(trial) < allocation+1;
            
            triggers_x(trial) = allocation+1;
            
        end
        temp_from = triggers_x(trial)-allocation ; %idx of trial start % displays 1 sec before trial onset
        temp_to = triggers_x(trial) + allocation-1;
        
        temp_trig1_block = trig1(temp_from:temp_to,1);
        temp_trig2_block = trig2(temp_from:temp_to,1);
        
        temp_resp_block = resp(temp_from:temp_to,1);
        
        block_resp(1:length(temp_resp_block),trial) = temp_resp_block;
        trig_blocks1(1:length(temp_trig1_block),trial) = temp_trig1_block;
        trig_blocks2(1:length(temp_trig2_block),trial) = temp_trig2_block;
        
        from(trial) = temp_from; %store all start times
        to(trial) = temp_to; %store all end times
        
        %extract behavioral param and phase per trial
        t(trial).resp = temp_resp_block;
        t(trial).respphase = angle(hilbert(temp_resp_block));
        t(trial).respphaseAttrig =     t(trial).respphase(middle);
        t(trial).trig1 = temp_trig1_block;
        t(trial).trig2 = temp_trig2_block;
        t(trial).cond = XLS_log{trial,3};
        t(trial).rt = XLS_log{trial,4};
        
        % catch subject's responses (keyboard keys)
        if strcmp(XLS_log{trial,5}, '[o]')
            t(trial).userInput = 1;
        elseif  strcmp(XLS_log{trial,5}, '[p]')
            t(trial).userInput = 0;
        end
        
        if length(t(trial).cond) >= 2
            
        else
            t(trial).cond = NaN;
        end
        clearvars temp_trial_block  temp_resp_block1 temp_resp_block2  temp_trig_block2
    end
    
    middle = size(block_trials,1 )./ 2;
    
    for l = 1:size(t,2) %extract sniff volume following trial onset
        t(l).auc01sec= trapz(t(l).resp(middle:middle+fs/10)); %area of sniff within 1/10 second - CHECKPOINT FOR INHALE/EXHALE EXCLUSION
        t(l).auc05sec= trapz(t(l).resp(middle:middle+fs/2)); %area of sniff within 1/2 second
        t(l).auc1sec= trapz(t(l).resp(middle:middle+fs)); %area of sniff within 1/2 second
        t(l).max2sec= max(t(l).resp(middle:middle+2*fs)); %area of sniff within 1/2 second
        
        % if no reply was provided by subject, decide what kind of trial it
        % was (inhale- or exhale- triggered) 
        if strcmp(XLS_log{l,3}, 'unknown');
            if  t(l).auc05sec > 0
                XLS_log{l,3} = 'in EST.';
                t(l).cond = {'in EST.'};
            else
                XLS_log{l,3} = 'ex EST.';
                t(l).cond = {'ex EST.'};
            end
        end
    end
    
    %checkpoint2
    if size(block_trials,2) == num_trials
        disp 'division into blocks ---- > OK  '
    else
        disp 'division into blocks ---- > ERROR?!  '
    end
    
    %%
    for i = 1:160 %get phase and display
        ph_all(i) = [t(i).respphase(middle)];
    end
    
    %
    COUNT = 0;
    figure(100);
    subplot(221)
    [ph_less1_idx] = find(ph_all<0);
    ph_less1_vals = ph_all(ph_less1_idx);
    ph_less1_vals_z = zscore(ph_less1_vals);
    hist(ph_less1_vals,50)
    
    xlim([-pi pi])
    [hist1 hist2] = hist(ph_less1_vals,20);
    hold all
    for k = 1:length(hist1)
        if hist1(k) < 5 &&  hist1(k) > 0
            COUNT = COUNT + 1;
        end
    end
    subplot(223)
    hist(ph_less1_vals_z,50);
    title('z')
       
    subplot(222)
    [ph_more1_idx] = find(ph_all>0);
    ph_more1_vals = ph_all(ph_more1_idx);
    ph_more1_vals_z = zscore(ph_more1_vals);
    hist((ph_more1_vals),50);
    xlim([ -pi pi]);
    [hist1 hist2] = hist(ph_more1_vals,20);
    hold all
    for k = 1:length(hist1)
        if hist1(k) < 5 &&  hist1(k) > 0
            COUNT = COUNT + 1;
        end
    end
    subplot(224)
    hist(ph_more1_vals_z,50);
    title('z')
    close
    %
    ph_all_z = [[ ph_more1_idx' ph_more1_vals_z' ph_more1_vals' ]; [ ph_less1_idx' ph_less1_vals_z' ph_less1_vals']];
    
    ph_all_z_table = sortrows(ph_all_z);  %2nd column is Z values, 3rd col. is phase
    
    for l = 1:size(t,2)
        t(l).ph_val_z= ph_all_z_table(l,2);
        t(l).ph_val= ph_all_z_table(l,3);
    end
    
    %%  Visualization - ALL IN ONE
    removeMisfires = [];
    h6 = figure(6)
    set(h6, 'Position', [0.1 0.1 1920 1024])
    lineWidthParam = 1;
    ylimParam =4;
    removemisfires = []
    tempColorVeca = 0.5;
    tempColorVecb = 0.9;
    tempColorVec = (tempColorVecb-tempColorVeca).*rand(size(t,2),1) + tempColorVeca;
    
    for l = 1:size(t,2)
        subplot(131)
        hold all
        plot(t(l).resp, 'color', [ tempColorVec(l) tempColorVec(l) tempColorVec(l)])
        plot(t(l).trig1, 'r')
        plot(t(l).trig2, 'g')
        xlim([0 5000])
        
        ylim([-ylimParam ylimParam])
        %
        if strcmp(t(l).cond, 'in')
            subplot(132)
            hold all
            plot(t(l).resp, 'color', [0.7 rand*0.5 rand*0.5])
            plot(t(l).trig1, 'b')
            plot(t(l).trig2, 'b')
            ylim([-ylimParam ylimParam])
            xlim([0 5000])
            
            if t(l).auc1sec < 0
                [mn mn2] =  min(t(l).resp(2500:4000));
                text(mn2+2500, mn , num2str(l));
            end
        elseif strcmp(t(l).cond, 'ex')
            subplot(133)
            hold all
            plot(t(l).resp, 'color', [rand*0.5 0.7  rand*0.5]);
            plot(t(l).trig1, 'b')
            plot(t(l).trig2, 'b')
            
            if t(l).auc1sec > 0
                [mx mx2] =  max(t(l).resp(2500:4000));
                text(mx2+2500, mx , num2str(l));
            end
            
            ylim([-4 4])
            xlim([0 5000])
            
        end
        %drawnow
    end
    
    anno= annotation('textbox',...
        [0.03 0.03 0.1 0.05],...
        'String',subjfilename(1:6),...
        'FontSize',10)
    set(anno, 'Interpreter', 'none')
    
    if toSaveImages == 1
        tempFigureSaveName = strcat(subjfilename(1:6), '_SUMM_SHAPES_1.png')
        saveas(gcf,tempFigureSaveName)
    end
    
    %%
    if PreloadedMisfiresFromXLSX  == 0
          
        %  Visualization I (trials 1 - 80)
        ManualTaggingOfBadTrials = 1;
        trialToRemove = [];
        lineWidthParam = 1;
        ylimParam =3;
        gridx = 9;  gridy = 9;
        removemisfires = [];
        
        h1 = figure
        set(h1, 'Position', [0.1 0.1 1920 1024])
        
        
        for l = 1:80
            subplot(gridx,gridy,l)
            hold all
            
            if abs(ph_all_z_table(l,2)) > 3
                patch([ 5000 0 0 5000 ]  ,[ -5 -5 5 5 ]  ,'r' , 'FaceAlpha',0.2, 'EdgeColor', 'r');
            end
            patch([  middle+1000 middle  middle  middle+1000 ]  ,[ -5 -5 5 5 ]  ,'k' , 'FaceAlpha',0.1, 'EdgeColor', 'w');
            
            set(gca,'tag',num2str(l))
            set(gca,'FontSize',3)
            set(gcf,'color', [0.5 0.5 0.5])
            
            hold all
            plot(t(l).trig1 ,'r', 'linewidth' , 1)
            plot(t(l).trig2 ,'g', 'linewidth' , 1)
            plot(zeros(length(t(l).trig1),1), 'k','linewidth' , 1)
            plot(t(l).resp, 'b', 'linewidth' , 1)
            
            ylim([-ylimParam ylimParam])
            
            if strcmp(t(l).cond, 'in')
                title(strcat(num2str(l), '::' ,'IN'), 'fontsize' ,9, 'color' , 'r' )
            elseif strcmp(t(l).cond, 'ex')
                title(strcat(num2str(l), '::' ,'EX'),'fontsize' ,9,  'color' , 'g' )
            elseif strcmp(t(l).cond, 'ex EST.')
                title(strcat(num2str(l), '::' ,'EX EST.'),'fontsize' ,9,  'color' , 'y' )
            elseif strcmp(t(l).cond, 'in EST.')
                title(strcat(num2str(l), '::' ,'IN EST.'),'fontsize' ,9,  'color' , 'y' )
            end
            
            if mod(l,10) == 0
                drawnow
            end
            %     grid off
            % axis off
        end
        if ManualTaggingOfBadTrials == 1
            while 1 == 1
                w = waitforbuttonpress;
                switch w
                    case 1 % keyboard
                        key = get(gcf,'currentcharacter');
                        if key==27 % (the Esc key)
                            
                            break
                        end
                    case 0 % mouse click
                        mousept = get(gca,'currentPoint');
                        x = mousept(1,1);
                        y = mousept(1,2);
                        
                        h = text(x,y,get(gca,'tag'),'vert','middle','horiz','center', 'color' , 'k', 'fontsize', 30);
                        h2 = text(x,y-1.5,'removed','vert','middle','horiz','center', 'color' , 'k', 'fontsize', 9);
                        trialToRemove = [trialToRemove str2num(h.String)];
                        
                end
            end
        end
        anno= annotation('textbox',...
            [0.03 0.03 0.1 0.05],...
            'String',subjfilename(1:6),...
            'FontSize',10)
        set(anno, 'Interpreter', 'none')
        
        set(gcf, 'PaperUnits', 'inches');
        x_width=16.25 ;y_width=10.125
        set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
        saveas(gcf,tempFigureSaveName)
        close
        
        %%  Visualization II (trials 81 - 160)
        
        h2 = figure;
        set(h2, 'Position', [0.1 0.1 1920 1024]);
        
        for l = 81:size(t,2)
            subplot(gridx,gridy,l-80)
            hold all
            
            if abs(ph_all_z_table(l,2)) > 3
                patch([ 5000 0 0 5000 ]  ,[ -5 -5 5 5 ]  ,'r' , 'FaceAlpha',0.2, 'EdgeColor', 'r');
            end
            patch([  middle+1000 middle  middle  middle+1000 ]  ,[ -5 -5 5 5 ]  ,'k' , 'FaceAlpha',0.1, 'EdgeColor', 'w');
            
            set(gca,'tag',num2str(l))
            set(gca,'FontSize',3)
            set(gcf,'color', [0.5 0.5 0.5])
            hold all
            plot(t(l).trig1 ,'r', 'linewidth' , 1);
            plot(t(l).trig2 ,'g', 'linewidth' , 1);
            plot(zeros(length(t(l).trig1),1), 'k','linewidth' , 1);
            plot(t(l).resp, 'b', 'linewidth' , 1);
            
            ylim([-ylimParam ylimParam])
            
            if strcmp(t(l).cond, 'in')
                title(strcat(num2str(l), '::' ,'IN'), 'fontsize' ,9, 'color' , 'r' )
            elseif strcmp(t(l).cond, 'ex')
                title(strcat(num2str(l), '::' ,'EX'),'fontsize' ,9,  'color' , 'g' )
            elseif strcmp(t(l).cond, 'ex EST.')
                title(strcat(num2str(l), '::' ,'EX EST.'),'fontsize' ,9,  'color' , 'y' )
            elseif strcmp(t(l).cond, 'in EST.')
                title(strcat(num2str(l), '::' ,'IN EST.'),'fontsize' ,9,  'color' , 'y' )
            end
            
            if mod(l,10) == 0
                drawnow
            end
            %     grid off
            % axis off
        end
        if ManualTaggingOfBadTrials == 1
            while 1 == 1
                w = waitforbuttonpress;
                switch w
                    case 1 % keyboard
                        key = get(gcf,'currentcharacter');
                        if key==27 % (the Esc key)
                            
                            break
                        end
                    case 0 % mouse click
                        mousept = get(gca,'currentPoint');
                        x = mousept(1,1);
                        y = mousept(1,2);
                        
                        h = text(x,y,get(gca,'tag'),'vert','middle','horiz','center', 'color' , 'k', 'fontsize', 30);
                        h2 = text(x,y-1.5,'removed','vert','middle','horiz','center', 'color' , 'k', 'fontsize', 9);
                        trialToRemove = [trialToRemove str2num(h.String)];
                        
                end
            end
        end
        anno= annotation('textbox',...
            [0.03 0.03 0.1 0.05],...
            'String',subjfilename(1:6),...
            'FontSize',10)
        set(anno, 'Interpreter', 'none')
        
        if toSaveImages == 1
            
            tempFigureSaveName = strcat(subjfilename(1:6), 'SUMM_SHAPES_3.png')
            set(gcf, 'PaperUnits', 'inches');
            x_width=16.25 ;y_width=10.125
            set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
            saveas(gcf,tempFigureSaveName)
        end
        close
        
        
        if removeFirstTrialAnyway ==1
            trialToRemove = [1 trialToRemove];
            disp('PLEASE NOTE! 1st trial removed anyway')
            pause(2)
        end
        
        trialToRemove = sort(unique(trialToRemove))
        pause(2)
        
        
        %
        for i = 1:length(trialToRemove)
            XLS_log(trialToRemove(i),:) = [{trialToRemove(i)} {NaN} {NaN} {NaN} {'removed'}];
        end
        %
        
    else % suppose you want to load misfires from xls
        
        % compare subject name to names in the misfires database
        for i = 1:size(PreloadedMisfires1,1)
            if(strcmp(PreloadedMisfires3{i,1}, subjfilename(1:4))) == 1 ;
                tempSubjRow = i
            end
        end
        PreloadedMisfires1_perSubj = PreloadedMisfires1(tempSubjRow,2:end);
        PreloadedMisfires1_perSubj = PreloadedMisfires1_perSubj(~isnan(PreloadedMisfires1_perSubj))
        trialToRemove = PreloadedMisfires1_perSubj;
        
        % according to toggle, removes first trial of the session
        % regardless of outcome or respiratory phase
        if removeFirstTrialAnyway ==1
            trialToRemove = [1 trialToRemove];
            disp('PLEASE NOTE! 1st trial removed anyway')
            pause(2)
        end
        

        for i = 1:length(trialToRemove)
            XLS_log(trialToRemove(i),:) = [{trialToRemove(i)} {NaN} {NaN} {NaN} {'removed'}];
        end
       
        
    end
    %% ANALYZER - SHAPES check subject's answers
    
    counter_noans = 0;
    num_trials = length(XLS_log);
    for i =  1:length(XLS_log)
        flagNonShape = []
        flagShape = []
        if ~ismember(i , trialToRemove) %if this trial is legit == was not included in those that should be removed
            
            tempWordString = cell2mat(XLS_log(i,2));
            if ~isnan(tempWordString) %if it is filled with text == we have a response from subject
                %crop word stimuli from string
                
                %extract shape number form the stimuli label in the XLS_log
                tempWordString(end-3:end) = [];
                tempWordString(1:5) = [];
                tempWordNumber = tempWordString;
                tempWordNumber = str2num(tempWordString);
                t(i).stim = tempWordNumber;
                
                if shapes_key(tempWordNumber) == 0
                    flagNonShape = 1; flagShape = 0;
                    t(i).meaning = 'impossible';
                end
                
                if shapes_key(tempWordNumber) == 1
                    flagNonShape = 0; flagShape = 1;
                    t(i).meaning = 'possible';
                end
                
                if strcmp(XLS_log(i,5),{'[o]'}) == flagShape;... %== 1 %if pressed "correct" and answer is indeed correct
                        XLS_log(i,7) = {1}; % col6 - correct / incorrect
                    t(i).accuracy = 1;
                else
                    XLS_log(i,7) = {0};
                    t(i).accuracy = 0;
                end
                
                if strcmp(XLS_log(i,5),{'[p]'}) == flagNonShape; %or incorrect and incorrect...
                    XLS_log(i,7) = {1}; % col6 - correct / incorrect
                    t(i).accuracy = 1;
                else
                    XLS_log(i,7) = {0};
                    t(i).accuracy = 0;
                end
                clear flagNonShape;
                clear flagShape;
                
            else %no answer from subject
                
                counter_noans = counter_noans + 1;
                XLS_log(i,7) = {0}; % col7 - correct / incorrect
                t(i).accuracy = 0;
                if strcmp(XLS_log(i,3),{'ex EST.'})
                    XLS_log(i,3) = {'ex'};
                elseif  strcmp(XLS_log(i,3),{'in EST.'})
                    XLS_log(i,3) = {'in'};
                end
            end
            
        else  %was removed because of misfire
            t(i).accuracy = NaN;
            t(i).rt = NaN;
        end
    end
    
    %%
    for ii = 1:length(t)
        if strcmp(t(ii).cond, 'in')
            temp_inex_trials(ii) = 1
        elseif strcmp(t(ii).cond, 'ex')
            temp_inex_trials(ii) = 0
        else
            temp_inex_trials(ii) =  NaN
        end
    end

    %% trials that are removed are being scrubbed
    for i = 1:length(trialToRemove)
        t(trialToRemove(i)).resp = NaN;
        t(trialToRemove(i)).trig1 = NaN;
        t(trialToRemove(i)).trig2 = NaN;
        t(trialToRemove(i)).cond = NaN;
        t(trialToRemove(i)).userInput = NaN;
        t(trialToRemove(i)).rt = NaN;
    end
    
    %%
    % In this final step we look at group level. Groups are defined
    % according to resp. condition or according to Shape type 
    
    % GROUPING BY RESP COND
    ctgGrouped =[];
    categoryTypes = [{'in'}, {'ex'}];
    tempWhere = []
    %average across parameters
    for k = 1:length(categoryTypes)
        for kk = 1:size(t,2)
            tempWhere1(kk) = strcmp([t(kk).cond],categoryTypes(k));
        end
        
        for kk = 1:size(t,2)
            tempWhere2(kk) = strcmp([t(kk).cond],strcat(categoryTypes(k),' EST.')); %trials assumed to be in or ex but
            %unanswered so no log. Still, no answer means an error in a
            %legit trial
        end
        
        tempWhere = tempWhere1+tempWhere2;
        
        tempWhere = logical(tempWhere)
        
        ctgGrouped(k).resp.vals = ([t(tempWhere).resp]);
        ctgGrouped(k).resp.mean = nanmean([t(tempWhere).resp],2);
        ctgGrouped(k).resp.std = std([t(tempWhere).resp],0,2);
        ctgGrouped(k).resp.se = (std([t(tempWhere).resp],0,2))./(size(ctgGrouped(k).resp.vals,2)-1)^0.5;
        ctgGrouped(k).categoryName = categoryTypes{k};
        
        ctgGrouped(k).rt.table = [(1:length(tempWhere))' tempWhere' ([t.rt])']
        ctgGrouped(k).rt.vals = ([t(tempWhere).rt])
        ctgGrouped(k).rt.mean = nanmean([t(tempWhere).rt]);
        ctgGrouped(k).rt.std = nanstd([t(tempWhere).rt],0,2);
        ctgGrouped(k).rt.se =  ctgGrouped(k).rt.std./(size(ctgGrouped(k).rt.vals,2)-1)^0.5;
        
        ctgGrouped(k).accu.table = [(1:length(tempWhere))' tempWhere' ([t.accuracy])']
        ctgGrouped(k).accu.vals = ([t(tempWhere).accuracy]);
        ctgGrouped(k).accu.mean = nansum([t(tempWhere).accuracy]) / sum(tempWhere) ;
        
    end
    
    clearvars tempWhere tempWhere1 tempWhere2
    
    % GROUPING BY meaning
    ctgGroupedShapeType =[];
    categoryTypes = [{'possible'}, {'impossible'}];
    
    %average across parameters
    for k = 1:length(categoryTypes)
        for kk = 1:size(t,2)
            tempWhere1(kk) = strcmp([t(kk).meaning],categoryTypes(k));
        end
        
        tempWhere = tempWhere1;
        
        tempWhere = logical(tempWhere)
        
        ctgGroupedShapeType(k).resp.vals = ([t(tempWhere).resp]);
        ctgGroupedShapeType(k).resp.mean = nanmean([t(tempWhere).resp],2);
        ctgGroupedShapeType(k).resp.std = nanstd([t(tempWhere).resp],0,2);
        
        ctgGroupedShapeType(k).rt.table = [(1:length(tempWhere))' tempWhere' ([t.rt])']
        ctgGroupedShapeType(k).rt.vals = ([t(tempWhere).rt])
        ctgGroupedShapeType(k).rt.mean = nanmean([t(tempWhere).rt]);
        ctgGroupedShapeType(k).rt.std = nanstd([t(tempWhere).rt],0,2);
        ctgGroupedShapeType(k).rt.se =  ctgGroupedShapeType(k).rt.std./(size(ctgGroupedShapeType(k).rt.vals,2)-1)^0.5;
        
        ctgGroupedShapeType(k).accu.table = [(1:length(tempWhere))' tempWhere' ([t.accuracy])']
        ctgGroupedShapeType(k).accu.vals = ([t(tempWhere).accuracy]);
        ctgGroupedShapeType(k).accu.mean =   nansum([t(tempWhere).accuracy]) / (sum(tempWhere) + + numel(missing_trials)) ;
        
    end
    
    %%
    
    LEGEND =  [{'in'}, {'ex'}];
    close
    h9 =  figure(9);
    
    set(h9, 'Position', [0.1 0.1 1920 1024]);
    auxBarRTMean = [];
    auxBarRTSE = [];
    auxBarAccuMean = [];
    auxBarAccuMeanShapeType = [];
    auxxShapeType = []
    auxx = []
    auxBarRTMeanShapeType= [];
    auxBarRTSEShapeType = []
    CONTRAST = [ 1:2  ]; % contrasting two experimental conditions 
    %that are stored in the same struct
    
    colors = [1 0.4 0 ; 0 0.4 1 ]
    for k = 1:length(CONTRAST) %1:length(categoryTypes)
        subplot(1,3,1:2)
        disperse=[];
        hold all
        auxColor = colors(k,:);
        h = plot(ctgGrouped((CONTRAST(k))).resp.mean, 'color' , auxColor , 'linewidth' , 1.5);
        
        plot(ctgGrouped(CONTRAST(k)).resp.vals, ':', 'color',auxColor);
        plot(ctgGrouped(CONTRAST(k)).resp.mean+ctgGrouped(CONTRAST(k)).resp.se, ':', 'color',auxColor);
        plot(ctgGrouped(CONTRAST(k)).resp.mean-ctgGrouped(CONTRAST(k)).resp.se, ':', 'color',auxColor);
        plot(trig_blocks1,'k');
        plot(trig_blocks2,'k');
        
        ylabel('resp z')
     
        auxBarRTMean(end+1) = ctgGrouped(CONTRAST(k)).rt.mean;
        auxBarRTSE(end+1) = ctgGrouped(CONTRAST(k)).rt.se;
        auxx = ctgGrouped(CONTRAST(k)).accu;
        auxBarAccuMean(end+1) = nanmean(auxx.vals)
        
        auxBarRTMeanShapeType(end+1) = ctgGroupedShapeType(CONTRAST(k)).rt.mean;
        auxBarRTSEShapeType(end+1) = ctgGroupedShapeType(CONTRAST(k)).rt.se;
    
        
        str = LEGEND(CONTRAST(k));
        disperse(k) = 1-1/numel(CONTRAST)*k*0.7;
        
        dim=([0.01   disperse(k) 0.09 0.05]);
        a = annotation('textbox',dim,'String',str );
        a.FontSize = 10;
        a.Color = auxColor;
    end
    
    %auxBarRTMean
    subplot(344);
    hold all
    bar(auxBarRTMean);
    errorbar(auxBarRTMean, auxBarRTSE);
    title('RT - in vs ex')
    ylabel('ms')
    ylim([500 1200])
    
    %auxBarRTMeanShapeType
    subplot(348);
    hold all
    bar(auxBarRTMeanShapeType);
    errorbar(auxBarRTMeanShapeType, auxBarRTSEShapeType);
    title('RT - posssible vs impossible')
    ylabel('ms')
    
    ylim([500 1200])
    
    %auxBarAccuMean
    subplot(3,4,12)
    hold all
    hh = bar(auxBarAccuMean);
    hh.FaceColor = 'r';
    hh.EdgeColor = 'b';
    
    title('ACCU. in vs ex.');
    ylabel('a.u.');
    ylim([0.3 1])
    
    anno= annotation('textbox',...
        [0.03 0.03 0.1 0.05],...
        'String',subjfilename(1:6),...
        'FontSize',10);
    set(anno, 'Interpreter', 'none');
    
    textSummary = {strcat('#trials no answer:', num2str(numel(missing_trials))  ,char(10)) , ...
        strcat('#trials manually removed:', num2str(numel(trialToRemove))  ,char(10)) , ...
        strcat('#highest score possible:~', num2str(...
        (160    -numel(trialToRemove)      -numel(missing_trials))...
        /...
        (160-numel(trialToRemove)))  ,char(10),  ...
        ' ', char(10),...
        strcat('   ACCURACY IN    :', num2str(auxBarAccuMean(1))  ,char(10)) , ...
        char(10),...
        strcat('  ACCURACY EX   :', num2str(auxBarAccuMean(2))  ,char(10)) ...
        )}
    
    annoTop= annotation('textbox',...
        [0.01 0.75 0.1 0.2],...
        'String',textSummary,...
        'FontSize',10);
    set(anno, 'Interpreter', 'none');
    
    if toSaveImages == 1
        tempFigureSaveName = strcat(subjfilename(1:6), 'SUMM_SHAPES_4.png')
        set(gcf, 'PaperUnits', 'inches');
        x_width=16.25 ;y_width=10.125
        set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
        saveas(gcf,tempFigureSaveName)
    end
    %%
    
    %store:
    A(SUBJ).t = t;
    A(SUBJ).ctg = ctgGrouped;
    A(SUBJ).ctgShapeType = ctgGroupedShapeType	;
    A(SUBJ).subjName = subjfilename;
    A(SUBJ).subjNumber = SUBJ;
    A(SUBJ).log = XLS_log;
    close
    
    toc
    
end
% CLOSE SUBJ LOOP


%%
EXCLUDE = 0 
%%%%%%%%%%%%%%%%%%%%%%
%load the parameter "A" from the .MAT file. Usually named "WORKSPACE"
for i = 1:size(A,2)
    disp(strcat(num2str(i),':::',A(i).subjName))
end
%
figure(1)

% IN VS EX
AC_IN_EX = []
RT_IN_EX = []
for SUBJ =  1:size(A,2)  %remove subjects we do
    
        AC_IN_EX(SUBJ,1:2) = [ A(SUBJ).ctg(1).accu.mean  A(SUBJ).ctg(2).accu.mean ]
        RT_IN_EX(SUBJ,1:2) = [ A(SUBJ).ctg(1).rt.mean  A(SUBJ).ctg(2).rt.mean ]
    
end
% add subj numbers
AC_IN_EX  = [(1:size(A,2))' AC_IN_EX]
RT_IN_EX  = [(1:size(A,2))' RT_IN_EX]

% remove excluded subjs
AC_IN_EX((AC_IN_EX(:,2) == 0 ),:) = []
RT_IN_EX((RT_IN_EX(:,2) == 0 ),:) = []

%  IN VS EX
figure
subplot(141)
hold all
title('ACC. IN vs EX')
bar([mean(AC_IN_EX(:,2)) mean(AC_IN_EX(:,3))])
errorbar([mean(AC_IN_EX(:,2)) mean(AC_IN_EX(:,3))], [std(AC_IN_EX(:,2))/sqrt(size(A,2)-numel(EXCLUDE)-1) std(AC_IN_EX(:,3))/sqrt(size(A,2)-numel(EXCLUDE)-1)])
ylim([0.5 1])
[h1 p1 ci1 stat1] = ttest(AC_IN_EX(:,2),AC_IN_EX(:,3))
%title(num2str(p1))
ax = gca
ax.XTick = [1 2 ] 
ax.XTickLabel = ({  'IN' , 'EX' })

subplot(142)
hold all
title('RT. IN vs EX')

bar([mean(RT_IN_EX(:,2)) mean(RT_IN_EX(:,3))])
errorbar([mean(RT_IN_EX(:,2)) mean(RT_IN_EX(:,3))], [std(RT_IN_EX(:,2))/sqrt(size(A,2)-numel(EXCLUDE)-1) std(RT_IN_EX(:,3))/sqrt(size(A,2)-numel(EXCLUDE)-1)])
ylim([800 1000])
[h2 p2 ci2 stat2] = ttest(RT_IN_EX(:,2),RT_IN_EX(:,3))
%title(num2str(p2))
ax = gca
ax.XTick = [1 2 ] 
ax.XTickLabel = ({  'IN' , 'EX' })%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%
AC__SHAPE_POS_IMPO = []
RT__SHAPE_POS_IMPO = []
for SUBJ =  1:size(A,2)  
        AC__SHAPE_POS_IMPO(SUBJ,1:2) = [ A(SUBJ).ctgShapeType(1).accu.mean  A(SUBJ).ctgShapeType(2).accu.mean ]
        RT__SHAPE_POS_IMPO(SUBJ,1:2) = [ A(SUBJ).ctgShapeType(1).rt.mean  A(SUBJ).ctgShapeType(2).rt.mean ]
    
end
% add subj numbers
AC__SHAPE_POS_IMPO  = [(1:size(A,2))' AC__SHAPE_POS_IMPO]
RT__SHAPE_POS_IMPO  = [(1:size(A,2))' RT__SHAPE_POS_IMPO]

% remove excluded subjs
AC__SHAPE_POS_IMPO((AC__SHAPE_POS_IMPO(:,2) == 0 ),:) = []
RT__SHAPE_POS_IMPO((RT__SHAPE_POS_IMPO(:,2) == 0 ),:) = []


subplot(143)
hold all
title('ACC.  POSSIBLE vs IMPOSSIBLE')

bar([mean(AC__SHAPE_POS_IMPO(:,2)) mean(AC__SHAPE_POS_IMPO(:,3))], 'facecolor' ,'g')
errorbar([mean(AC__SHAPE_POS_IMPO(:,2)) mean(AC__SHAPE_POS_IMPO(:,3))], [std(AC__SHAPE_POS_IMPO(:,2))/sqrt(size(A,2)-numel(EXCLUDE)-1) std(AC__SHAPE_POS_IMPO(:,3))/sqrt(size(A,2)-numel(EXCLUDE)-1)])
ylim([0.5 1])
[h3 p3 ci3 stat3] = ttest(AC__SHAPE_POS_IMPO(:,2),AC__SHAPE_POS_IMPO(:,3))
%title(num2str(p3))
ax = gca
ax.XTick = [1 2 ] 
ax.XTickLabel = ({  'IN' , 'EX' })
subplot(144)
hold all
title('RT. POSSIBLE vs IMPOSSIBLE')

bar([mean(RT__SHAPE_POS_IMPO(:,2)) mean(RT__SHAPE_POS_IMPO(:,3))], 'facecolor' ,'g')
errorbar([mean(RT__SHAPE_POS_IMPO(:,2)) mean(RT__SHAPE_POS_IMPO(:,3))], [std(RT__SHAPE_POS_IMPO(:,2))/sqrt(size(A,2)-numel(EXCLUDE)-1) std(RT__SHAPE_POS_IMPO(:,3))/sqrt(size(A,2)-numel(EXCLUDE)-1)])
ylim([800 1000])
[h4 p4 ci4 stat4] = ttest(RT__SHAPE_POS_IMPO(:,2),RT__SHAPE_POS_IMPO(:,3))
ax = gca
ax.XTick = [1 2 ] 
ax.XTickLabel = ({  'IN' , 'EX' })%title(num2str(p4))

%%
%get trials without RT whether because removed or no-response
for SUBJ =  1:size(A,2)
    
    trialsWithoutRT_perSubj(SUBJ) = sum(isnan([A(SUBJ).t.rt]));
    aux = [];
    for t = 1:160
        aux(t) = (isnan([A(SUBJ).t(t).resp(1)]));
        
    end
    trialsMisfiredByUs(SUBJ) = sum(aux);
end

trialsMisfiredByUs'

%
%  anno1= annotation('textbox',...
%         [0.25 0.03 0.03 0.05],...
%         'String',strcat(num2str(ci1), '/', stat1.tstat, '/',stat1.df,  '/',stat1.sd),...
%         'FontSize',20)
%     set(anno, 'Interpreter', 'none');

%end
% CLOSE SUBJ LOOP
%end

%% extract 'A' as table
AOUT = table({A.subjName}', trialsWithoutRT_perSubj' , trialsMisfiredByUs',...
    {A.subjName}', AC_IN_EX(:,2:3),...
    mean(AC_IN_EX(:,2:3),2),...
    AC_IN_EX(:,2)-AC_IN_EX(:,3),...
    {A.subjName}', RT_IN_EX(:,2:3),...
    mean(RT_IN_EX(:,2:3),2),...
    RT_IN_EX(:,2)-RT_IN_EX(:,3),...
    {A.subjName}', AC__SHAPE_POS_IMPO(:,2:3),...
    {A.subjName}', RT__SHAPE_POS_IMPO(:,2:3))

