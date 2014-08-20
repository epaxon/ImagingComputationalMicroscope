function [fh] = export_example_component(icm, trial_idx, tab_idx, frame, filefolder)
% fh = export_example_component(icm, trial_idx, tab_idx, frame): creates a
% nice figure of a component. 
%
% @param: icm an ImagingComputationalMicroscope
% @param: trial_idx which trial from icm to plot. Default is current_trial
% @param: tab_idx which stage tab to plot (1: Data, 2: PP, 3: PCA, 4: ICA, 5: Segment, 6: Viz).
% Default is current tab.
% @param: which frame of the im_data in the tab to plot. Default current
% frame

offset = 5;

if nargin < 2 || isempty(trial_idx)
    trial_idx = icm.gui.current_trial;
end

if nargin < 3 || isempty(tab_idx)
    tab_idx = icm.gui.d(trial_idx).display;
end

if nargin < 4 || isempty(frame)
    frame = icm.gui.d(trial_idx).current_frame(tab_idx);
end

if nargin < 5
    filefolder = [];
end


%%
fh(1) = figure();
fh(2) = figure();
set(fh, 'Color', 'w');
set(fh(1), 'Position', [50 50 500 500]);
set(fh(2), 'Position', [550 50 800 400]);

ax_im = axes('Parent', fh(1), 'Position', [0 0 1 1]);
ax_component = axes('Parent', fh(2));

% %%
% 
% if tab_idx == 1
%     % Then on the data tab
%     
% elseif tab_idx == 2
%     % Then on the pp tab
%     
% elseif tab_idx == 3
%     % Then on the pca tab
%     
% elseif tab_idx == 4
%     % Then on the ica tab
% 
% elseif tab_idx ==5
%     % Then on segment tab
%     
% elseif tab_idx ==6
%     % THen on viz tab
%     
% else
%     % Then something is wrong'
%     disp(tab_idx);
%     error('incorrect display index');
% end
%     
%%
axes(ax_component);
cla(ax_component);
hold on;
comp_lines = get(icm.h.component_axes, 'Children');

for i = 1:length(comp_lines)
    if strcmp(get(comp_lines(i), 'Type'), 'line')
        xdata = get(comp_lines(i), 'XData');
        ydata = get(comp_lines(i), 'YData');
        
        plot(ax_component, xdata, ydata + (i-1) * offset, 'k', 'LineWidth', 2);
    end
end

%%
axes(ax_im);
cla(ax_im);

im_children = get(icm.h.roi_editor.h.im_axes, 'Children');

for i = 1:length(im_children)
    if strcmp(get(im_children(i), 'Type'), 'image')
        imagesc(get(im_children(i), 'CData'));
    end
end

axis(ax_im, 'xy');

set(ax_im, 'XTick', [], 'YTick', []);

%%

if ~isempty(filefolder)
    % Then save the plots
    tag = ['-t' num2str(trial_idx) '-d' num2str(tab_idx) '-f' num2str(frame) '-n' datestr(now, 'yymmdd')];
    
    trace_file = [filefolder 'traces' tag];
    im_file = [filefolder 'im' tag];
    
    saveas(fh(1), im_file, 'epsc');
    saveas(fh(1), im_file, 'fig');
    
    saveas(fh(2), trace_file, 'epsc');
    saveas(fh(2), trace_file, 'fig');
    
    figure(fh(1));
    faa1 = myaa;
    set(faa1, 'PaperPositionMode', 'auto');
    saveas(faa1, im_file, 'png');
    
    figure(fh(2));
    faa2 = myaa;
    set(faa2, 'PaperPositionMode', 'auto');
    saveas(faa2, trace_file, 'png');
end



