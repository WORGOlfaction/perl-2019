% 
% figure
% hold all
% plot(sum(r_vec'))
% %
% plot(sum(mse_vec'))
% 
% %%
% figure
% hold all
% 
% for w = 1:180
% m(:,w) = (sum(masks(:,:,w),2));
% 
% end

%%
% idx = []
% for i =  1:360
%     if strfind( l{i} , 'IN' )
%         
%         idx = [idx i]
%     end
% end
% %%
% l2 = l(idx)
clear
load('labels.mat')
load('x_in-x_ex_58_sh.mat')
%%
figure
sp1 = subplot(211)
sp1.FontSize = 1
colormap(flipud(bone))
imagesc(squeeze(masks(1,:,:)).*100)

hold all

sp2 = subplot(212)
sp2.Position = sp1.Position


b = bar(mean(squeeze(masks(1,:,:)).*100), 'k')
set(gca, 'Color', 'None')


set(gca,'XTickLabel',l2,...
    'XTick',[1:180], 'fontsize' ,6 , 'XTickLabelRotation' , 90);


cm = mean(squeeze(masks(1,:,:)))
b.FaceColor = 'flat';
b.FaceAlpha = 0.9
for i = 1:180
b.CData(i,:) =[(cm(i)/0.5) 0.4 1-(cm(i)/0.5) ];
end


