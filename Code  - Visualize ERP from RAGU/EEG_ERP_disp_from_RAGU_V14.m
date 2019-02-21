%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Supplementary Code for Perl et al. 2019
%%%
%%% This script loads a pre-saved RAGU database containing containing
%%% EEG-ERP matrices collected during the EEG sessions where task was
%%% presented locked to respiratory phase - inhalation or exhalation onset
%%%
%%% RAGU workspace is saved as 'rd' variable. Within which is the rd.V
%%% 4D matrix: Subjects X 2 Condition X 64 Electrodes X 384 (time
%%% series, 1500 ms sampled at 256 Hz (500ms baseline and 1000ms of evoked response)
%%%
%%% rd.Channel.Name holds electrode names
%%% The start and end points of a significant time window calcualted elsewhere using tANOVA within RAGU
%%% are fed into the script in: 'effectFrom' and 'effectTo' variables (time
%%% in ms post t=0)
%%%
%%% One may load the RAGU data file for the EEG-ERP of the visuospatial
%%% task and replicate the findings shown in Figure 5 by choosing to
%%% display electrodes P4 and FC5 with a time window
%%% ('effectFrom:effectTo') of 185 - 270 ms post stimulus onset. 
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
filetoload =  'SHAPES_RAGU_V14byMatlab_Shdu_Asma_excld'
load(filetoload)

%%
effectFrom = 185; %time in ms post t=0
effectTo = 270;  %time in ms post t=0

%color scheme
if isempty(strfind(filetoload , 'C_vs_W'))
    colorIn = [1 0.4 0];
    colorEx = [ 0 0.4 1];
else
    colorIn = [0.74 0.2 0.8];
    colorEx = [ 0.5 0.93 0.1];
end

ELEC_ARRAY = [1:1:64]
PLOTSIZEFACTOR = 0.04 %for head montage figure size

DATA = rd.V;
whitebg('w')
% load coordinates for head montage. Notice these are spaced further apart
% to enable easy visualization on account of displaying actual distances using the
% 10-20 system
[eega eegb eegc ] = xlsread('eegCoordsModifiedForRaguDispOnMatlab2.xlsx')
eega = round((eega));

%convert time window to time-series index
fromIdx = (500+effectFrom)/1500*384;
toIdx = (500+effectTo)/1500*384;
%generate patch of significant time window
patchx = [         fromIdx              toIdx                     toIdx                    fromIdx   ];
patchy = [             5                  5                          -5                       -5     ];

plotOnHead = 1; %toggle logical;
toreverse = 1 ;%toggle logical for yaxis flip
%
numSubj = size(rd.V,1);

%subjets who where removed elsewhere in RAGU software due to excessive
%distance are scrubbed here:
%Prior to permutations, data were re-referenced to average, and underwent
%multi-dimensional scaling to remove outliers within the RAGU package,
%with exclusion threshold set at p < 0.05. Randomization parameters were
%set to 5,000 permutations on the L2 norm (scale to unity variance) of the raw data.
for a = 1:numSubj
    if isnan(rd.IndFeature(a))
        rd.V(a,:,:,:) = nan;
    end
end
%% This section draws all ERPs on subplots corresponding to their location on the scalp
%figure params
ELEC_ARRAY = [1:1:64]
close all
h=figure(3);
set(h, 'Position', [1 1 1920 1040]);

fig = gcf;
fig.Color = [1 1 1 ];
set(0, 'DefaultAxesFontName', 'Arial')
axis off

c =(eega); %baseline for figure display normalization of between-electrode distances
pos1 = [];
c(:,1) = (100+c(:,1))./max(100+c(:,1));
c(:,2) = (100+c(:,2))./max(100+c(:,2));

t_vec  = size(rd.V,4); %num of time points

%
for counter  =1:numel(ELEC_ARRAY)
    
    size1 = 0.07;
    size2 = 0.08;
    
    e = ELEC_ARRAY(counter); % e is electrode index
    drawnow
    hold all
    
    axis off
    hax = axes('Position', [c(e,2)/1.1 (c(e,1)/1.1) size1 size2]);
    set(hax,'XTick',[])
    
    %preallocation to collect ERP signal according to condition (inhale /
    %exhale)
    gather1 = [];
    gather2 = [];
    
    for s = 1:numSubj
        hold all
        for cond = 1:2  
            plot(zeros(1,384), 'k')

            if cond == 1
                gather1 = [gather1  squeeze(rd.V(s,cond,e,:)) ] ;
                
            elseif cond == 2
                gather2 = [gather2  squeeze(rd.V(s,cond,e,:)) ] ;
            end
        end
    end
    
    set (gca,'Ydir','reverse')
    set (gca, 'Fontsize' , 10)
    stem(384/3 ,20 , 'xk' ,'linewidth' , 1)
    stem(384/3 ,-20 , 'xk' ,'linewidth' , 1)
    
    %mark widow of effect
    stem((500+effectFrom)/1500*384 ,20 , 'xk' ,'linewidth' , .3)
    stem((500+effectFrom)/1500*384 ,-20 , 'xk','linewidth' , .3)
    stem((500+effectTo)/1500*384 ,-20 , 'xk','linewidth' , .3)
    stem((500+effectTo)/1500*384 ,20 , 'xk','linewidth' , .3)
    
    %collapse
    cond1_m = nanmean(gather1,2);
    cond2_m = nanmean(gather2,2);
    cond1_se = nanstd(gather1,0,2) ./ sqrt(size(gather1,2) - 1 );
    cond2_se = nanstd(gather2,0,2) ./ sqrt(size(gather2,2) - 1 );
    
    %fill patch of window of effect
    fromIdx = (500+effectFrom)/1500*384;
    toIdx = (500+effectTo)/1500*384;
    patchx = [         fromIdx              toIdx                     toIdx                    fromIdx   ];
    patchy = [             6               6                              -6                       -6     ];
    ptch = patch(patchx,patchy, 'w');
    ptch.FaceColor = 'k';
    ptch.FaceAlpha = 0.05;
    
    
    %plot mean and se per subj
    plot(cond1_m  , 'color' ,[colorIn 1]  , 'linewidth' , 1 )
    plot(cond2_m  , 'color' ,[colorEx 1 ]  , 'linewidth' , 1 )
    
    plot(cond1_m + cond1_se ,'color' ,[colorIn 0.8] , 'linestyle'  ,':')
    plot(cond1_m - cond1_se ,'color' ,[colorIn 0.8 ] , 'linestyle'  ,':')
    
    plot(cond2_m + cond2_se ,'color' ,[colorEx 0.8], 'linestyle'  ,':')
    plot(cond2_m - cond2_se ,'color' ,[colorEx 0.8 ], 'linestyle'  ,':')
    
    lim1 = nanmax(nanmax([(cond1_m+cond1_se)*1.05  ; (cond2_m+cond2_se)*1.05 ]));
    lim2 = nanmin(nanmin([(cond1_m-cond1_se)*1.05  ; (cond2_m-cond2_se)*1.05 ]));
    xlim([0 384])
    
    ylim([-3.5 3.5 ])
    
    axis off
    grid off
    ls = [-500:100:1000] ;
    set(gca,'XTickLabel',ls,...
        'XTick',[0:t_vec/(length(ls(1:end))-1):(t_vec)], 'fontsize' ,6 , 'XTickLabelRotation' , 90);
    
    text(46, -3 , rd.Channel(e).Name);
    
end
%%  This section focuses on requested electrodes of choice and plots them inidividually
% Any vector of electrodes may serve as input
% Consult with rd.Channel.name for electrode name-number pairing

ELEC_ARRAY = [14 35 46 58 ] %example

fromIdx = (500+effectFrom)/1500*384;
toIdx = (500+effectTo)/1500*384;
patchx = [         fromIdx              toIdx                     toIdx                    fromIdx   ];
patchy = [             5                  5                          -5                       -5     ];

close
h=figure(4);
set(h, 'Position', [1 1 1920 1040]);

fig = gcf;
fig.Color = [1 1 1 ];
set(0, 'DefaultAxesFontName', 'Arial')
%axis off
% %
% %load coords64.mat
c =(eega);

pos1 = [];
t_vec  = size(rd.V,4);
%c = flipud(c)%

grid1 = ceil(sqrt(numel(ELEC_ARRAY)));

for counter  =1:numel(ELEC_ARRAY)
    
    e = ELEC_ARRAY(counter);
    drawnow
    hold all
    
    subplot(grid1,grid1,counter)
    
    %preallocate
    gather1 = [];
    gather2 = [];
    
    for s = 1:numSubj   
        hold all
        for cond = 1:2
            plot(zeros(1,384), 'k')
            
            if cond == 1
                gather1 = [gather1  squeeze(rd.V(s,cond,e,:)) ] ;
                
            elseif cond == 2
                gather2 = [gather2  squeeze(rd.V(s,cond,e,:)) ] ;
            end
        end
    end
    
    ylim([-4 4 ])
    
    set (gca,'Ydir','reverse')
    set (gca, 'Fontsize' , 12)
    stem(384/3 ,20 , ':xk' ,'linewidth' , 1)
    stem(384/3 ,-20 , ':xk' ,'linewidth' , 1)
    
    stem((500+effectFrom)/1500*384 ,20 , 'xk' ,'linewidth' , 1)
    stem((500+effectFrom)/1500*384 ,-20 , 'xk','linewidth' , 1)
    
    stem((500+effectTo)/1500*384 ,-20 , 'xk','linewidth' , 1)
    stem((500+effectTo)/1500*384 ,20 , 'xk','linewidth' , 1)
    
    %collapse
    cond1_m = nanmean(gather1,2);
    cond2_m = nanmean(gather2,2);
    cond1_se = nanstd(gather1,0,2) ./ sqrt(size(gather1,2) - 1 );
    cond2_se = nanstd(gather2,0,2) ./ sqrt(size(gather2,2) - 1 );
    
    %plot mean and se per subj
    fromIdx = (500+effectFrom)/1500*384;
    toIdx = (500+effectTo)/1500*384;
    patchx = [         fromIdx              toIdx                     toIdx                    fromIdx   ];
    patchy = [             6               6                              -6                       -6     ];
    
    %plot fill patch
    ptch = patch(patchx,patchy, 'w');
    ptch.FaceColor = 'k';
    ptch.FaceAlpha = 0.1;
    ptch.EdgeColor = 'none';
    
    %plot mean and se per subj
    plot(gather1  , 'color' ,[colorIn 0.2]  , 'linewidth' , 0.3 )
    plot(gather2  , 'color' ,[colorEx 0.2]  , 'linewidth' , 0.3 )
    
    plot(cond1_m  , 'color' ,[colorIn 1]  , 'linewidth' , 1.5 )
    plot(cond2_m  , 'color' ,[colorEx 1 ]  , 'linewidth' , 1.5 )
    plot(cond1_m + cond1_se ,'color' ,[colorIn 0.8] , 'linestyle'  ,':'  , 'linewidth' , 1.5 )
    plot(cond1_m - cond1_se ,'color' ,[colorIn 0.8 ] , 'linestyle'  ,':'  , 'linewidth' , 1.5 )
    
    plot(cond2_m + cond2_se ,'color' ,[colorEx 0.8], 'linestyle'  ,':'  , 'linewidth' , 1.5 )
    plot(cond2_m - cond2_se ,'color' ,[colorEx 0.8 ], 'linestyle'  ,':'  , 'linewidth' , 1.5 )
    lim1 = nanmax(nanmax([(cond1_m+cond1_se)*1.05  ; (cond2_m+cond2_se)*1.05 ]));
    lim2 = nanmin(nanmin([(cond1_m-cond1_se)*1.05  ; (cond2_m-cond2_se)*1.05 ]));
       
    grid off
    ls = [-500:100:1000] ;
    set(gca,'XTickLabel',ls,   'XTick',[0:(384)/length(ls(1:end-1)):(384)], 'fontsize' ,10);
       
    text(96, 2 , rd.Channel(e).Name, 'fontsize' , 10);
    ylabel('\mu V')
    
end