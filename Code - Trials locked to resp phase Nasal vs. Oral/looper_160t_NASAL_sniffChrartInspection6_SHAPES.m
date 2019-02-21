%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Supplementary Code for Perl et al. 2019
%%%
%%% This script loads a database containing all behavioral and
%%% physiological (respiratory) data collected during the session were the
%%% visuospatial task was triggered by respiratory phase onset
%%%
%%% This script is vvery similar to the ones used to analyze the behavioral data
%%% in the EEG experiment (filename 'EEG_sniffChart_Inspection6_SHAPES.m' )
%%% Breifly, the script goes into each folder and loads the xlsx behavioral log and
%%% Labchart physiological data stored as .MAT
%%%
%%%
%%%
%%% Dependecies: 'NanZScore' , 'sortcell'
%%%
%%% These results correspond to Supp. Figure 4 in the manuscript
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
whitebg('w')
shapes_key =   [0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,0,0,0,0,1,1,1,1,1,1,0,0,1,1,0,0,1,1,0,0,0,0,1,1,1,1,0,0,1,1,0,0,1,1,1,1,1,1,1,1,0,0,1,1,1,1,0,0,1,1,1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,1,1,1,1,0,0,0,0]

folderdir = dir
folderdir([folderdir.isdir] == 0) = []
folderdir = folderdir(3:end);
home = pwd

A = [] %preallocation

for subj = 1:length(folderdir)
    
    cd(home)
    cd(folderdir(subj).name)
    
    close all
    listxlsx = dir('*.xlsx');
    
    for j  = 1 :length(listxlsx)
        if strfind( listxlsx(j).name , '~')  ~= 0
            listxlsx(j)= []
        end
    end
    
    listmat = dir('*.mat');
    
    crop = []
    
    toSaveImages = 0 %toggle logical
    
    toPreloadedMisfiresFromMAT =1 %toggle logical
    
    toRemoveFirstTrialAnyway = 1  %toggle logical
    
    if listmat.bytes < 5E6
        toResampleTo1Khz  = 1  %toggle logical
    else
        toResampleTo1Khz  = 0
    end
    %%
    
    SUBJ =1:size(listxlsx,1) %go the xlsx file in a given  folder
    
    tic
    %verify each it has both types of files
    if  strcmp(lower(listxlsx(SUBJ).name(1:5)), lower(listmat(SUBJ).name(1:5)))
        disp('Match OK')
    else
        disp('Match PROBLEM:')
        disp(strcat(listxlsx(SUBJ).name, '////', listmat(SUBJ).name, '////', listmarkers(SUBJ).name))
    end
    
    close all
    %cleaning
    clearvars -except subj folderdir home crop toResampleTo1Khz toPreloadedMisfiresFromMAT ManualTaggingOfBadTrials SUBJ A testtype listmat listxlsx  listmarkers RootDir RootDirPath shapes_key toSaveImages toPreloadedMisfiresFromXLSX toRemoveFirstTrialAnyway
    
    subjfilename = listxlsx(SUBJ).name
    
    %%
    tic
    %param init.
    pathName = pwd;
    fs = 1000; %sampling rate
    allocation =5000 * (fs ./ 1000); %size of window to extract and save
    middle = 5000 %middle of window (half of 'allocation' size
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
    pause(1)
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
    
    %%
    %parameters:
    %preallocation
    block_trials = nan(allocation*2, num_trials);
    resp_blocks = nan(allocation*2, num_trials);
    
    from = nan(num_trials, 1);
    to = nan(num_trials, 1);
    
    %load MAT file of LabChart physiological recording
    disp('loading:')
    disp(listmat(SUBJ).name)
    pause(1)
    load(listmat(SUBJ).name)
    
    %% RESAMPLE TO 1 KHZ (stored as 100Hz)
    % Data were recorded and digitized at 1KHz but saved following downsampling
    % to 100Hz in order to save disk space.
    
    VER = ver; %get matlab version
    if strcmp(VER(1).Release,'(R2016a)') %syntax of 'resample' varies between Matlab versions.
        if toResampleTo1Khz  == 1
            
            C2B1 = resample(C2B1,1000,100);
            C3B1 = resample(C3B1,1000,100);
            C4B1 = resample(C4B1,1000,100);
            %  C5B1 = resample(C5B1,1000,100);
            C6B1 = resample(C6B1,1000,100);
            C7B1 = resample(C7B1,1000,100);
            C8B1 = resample(C8B1,1000,100);
            %  C9B1 = resample(C9B1,1000,100);
            
            if exist('C10B1')
                C10B1 = resample(C10B1,1000,100);
            end
            if exist('C11B1')
                
                C11B1 = resample(C11B1,1000,100);
            end
        end
        
    else
        
        if toResampleTo1Khz  == 1
            
            C2B1 = resample(C2B1,1000,100);
            C3B1 = resample(C3B1,1000,100);
            C4B1 = resample(C4B1,1000,100);
            %  C5B1 = resample(C5B1,1000,100);
            C6B1 = resample(C6B1,1000,100);
            C7B1 = resample(C7B1,1000,100);
            C8B1 = resample(C8B1,1000,100);
            %  C9B1 = resample(C9B1,1000,100);
            
            if exist('C10B1')
                C10B1 = resample(C10B1,1000,100);
            end
            if exist('C11B1')
                C11B1 = resample(C11B1,1000,100);
            end
        end
        
    end
    %%
    % In this session respiration was recorded in stereo from two spirometer,
    % one per nostril. Data will now be averaged across channels.
    
    respl = C3B1; respl = zscore(respl) ;
    respr = C4B1; respr = zscore(respr) ;
    
    trig1 = C7B1;
    trig2 = C8B1;
    trialonset_raw = C6B1;
    clearvars C2B1 C1B1 C4B1 C5B1 C6B1 C3B1 C7B1 C8B1 C9B1 C10B1
    
    disp('importing data from Chart ---> OK')
    
    %Data will now be averaged across channels.
    resp = (respl + respr ) ./ 2;
    
    %%
    %digitize response user input
    digitize_thresh = mean(trig1)./2;
    for i = 1:length(trig1)
        if trig1(i) < digitize_thresh    %flatten jagged voltage increase
            trig1(i) = 1;
        else
            trig1(i) = 0 ;
        end
    end
    for i = 1:length(trig2)
        if trig2(i) < digitize_thresh    %flatten jagged voltage increase
            trig2(i) = 1;
        else
            trig2(i) = 0 ;
        end
    end
    
    trialonset = []
    digitize_thresh2 = 3;
    for i = 1:length(trialonset_raw)
        if trialonset_raw(i) < digitize_thresh2    %flatten jagged voltage increase
            trialonset(i) = 1;
        else
            trialonset(i) = 0 ;
        end
    end
    trialonset = trialonset';
    
    % find Trials
    [triggers_trialonset_y triggers_trialonset_x] = findpeaks...
        (trialonset, 'minpeakdistance',10, 'minpeakheight' , 0.9);
    [triggers_y1 triggers_x1] = findpeaks...
        (trig1, 'minpeakdistance',10, 'minpeakheight' , 0.9);
    [triggers_y2 triggers_x2] = findpeaks...
        (trig2, 'minpeakdistance',10, 'minpeakheight' , 0.9);
    
    % triggers_x = sort([triggers_x1; triggers_x2]);
    
    trialStart = triggers_trialonset_x;
    
    sessionTime = (trialStart(end) - trialStart(1) ) ./ (60 * fs) %calculate session time (in minutes)
    
    %checkpoint1
    if numel(triggers_trialonset_x) == num_trials...
            disp 'detection of trials ---- > OK  '
    else
        disp 'detection of trials or answers ---- > ERROR?!  '
    end
    
    %%
    %division into blocks of trials and extraction of all physio channels
    %around trial onset window
    
    %division into blocks of trials
    
    t = [];
    
    for trial = 1:length(triggers_trialonset_x)
        if triggers_trialonset_x(trial) < allocation+1
            
            triggers_trialonset_x(trial) = allocation+1
            
        end
        temp_from = triggers_trialonset_x(trial)-allocation ; %idx of trial start % displays 1 sec before trial onset\
        
        temp_to = triggers_trialonset_x(trial) + allocation-1;
        
        temp_trig1_block = trig1(temp_from:temp_to,1);
        temp_trig2_block = trig2(temp_from:temp_to,1);
        
        temp_trig_trialonset_block = trialonset(temp_from:temp_to,1);
           
        temp_resp_block = resp(temp_from:temp_to,1);
        
        
        block_resp(1:length(temp_resp_block),trial) = temp_resp_block;
        
        trig_blocks1(1:length(temp_trig1_block),trial) = temp_trig1_block;
        trig_blocks2(1:length(temp_trig2_block),trial) = temp_trig2_block;
        trialonset_blocks(1:length(temp_trig2_block),trial) = temp_trig_trialonset_block;
        from(trial) = temp_from; %store all start times
        to(trial) = temp_to; %store all end times
        
        t(trial).resp = temp_resp_block;
        t(trial).respphase = angle(hilbert(temp_resp_block));
        t(trial).respphaseAttrig =     t(trial).respphase(middle);
        t(trial).trig1 = temp_trig1_block;
        t(trial).trig2 = temp_trig2_block;
        
        t(trial).trialonset= temp_trig_trialonset_block;
        
        
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
            if  t(l).auc1sec > 0
                XLS_log{l,3} = 'in ESTM';
                t(l).cond = {'in ESTM'};
            else
                XLS_log{l,3} = 'ex ESTM';
                t(l).cond = {'ex ESTM'};
            end
        end
    end
    
    %checkpoint2
    if size(block_trials,2) == num_trials
        disp 'division into blocks ---- > OK  '
    else
        disp 'division into blocks ---- > ERROR?!  '
    end
    
    %
    for i = 1:length(triggers_trialonset_x)
        ph_all(i) = [t(i).respphaseAttrig];
    end
    %%
    
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
    
    pause(0.5)
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
    h6 = figure(6);
    set(h6, 'Position', [0.1 0.1 1920 1024]);
    lineWidthParam = 1;
    ylimParam1 =prctile(resp,99.7);
    removemisfires = []
    tempColorVeca = 0.5;
    tempColorVecb = 0.9;
    tempColorVec = (tempColorVecb-tempColorVeca).*rand(size(t,2),1) + tempColorVeca;
    
    for l = 1:size(t,2)

        if strcmp(t(l).cond, 'in')
          
            hold all
            plot(t(l).resp, 'color', [1 0.4 0] , 'linewidth' , 0.5 )
            plot(t(l).trialonset, 'k')
            
            
        elseif strcmp(t(l).cond, 'ex')
        
            hold all
            plot(t(l).resp, 'color', [0 0.4 1 ] , 'linewidth' , 0.5 )
            plot(t(l).trialonset, 'k')
            
            
        elseif strcmp(t(l).cond, 'ex ESTM')
       
            hold all
            plot(t(l).resp, 'color', [0 0.4 1 ] , 'linewidth' , 0.5 , 'linestyle' , ':')
            plot(t(l).trialonset, 'k')
            
        elseif strcmp(t(l).cond, 'in ESTM')
   
            hold all
            plot(t(l).resp, 'color', [1 0.4 0 ] , 'linewidth' , 0.5 , 'linestyle' , ':')
            plot(t(l).trialonset, 'k')
        end
        
        ylim([-ylimParam1 ylimParam1])
        
        %drawnow
    end
    
    anno= annotation('textbox',...
        [0.03 0.03 0.1 0.05],...
        'String',subjfilename(1:6),...
        'FontSize',10)
    set(anno, 'Interpreter', 'none')
    
    if toSaveImages == 1
        tempFigureSaveName = strcat('AUTO_', subjfilename(1:6), '_SHAPES_1.jpeg')
        saveas(gcf,tempFigureSaveName)
    end
    %%
    if toPreloadedMisfiresFromMAT  == 0
        
        %  Visualization I
        trialToRemove = [];
        lineWidthParam = 1;
        ylimParam2 =3;
        gridx = 10;  gridy = 16;
        removemisfires = [];
        
        h1 = figure
        set(h1, 'Position', [0.1 0.1 1920 1024])
        
        for l = 1:160
            subplot(gridx,gridy,l)
            hold all
            axis off
            
            set(gca,'tag',num2str(l))
            set(gca,'FontSize',6)
            set(gcf,'color', [0.5 0.5 0.5])
            
            hold all
            tempcolor =  (t(l).ph_val + pi ) / (2*pi );
            
            patch([ middle*2 0 0 middle*2 ]  ,[ -5 -5 5 5 ]  ,[1-tempcolor tempcolor 0] , 'FaceAlpha',0.5, 'EdgeColor', 'k');
            patch([  middle+1200 middle  middle  middle+1200 ]  ,[ -5 -5 5 5 ]  ,'k' , 'FaceAlpha',0.3, 'EdgeColor', 'k');
            
            plot(zeros(length(t(l).trig1),1), 'k','linewidth' , 0.5)
            plot(t(l).resp, 'c', 'linewidth' , 1.5)
            plot(t(l).trialonset , 'y', 'linewidth' , 1.5)
            xlim([3000 7000])
            %   ylim([-ylimParam2 ylimParam2])
            ylim([-2.1 2.1])
            text(middle-2000, 0.5, num2str(t(l).ph_val) , 'fontsize' , 8)
            text(middle-2000, -0.5, num2str(t(l).rt), 'fontsize' , 8)
            
            if strcmp(t(l).cond, 'in')
                title(strcat(num2str(l), ':' ,'IN'), 'fontsize' ,8, 'color' , 'r' )
            elseif strcmp(t(l).cond, 'ex')
                title(strcat(num2str(l), ':' ,'EX'),'fontsize' ,8,  'color' , 'g' )
            elseif strcmp(t(l).cond, 'ex ESTM')
                title(strcat(num2str(l), ':' ,'EX ESTM'),'fontsize' ,8,  'color' , 'b' )
            elseif strcmp(t(l).cond, 'in ESTM')
                title(strcat(num2str(l), ':' ,'IN ESTM'),'fontsize' ,8,  'color' , 'b' )
            else
                title(strcat(num2str(l), ':' ,'?????'),'fontsize' ,8,  'color' , 'k' )
            end
            
            if mod(l,10) ==0
                drawnow
            end
            grid off
        end
        if toPreloadedMisfiresFromMAT == 0
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
                        h2 = text(x,y-1.5,'removed','vert','middle','horiz','center', 'color' , 'k', 'fontsize', 12);
                        trialToRemove = [trialToRemove str2num(h.String)];
                        
                end
            end
        end
        
        anno= annotation('textbox',...
            [0.03 0.03 0.1 0.05],...
            'String',subjfilename(1:6),...
            'FontSize',10)
        set(anno, 'Interpreter', 'none')
        tempFigureSaveName = strcat('AUTO_' , subjfilename(1:6), '_NASOR_SHAPES_TRIALS.jpeg')
        
        if toSaveImages == 1
            
            set(gcf, 'PaperUnits', 'inches');
            x_width=16.25 ;y_width=10.125
            set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
            saveas(gcf,tempFigureSaveName)
        end
        % saveas(gcf,tempFigureSaveName)
        close
        
        trialToRemove = sort(unique(trialToRemove))
        pause(1)
        
        %
        for i = 1:length(trialToRemove)
            XLS_log(trialToRemove(i),:) = [{trialToRemove(i)} {NaN} {NaN} {NaN} {'removed'}];
        end
        
    else  % suppose you want to load misfires from xls
        
        load PreloadedMisfires_N160   % LOAD FROM MAT
        
        if ~isempty(strfind(listxlsx.name, '160'))
            match = find(strcmp({APreloadedMisfires_N.name}, subjfilename(1:4)) == 1)
            trialToRemove = APreloadedMisfires_N(match ).vals;
            disp(APreloadedMisfires_N(match).name)
            disp(APreloadedMisfires_N(match).vals)
            
            for i = 1:length(trialToRemove)
                XLS_log(trialToRemove(i),:) = [{trialToRemove(i)} {NaN} {NaN} {NaN} {'removed'}];
            end
            
        elseif ~isempty(strfind(listxlsx.name, '_o'))
            match = find(strcmp({APreloadedMisfires_O.name}, subjfilename(1:4)) == 1)
            trialToRemove = APreloadedMisfires_O(match ).vals;
            disp(APreloadedMisfires_O(match).name)
            disp(APreloadedMisfires_O(match).vals)
            
            pause(1)
            
            for i = 1:length(trialToRemove)
                XLS_log(trialToRemove(i),:) = [{trialToRemove(i)} {NaN} {NaN} {NaN} {'removed'}];
            end
            
        else
            disp('COULD NOT LOAD TRIAL MISFIRES FILE!!')
        end
        
    end
    % according to toggle, removes first trial of the session
    % regardless of outcome or respiratory phase
    if toRemoveFirstTrialAnyway ==1
        trialToRemove = [1 trialToRemove];
        %  disp('PLEASE NOTE! 1st trial removed anyway')
        %  pause(2)
    end
    
    trialToRemove = sort(unique(trialToRemove));
    %%
    %  Visualization II - switch ESTIMATED TRIALS
    %  For trials without subject answer, estimation of trial condition (inhale / exhale )
    %  is made according to the ensuing respiratory trace. This automated
    %  process now undergoes visual inspection. By clicking on subplot the
    %  usser can switch trial condition
    
    trialToSwitch = [];
    lineWidthParam = 1;
    ylimParam2 =1.5;
    gridx = 10;  gridy = 16;
    removemisfires = [];
    
    f2 = figure
    set(f2, 'Position', [0.1 0.1 1920 1024])
    
    for l = 1:160
        subplot(gridx,gridy,l)
        hold all
        
        
        set(gca,'tag',num2str(l))
        set(gca,'FontSize',6)
        set(gcf,'color', [0.5 0.5 0.5])
        
        hold all
        tempcolor =  (t(l).ph_val + pi ) / (2*pi );
        
        if strcmp(t(l).cond, 'in')
            % patch([ middle*2 0 0 middle*2 ]  ,[ -5 -5 5 5 ]  ,[0 0 0 ] , 'FaceAlpha',0.5, 'EdgeColor', 'k');
        elseif strcmp(t(l).cond, 'ex')
            % patch([ middle*2 0 0 middle*2 ]  ,[ -5 -5 5 5 ]  ,[0 0 0 ] , 'FaceAlpha',0.5, 'EdgeColor', 'k');
        else
            patch([ middle*2 0 0 middle*2 ]  ,[ -5 -5 5 5 ]  ,[1-tempcolor tempcolor 0] , 'FaceAlpha',0.5, 'EdgeColor', 'k');
        end
        %    end
        
        patch([  middle+1200 middle  middle  middle+1200 ]  ,[ -5 -5 5 5 ]  ,'k' , 'FaceAlpha',0.3, 'EdgeColor', 'k');
        
        plot(zeros(length(t(l).trig1),1), 'k','linewidth' , 0.5)
        plot(t(l).resp, 'c', 'linewidth' , 1.5)
        plot(t(l).trialonset , 'y', 'linewidth' , 1.5)
        xlim([3000 7000])
        ylim([-ylimParam2 ylimParam2])
        text(middle-2000, 0.8, num2str(t(l).ph_val) , 'fontsize' , 8)
        text(middle-2000, 0.5, num2str(t(l).rt), 'fontsize' , 8)
        
        if strcmp(t(l).cond, 'in')
            title(strcat(num2str(l), '::' ,'IN'), 'fontsize' ,8, 'color' , 'k' )
        elseif strcmp(t(l).cond, 'ex')
            title(strcat(num2str(l), '::' ,'EX'),'fontsize' ,8,  'color' , 'k' )
        elseif strcmp(t(l).cond, 'ex ESTM')
            title(strcat(num2str(l), '::' ,'EX ESTM'),'fontsize' ,8,  'color' , 'y' )
        elseif strcmp(t(l).cond, 'in ESTM')
            title(strcat(num2str(l), '::' ,'IN ESTM'),'fontsize' ,8,  'color' , 'y' )
        else
            title(strcat(num2str(l), '::' ,'?????'),'fontsize' ,8,  'color' , 'k' )
        end
        
        if mod(l,10) ==0
            drawnow
        end
        grid off
        % axis off
    end
    
    anno= annotation('textbox',...
        [0.03 0.03 0.1 0.05],...
        'String',subjfilename(1:6),...
        'FontSize',10)
    set(anno, 'Interpreter', 'none')
    
    close
    
    %% ANALYZER  - SHAPES check subject's answers
    counter_noans = 0;
    num_trials = length(XLS_log);
    for i = 1:length(XLS_log)
        
        if ~ismember(i , trialToRemove) %if this trial is legit == was not included in those that should be removed
            
            tempWordString = cell2mat(XLS_log(i,2));
            if ~isnan(tempWordString) %if it is filled with text == we have a response from subject
                %crop word stimuli from string
                
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
                if strcmp(XLS_log(i,3),{'ex ESTM'})
                    XLS_log(i,3) = {'ex'};
                elseif  strcmp(XLS_log(i,3),{'in ESTM'})
                    XLS_log(i,3) = {'in'};
                end
            end
            
        else  %was removed because of misfire
            t(i).accuracy = NaN;
            t(i).rt = NaN;
        end
    end
    
    % trials that are removed are being scrubbed
    for i = 1:length(trialToRemove)
        t(trialToRemove(i)).resp = NaN;
        t(trialToRemove(i)).trig1 = NaN;
        t(trialToRemove(i)).trig2 = NaN;
        t(trialToRemove(i)).trialonset   	 = NaN;
        t(trialToRemove(i)).cond = NaN;
        t(trialToRemove(i)).userInput = NaN;
        t(trialToRemove(i)).rt = NaN;
    end
    
   
    %% GROUPING BY RESP COND
    % In this final step we look at group level. Groups are defined
    % according to resp. condition or according to Shape type 
    
    ctgGrouped =[];
    categoryTypes = [{'in'}, {'ex'}];
    tempWhere = []
    %average across parameters
    for k = 1:length(categoryTypes)
        for kk = 1:size(t,2)
            tempWhere1(kk) = strcmp([t(kk).cond],categoryTypes(k));
        end
        
        for kk = 1:size(t,2)
            tempWhere2(kk) = strcmp([t(kk).cond],strcat(categoryTypes(k),' ESTM')); %trials assumed to be in or ex but
            %unanswered so no log. Still, no answer means an error in a
            %legit trial
        end
        
        tempWhere = tempWhere1+tempWhere2;
        
        tempWhere = logical(tempWhere);
        
        ctgGrouped(k).resp.vals = ([t(tempWhere).resp]);
        ctgGrouped(k).resp.mean = nanmean([t(tempWhere).resp],2);
        ctgGrouped(k).resp.std = std([t(tempWhere).resp],0,2);
        ctgGrouped(k).resp.se = (std([t(tempWhere).resp],0,2))./(size(ctgGrouped(k).resp.vals,2)-1)^0.5;
        ctgGrouped(k).categoryName = categoryTypes{k};
        
        ctgGrouped(k).rt.table = [(1:length(tempWhere))' tempWhere' ([t.rt])'];
        ctgGrouped(k).rt.vals = ([t(tempWhere).rt]);
        ctgGrouped(k).rt.mean = nanmean([t(tempWhere).rt]);
        ctgGrouped(k).rt.std = nanstd([t(tempWhere).rt],0,2);
        ctgGrouped(k).rt.se =  ctgGrouped(k).rt.std./(size(ctgGrouped(k).rt.vals,2)-1)^0.5;
        
        ctgGrouped(k).accu.table = [(1:length(tempWhere))' tempWhere' ([t.accuracy])'];
        ctgGrouped(k).accu.vals = ([t(tempWhere).accuracy]);
        ctgGrouped(k).accu.mean = nansum([t(tempWhere).accuracy]) / sum(tempWhere) ;
        
    end
    %%
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
    CONTRAST = [ 1:2  ];  % contrasting two experimental conditions 
    %that are stored in the same struct
    
    for k = 1:length(CONTRAST) %1:length(categoryTypes)
        subplot(1,3,1:2)
        disperse=[];
        hold all
        title(subjfilename)
        if k == 1
            auxColor = [1 0.4 0 0.7];
        elseif k == 2
            auxColor = [0 0.4 1 0.7];  
        end
        
        h = plot(ctgGrouped((CONTRAST(k))).resp.mean, 'linewidth' , 5, 'color' , auxColor);
        auxColor = h.Color;
        
        plot(ctgGrouped(CONTRAST(k)).resp.vals, 'color',[auxColor 0.4] , 'linewidth' , 1);
        plot(ctgGrouped(CONTRAST(k)).resp.mean+ctgGrouped(CONTRAST(k)).resp.se, '-', 'color',auxColor);
        plot(ctgGrouped(CONTRAST(k)).resp.mean-ctgGrouped(CONTRAST(k)).resp.se, '-', 'color',auxColor);
        plot(trialonset_blocks,'k');
        
        ylabel('resp z')
        xlim([1 9500])

        auxBarRTMean(end+1) = ctgGrouped(CONTRAST(k)).rt.mean;
        auxBarRTSE(end+1) = ctgGrouped(CONTRAST(k)).rt.se;
        auxx = ctgGrouped(CONTRAST(k)).accu;
        auxBarAccuMean(end+1) = nanmean(auxx.vals)
        
        auxBarRTMeanShapeType(end+1) = ctgGroupedShapeType(CONTRAST(k)).rt.mean;
        auxBarRTSEShapeType(end+1) = ctgGroupedShapeType(CONTRAST(k)).rt.se;
        %auxxShapeType = ctgGroupedShapeType(CONTRAST(k)).accu;
        %auxBarAccuMeanShapeType(end+1) = nanmean(auxxShapeType.vals)
        
        str = LEGEND(CONTRAST(k));
        disperse(k) = 1-1/numel(CONTRAST)*k*0.7;
        
        dim=([0.01   disperse(k)/4 0.02 0.05]);
        a = annotation('textbox',dim,'String',str );
        a.FontSize = 40;
        a.Color = auxColor;
    end
    
    %auxBarRTMean
    subplot(388);
    hold all
    bar(auxBarRTMean);
    errorbar(auxBarRTMean, auxBarRTSE);
    title('RT - in vs ex')
    ylabel('ms')
    ylim([500 1600])
    xlim([0.5 2.5])
    
    %auxBarRTMeanShapeType
    subplot(3,8,16);
    hold all
    bar(auxBarRTMeanShapeType);
    errorbar(auxBarRTMeanShapeType, auxBarRTSEShapeType);
    title('RT - posssible vs impossible')
    ylabel('ms')
    xlim([0.5 2.5])
    ylim([500 1600])
    
    %auxBarAccuMean
    subplot(3,8,24)
    hold all
    hh = bar(auxBarAccuMean);
    hh.FaceColor = 'r';
    hh.EdgeColor = 'b';
    xlim([0.5 2.5])
    title('ACCU. in vs ex.');
    ylabel('a.u.');
    ylim([0.3 1])
    
    textSummary = {strcat('#trials no answer:', num2str(numel(missing_trials))  ,char(10)) , ...
        strcat('#'  ,char(10)) , ...
        strcat('#trials manually removed:', num2str(numel(trialToRemove))  ,char(10)) , ...
        strcat('#'  ,char(10)) , ...
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
        [0.01 0.75 0.1 0.15],...
        'String',textSummary,...
        'FontSize',10);
    
    
    for i = 1:size(t,2)
        if strcmp(t(i).cond,'in');
            validIN(i) =  1 ;
        else
            validIN(i) =  0 ;
            
        end
    end
    
    for i = 1:size(t,2)
        if strcmp(t(i).cond,'ex');
            validEX(i) =  1 ;
        else
            validEX(i) =  0 ;
        end
    end

    textSummary2 = {strcat('#valid trials in INHALE:', num2str(sum(validIN))  ,char(10)) , ...
        strcat('#valid trials in EXHALE:', num2str(sum(validEX))   ,char(10)    )}
    
    annoTop2= annotation('textbox',...
        [0.01 0.60 0.1 0.1],...
        'String',textSummary2,...
        'FontSize',10);
    
    textSummary3 = {  strcat('   RT IN    :', num2str(auxBarRTMean(1))  ,char(10)) , ...
        char(10),...
        strcat('  RT EX   :', num2str(auxBarRTMean(2))  ,char(10)) ...
        }
    annoTop= annotation('textbox',...
        [0.01 0.45 0.1 0.15],...
        'String',textSummary3,...
        'FontSize',10);
       
    disp('>>>>>IN ........ EX')
    disp(auxBarAccuMean)
    disp('>>>>>>>>>>>>>>>>>>>>')
    
    if toRemoveFirstTrialAnyway ==1  
        disp('PLEASE NOTE! 1st trial removed anyway')   
    end
    
    if toSaveImages == 1;
        tempFigureSaveName = strcat('AUTO_' ,subjfilename(1:6), '_NASOR_SHAPES_SUMMARY.jpeg');
        set(gcf, 'PaperUnits', 'inches');
        x_width=16.25 ;y_width=10.125;
        set(gcf, 'PaperPosition', [0 0 x_width y_width]); %
        saveas(gcf,tempFigureSaveName);
    end

    %clean 
    for o = 1:size(t,2)
        t(o).respphase = [];
        t(o).trig1 = [];
        t(o).trig2 = [];
    end
    
    %store:
    A(subj).t = t;
    A(subj).ctg = ctgGrouped;
    A(subj).ctgShapeType = ctgGroupedShapeType	;
    A(subj).subjName = subjfilename;
    A(subj).subjNumber = SUBJ;
    A(subj).log = XLS_log;
    A(subj).resp_trace = resp;
    A(subj).sessionLength =  (triggers_trialonset_x(end) - triggers_trialonset_x(1)) / 60 / fs  %in minutes
    A(subj).triggers_trialonset_x = triggers_trialonset_x;
    A(subj).trig_trace = trialonset;   
    toc
   
end
