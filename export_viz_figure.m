function [fh, rois] = export_viz_figure(icm, trial_idx, pc_coh_flag, rois, alias)
% fh = export_viz_figure(icm, trial_idx, pc_coh_flag, rois): creates a nice
% figure from analysis using icm.
%
% @param: icm an ImagingComputationalMicroscope
% @param: trial_idx which trial from icm to plot. Default current_trial
% @param: pc_coh_flag plot the pcs or the coherence. Default display
% @param: rois a list of rois to plot, a zero plots only sig rois.

if nargin < 2 || isempty(trial_idx)
    trial_idx = icm.gui.current_trial;
end

if nargin < 3 || isempty(pc_coh_flag)
    % not sure how to handle this yet
    pc_coh_flag = 1;
end

if nargin < 4 || isempty(rois)
    % there are many possibilities...
    rois = [];
end

if nargin < 5 || isempty(alias)
    alias = [];
end

%% Other parameters
offset = 10;
%xlimits
label_x_offsets = 30;

%%

fh(1) = figure();
fh(2) = figure();
fh(3) = figure();
set(fh, 'Color', 'w');
set(fh(1), 'Position', [50 50 500 500]);
set(fh(2), 'Position', [550 50 500 500]);
set(fh(3), 'Position', [1050 50 500 500]);

% ax_im = axes('Parent', fh, 'Position', [0 0.5 0.5 0.5]);
% ax_plot = axes('Parent', fh, 'OuterPosition', [0 0 0.5 0.5]);
% ax_traces = axes('Parent', fh, 'OuterPosition', [0.5 0 0.4 1]);

ax_traces = axes('Parent', fh(1), 'OuterPosition', [0 0 0.92 1]);
ax_plot = axes('Parent', fh(2));
ax_im = axes('Parent', fh(3), 'Position', [0 0 1 1]);

set(ax_im, 'XTick', [], 'YTick', [], 'Box', 'on');
%

if pc_coh_flag
    % Then we're doing the coherence
    
    %%
    cg = icm.h.ica_coherence;
    
    %%
    cols = cg.get_colors();
    phases = cg.get_phases();
    sig = cg.get_sig_coherence();
    sig_level = cg.significance_level;
    
    cphase = cg.cphase;
    cmag = cg.cmag;
    freqs = cg.freqs;
    freq_idx = cg.freq_idx;
    base = cg.base;
    
    % if rois is empty use sig rois
    if isempty(rois)
        rois = sig;
        rois(rois==base) = [];
    end
    
    [~, sidx] = sort(wrapToPi(phases(rois) - pi/4));
    
    mags = cmag(freq_idx, :);
    
    
    
    %%
    axes(ax_plot);
    hold(ax_plot, 'on');
    axis(ax_plot, 'equal');
    
    ph = 0:pi/100:2*pi;
    
    % Draw a line for the boundary
    plot(cos(ph), sin(ph), 'k', 'LineWidth', 2, 'HitTest', 'off', 'HandleVisibility', 'off');
    
    % Draw border lines
    plot([0 0], [-1 1], 'k', 'LineWidth', 2, 'HitTest', 'off', 'HandleVisibility', 'off');
    plot([-1 1], [0 0], 'k','LineWidth', 2,  'HitTest', 'off', 'HandleVisibility', 'off');
    
    % Draw sig line
    plot(sig_level * cos(ph), sig_level * sin(ph), '--r');
    
    for i = 1:length(mags)
        mx = mags(i).*cos(phases(i));
        my = mags(i).*sin(phases(i));
        
        if ~ismember(i, rois) && ~ismember(i, base) && ~ismember(i, sig)
            plot(mx, my, 'o', 'MarkerFaceColor', [0.5, 0.5, 0.5], 'MarkerEdgeColor', [0.5, 0.5, 0.5], 'MarkerSize', 10);
        elseif ismember(i, sig)
            plot(mx, my, 'o',  'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor', cols(i,:), 'MarkerSize', 10);
        end
    end
    
    for i = length(mags):-1:1
        mx = mags(i).*cos(phases(i));
        my = mags(i).*sin(phases(i));
        
        if ismember(i, rois)
            % Plot a big marker and the number
            plot(mx, my, 'o', 'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor', cols(i,:), 'MarkerSize', 20);
            [~, ib] = ismember(i, rois);
            if length(alias) >= ib
                name = alias{ib};
            else
                name = num2str(i);
            end
            text(mx, my, name, 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 14);
            
        end
    end
    
    
    text(1, -1, [num2str(freqs(freq_idx), 2) ' Hz'], 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 18, 'HorizontalAlignment', 'right');
    
    axis([-1.1 1.1 -1.1 1.1]);
    
    set(ax_plot, 'XColor', 'w', 'YColor', 'w', 'Box', 'off');
else
    %%
    cols = icm.data(trial_idx).viz.colors;
    base = [];
    sidx = 1:length(rois);
    
    %% ok we're going to do some stuff to get the right view and do what i want
    pcv = icm.h.pc_ica_viewer;
    
    [el, az] = view(pcv.h.pc_axes);
    
    x_pc = pcv.gui.x_pc;
    y_pc = pcv.gui.y_pc;
    z_pc = pcv.gui.z_pc;
    
    axes(ax_plot);
    hold(ax_plot, 'on');
    for i = 1:size(pcv.scores, 1)
        if ismember(i, rois) 
            plot3(ax_plot, pcv.scores(i, x_pc), pcv.scores(i, y_pc), pcv.scores(i, z_pc), 'o', ...
                'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor', cols(i,:), 'MarkerSize', 20);
            text(pcv.scores(i, x_pc), pcv.scores(i, y_pc), pcv.scores(i, z_pc), num2str(i), ...
                'Parent', ax_plot, ...
                 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 14);
        else
            plot3(ax_plot, pcv.scores(i, x_pc), pcv.scores(i, y_pc), pcv.scores(i, z_pc), 'o', ...
                'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor', cols(i,:), 'MarkerSize', 10);
        end        
    end
    
    view(ax_plot, [el, az]);
    axis(ax_plot, 'vis3d');
    set(ax_plot, 'XTick', [], 'YTick', [], 'ZTick', [], 'FontSize', 18);
    
    xlabel(['PC: ' num2str(x_pc)]);
    ylabel(['PC: ' num2str(y_pc)]);
    zlabel(['PC: ' num2str(z_pc)]);
%         
%     pc_ax = copyobj(icm.h.pc_ica_viewer.h.pc_axes, fh(2));
%     % Change back
%     icm.h.pc_ica_viewer.gui.text_mode = 1;
%     icm.h.pc_ica_viewer.update();
%     
%     % Now we should have a bunch of single point lines
%     pc_ax_children = get(pc_ax, 'Children');
%     
%     set(pc_ax_children, 'MarkerSize', 10);
%     % For now, I'm just going to rely that there are only children for each
%     % ROI.
%     
%     for i = 1:length(rois)
%         % Ok, so get the coords and change the marker size for the examples
%         x_roi = get(pc_ax_children(rois(i)), 'XData');
%         y_roi = get(pc_ax_children(rois(i)), 'YData');
%         z_roi = get(pc_ax_children(rois(i)), 'ZData');
%         
%         set(pc_ax_children(rois(i)), 'MarkerSize', 20);
%         
%         text(x_roi(1), y_roi(1), z_roi(1), num2str(rois(i)), 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold', 'FontSize', 14);
%     end
%     
%     %% 
%     set(pc_ax, 'OuterPosition', [0 0 1 1])
%     
end
%%

if isfield(icm.data(trial_idx).ica, 'post_ics')
    traces = icm.data(trial_idx).ica.post_ics;
else
    traces = icm.data(trial_idx).ica.ics;
end

data_t = icm.data(trial_idx).im_z(icm.data(trial_idx).pp.im_z);

axes(ax_traces);
set(ax_traces, 'YColor', 'w', 'FontSize', 18);
hold(ax_traces, 'on');

if ismember(base, rois)
    plot(data_t, traces(:, base), 'LineWidth', 2, 'Color', cols(base, :));
    
    
    idx = find(rois==base);
    if length(alias) >= idx
        name = alias{idx};
    else
        name = num2str(base);
    end
    
    text(data_t(end) + 0.05 * data_t(end), 0.5, name,...
        'Color', cols(base,:), 'FontWeight', 'bold', 'FontSize', 18);
    
    % Ok want to take base out of rois so don't redraw
    rois2 = rois;
    idx = find(rois==base);
    rois2(idx) = [];
    sidx2 = sidx;
    sidx2(idx) = [];
    alias2 = alias;
    if length(alias2) > idx
        alias2(idx) = [];
    end
else
    if ~isempty(base)
        plot(data_t, traces(:, base), 'LineWidth', 2, 'Color', 'k');
    end
    rois2 = rois;
    sidx2 = sidx;
    alias2 = alias;
end

for i = 1:length(rois2)
    plot(data_t, traces(:, rois2(sidx2(i))) - i * offset, 'LineWidth', 2, 'Color', cols(rois2(sidx2(i)), :));
    
    if length(alias2) >= i
        name = alias2{sidx2(i)};
    else
        name = num2str(rois2(sidx2(i)));
    end
    
    text(data_t(end) + 0.05 * data_t(end), -i * offset + 0.5, name,...
        'Color', cols(rois2(sidx2(i)),:), 'FontWeight', 'bold', 'FontSize', 18);
end

xlabel('Time (s)');
%xlim(ax_traces, [0 10]);
xlim(ax_traces, [0 1600]);


%%

axes(ax_im);

viz_im = icm.data(trial_idx).viz.im_data;
viz_x = icm.data(trial_idx).viz.im_x;
viz_y = icm.data(trial_idx).viz.im_y;

imagesc(viz_x, viz_y, viz_im);

axis(ax_im, 'equal');
axis(ax_im, 'xy');
set(ax_im, 'XColor', 'w', 'YColor', 'w', 'Box', 'off', 'XTick', [], 'YTick', []);

seg_ic_ids = icm.data(trial_idx).segment.segment_info.ic_ids;

for i = 1:length(rois)
    roi_idxs = find(seg_ic_ids == rois(i));
    
    if isempty(roi_idxs)
        % Then there wasn't an roi so just skip
        disp(['warning no roi for ic: ' num2str(i)]);
        continue;
    end
    oval = icm.data(trial_idx).segment.segment_info.rois(roi_idxs(1), :);
    
    
    if length(alias) >= i
        name = alias{i};
    else
        name = num2str(rois(i));
    end
    
    text(oval(1) + label_x_offsets, oval(2), name, 'Color', cols(rois(i),:), ...
        'FontWeight', 'bold', 'FontSize', 18, 'HorizontalAlignment', 'center');
end

if ~isempty(base)
    roi_idxs = find(seg_ic_ids == base);
    oval = icm.data(trial_idx).segment.segment_info.rois(roi_idxs(1), :);

    plot_oval(oval, 'Color', 'w', 'LineWidth', 3);
end
