classdef ImagingComputationalMicroscope < hgsetget
    % class ImageComponentParser: gui to analyze the component ...
    % decompositions of imaging data.
    %
    % @file: ImageComponentParser.m
    % @author: Paxon Frady
    % @created: 8/20/2013
    %
    % Copyright (C) 2013 E. Paxon Frady
    %
    % This program is free software: you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation, either version 3 of the License, or
    % (at your option) any later version.
    %
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    % GNU General Public License for more details.
    %
    % You should have received a copy of the GNU General Public License
    % along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    
    properties
        % gui properties
        h; % graphic object handles.
        gui; % settings for the gui.
        
        % hgsetget properties
        Position; % The size and position of the object
        Parent; % The parent of the object
        
        % object properties
        data; % Struct containing all the data for an ICP
        
        %im_data; % The original image data
        %rois; % Cell array containing the sets of rois
        %settings; % struct containing settings for each stage.
        %pp;  % struct containing preprocessing data
        %pca; % struct containing pca data
        %ica; % struct containing ica data
        %post; % struct containing postprocessing data
        %viz; % struct containing visualization data
        %cluster; % struct containing clustering data
        %stage; % Keeps track of which stage the analysis is in.
    end
    
    properties (Constant)
        % The stage values need to go in increasing order
        InitStage = 0;
        PreProcessingStage = 1;
        PcaStage = 2;
        IcaStage = 3;
        PostProcessingStage = 4;
    end
    
    events
        
    end
    
    methods
        %%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = ImagingComputationalMicroscope(parent, im_data)
            % self = ImageComponentParser(parent, im_data): parses the
            % components of imaging data.
            %
            % @param: parent the parent handle of the gui object. If no
            % parent is given a new figure will be created and used as the
            % parent.
            % @param: im_data MxNxt matrix of image data. Or cell array of
            % several trials of image data.
            % @return: self handle to the ImageComponentParser instance
            %
            
            if nargin < 1
                parent = [];
            end
            
            if nargin < 2
                self.init_data([],1,1);
            else
                self.init_data(im_data);
            end
            
            self = self.init_state();
            self = self.init_gui(parent);
            
            self.reset();
        end
        
        function self = init_state(self)
            % init_state: initializes the gui state variables.
            
            self.Position = [0 0 1200 850];
            
            self.gui.current_trial = 1;
            
            self.gui.MARGIN = 10;
            self.gui.CAX_H = 240;
            self.gui.BUTTON_H = 30;
            self.gui.CONTROL_H = 200;
            self.gui.PC_PANEL_ITEM_W = 20;
            self.gui.VIZ_SETTINGS_ITEM_W = 40;
            self.gui.VIZ_SETTINGS_ITEM_H = 20;
            
            self.gui.data_norm_frame = 20; % Data normalized to this frame
            
            self.gui.rotate_rate = 0.05;
            self.gui.rotate_angle_step = 2;
            self.gui.rotate_timer = timer('TimerFcn', @self.rotate_timer_cb, ...
                'ExecutionMode', 'fixedRate', ...
                'Period', self.gui.rotate_rate);
            
            self.gui.locked_components.xdata = [];
            self.gui.locked_components.ydata = [];
            self.gui.locked_components.handle_ids = [];
            self.gui.locked_colors = lines(7);
            
            self.default_settings();
        end
        
        function self = init_gui(self, parent)
            % init_gui: initializes the gui objects.
            %
            % @param: parent the parent handle of this object. Default is
            % to create a new figure. Use [] for default.
            
            if nargin < 2 || isempty(parent)
                % No parent given, then make a new figure as the parent.
                parent = figure();
                clf(parent);
                set(parent, 'Position', [100, 100, self.Position(3), self.Position(4)]);
            end
            
            self.h.parent = parent;
            
            % We must use a figure event notifier, which is attached to the
            % top-most figure. Go up until we get the figure.
            self.h.fh = self.h.parent;
            while ~strcmp(get(self.h.fh, 'Type'), 'figure')
                % Then the fh object is not a figure, so go up.
                self.h.fh = get(self.h.fh, 'Parent');
            end
            
            % Now fh is the parent figure. Set its event notifier.
            self.h.fen = FigureEventNotifier(self.h.fh);
            addlistener(self.h.fen, 'WindowKeyPress', @self.window_key_press_cb);
            set(self.h.fh, 'Toolbar', 'figure');
            
            %self.h.panel = uipanel(self.Parent, 'Units', 'pixels');
            self.h.panel = uiextras.BoxPanel('Parent', self.h.parent, ...
                'Title', 'Imaging Computational Microscope');
            
            % RoiEditor
            self.h.roi_editor = RoiEditor(self.h.fh, self.data(self.gui.current_trial).im_data);
            %self.h.roi_editor.is_editing_enabled = false;
            
            addlistener(self.h.roi_editor, 'SelectionChanged', @self.re_selection_changed_cb);
            addlistener(self.h.roi_editor, 'NewRois', @self.re_new_rois_cb);
            addlistener(self.h.roi_editor, 'AlteredRois', @self.re_altered_rois_cb);
            addlistener(self.h.roi_editor, 'DeletedRois', @self.re_deleted_rois_cb);
            
            %%% Ok I'm just ignoring trying to do this now. It keeps
            %%% messing up, argh.
            %addlistener(self.h.roi_editor, 'LevelsChanged', @self.re_levels_changed_cb);
            %%%
            addlistener(self.h.roi_editor, 'FrameChanged', @self.re_frame_changed_cb);
            
            % Roi Management
            self.h.roi_listbox = uicontrol('Style', 'listbox', ...
                'String', self.data(1).roi_names, 'Min', 1, 'Max', 1, 'Callback', @self.roi_listbox_cb);
            self.h.add_rois_button = uicontrol('Style', 'pushbutton', ...
                'String', '+', 'Callback', @self.add_rois_button_cb);
            self.h.delete_rois_button = uicontrol('Style', 'pushbutton', ...
                'String', '-', 'Callback', @self.delete_rois_button_cb);
            
            % Trial Management
            self.h.trial_listbox = uicontrol('Style', 'listbox', ...
                'String', {'loading...'}, 'Min', 1, 'Max', 1, 'Callback', @self.trial_listbox_cb);
            self.h.add_trial_button = uicontrol('Style', 'pushbutton', ...
                'String', '+', 'Callback', @self.add_trial_button_cb);
            self.h.delete_trial_button = uicontrol('Style', 'pushbutton', ...
                'String', '-', 'Callback', @self.delete_trial_button_cb);
            
            % Component axes
            self.h.component_axes = axes('Units', 'pixels');
            self.h.lock_component_button = uicontrol('Style', 'pushbutton',...
                'String', 'Lock', 'Callback', @self.lock_component_button_cb);
            self.h.clear_locked_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Clear', 'Callback', @self.clear_locked_button_cb);
            
            % Data axes
            self.h.data_axes = axes('Units', 'pixels');
            
            self.h.stage_tab_panel = uiextras.TabPanel('Callback', @self.stage_tab_panel_cb);
            self.h.data_tab = uiextras.Panel('Parent', self.h.stage_tab_panel);
            self.h.pp_tab = uiextras.Panel('Parent', self.h.stage_tab_panel);
            self.h.pca_tab = uiextras.Panel('Parent', self.h.stage_tab_panel);
            self.h.ica_tab = uiextras.Panel('Parent', self.h.stage_tab_panel);
            self.h.sc_tab = uiextras.Panel('Parent', self.h.stage_tab_panel);
            self.h.viz_tab = uiextras.Panel('Parent', self.h.stage_tab_panel);
            self.h.stage_tab_panel.TabNames = {'Data', 'Pre-Processing', 'PCA', 'ICA', 'Segment', 'Visualize'};
            self.h.stage_tab_panel.SelectedChild = self.gui.d(1).display;
            
            self.h.stage_status = uicontrol('Style', 'text', 'String', '...');
            
            % Data tab
            self.h.reset_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Reset', 'Callback', @self.reset_button_cb);
            
            self.h.concat_trials_toggle = uicontrol('Style', 'togglebutton', ...
                'String', 'Concatenate Trials', 'Callback', @self.concat_trials_toggle_cb);
            
            % PP tab
            self.h.motion_correct_button = uicontrol('Style', 'pushbutton',...
                'String', 'Motion Correct', 'Callback', @self.motion_correct_button_cb);
            self.h.preprocess_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Pre Process', 'Callback', @self.preprocess_button_cb);
            self.h.wavelets_check = uicontrol('Style', 'checkbox', 'Value', 0, ...
                'String', 'Use Wavelets', 'Callback', @self.wavelets_check_cb);
            
            self.h.pp_smooth_label = uicontrol('Style', 'text', 'String', 'Smooth Window:', 'TooltipString', ...
                'Sets dimensions of smooth window - MxNxT', ...
                'HorizontalAlignment', 'left');
            self.h.pp_down_label = uicontrol('Style', 'text', 'String', 'Down Sampling:', 'TooltipString', ...
                'Sets the down sampling in each dimensoin - MxNxT', ...
                'HorizontalAlignment', 'left');
            
            self.h.pp_M_label = uicontrol('Style', 'text', 'String', 'M', 'TooltipString', ...
                'M corresponds to the rows of the image (vertical)');
            self.h.pp_smooth_M = uicontrol('Style', 'edit', 'String','1', 'Callback', @self.pp_settings_cb);
            self.h.pp_down_M = uicontrol('Style', 'edit', 'String','1', 'Callback', @self.pp_settings_cb);             
            self.h.pp_N_label = uicontrol('Style', 'text', 'String', 'N', 'TooltipString', ...
                'N corresponds to the columns of th eimage (horizontal)');
            self.h.pp_smooth_N = uicontrol('Style', 'edit', 'String', '1', 'Callback', @self.pp_settings_cb);
            self.h.pp_down_N = uicontrol('Style', 'edit', 'String', '1', 'Callback', @self.pp_settings_cb);            
            self.h.pp_T_label = uicontrol('Style', 'text', 'String', 'T', 'TooltipString', ...
                'T corresponds to the frames (depth)');
            self.h.pp_smooth_T = uicontrol('Style', 'edit', 'String', '1', 'Callback', @self.pp_settings_cb); 
            self.h.pp_down_T = uicontrol('Style', 'edit', 'String', '1', 'Callback', @self.pp_settings_cb);            
            
            % PCA tab
            self.h.runpca_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Run PCA', 'Callback', @self.runpca_button_cb);
            
            % ICA tab
            self.h.runica_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Run ICA', 'Callback', @self.runica_button_cb);
            self.h.which_pcs_label = uicontrol('Style', 'text', 'String', 'PCs:');
            self.h.which_pcs_edit = uicontrol('Style', 'edit', 'Callback', @self.which_pcs_edit_cb);
            self.h.ic_show_viz_check = uicontrol('Style', 'checkbox', 'Value', 1, ...
                'String', 'Show Viz', 'Callback', @self.ic_show_viz_check_cb);
            
            self.h.post_poly_label = uicontrol('Style', 'text', 'String', 'Poly:');
            self.h.post_poly_slider = uicontrol('Style', 'slider', 'Callback', @self.post_poly_slider_cb, ...
                'Min', 0, 'Max', 20, 'SliderStep', [0.05, 0.2], 'Value', 0);
            self.h.post_poly_edit = uicontrol('Style', 'edit', 'Callback', @self.post_poly_edit_cb);
            self.h.post_smooth_label = uicontrol('Style', 'text', 'String', 'Smooth:');
            self.h.post_smooth_slider = uicontrol('Style', 'slider', 'Callback', @self.post_smooth_slider_cb,...
                'Min', 0, 'Max', 20, 'SliderStep', [0.05, 0.2], 'Value', 0);
            self.h.post_smooth_edit = uicontrol('Style', 'edit', 'Callback', @self.post_smooth_edit_cb);
            self.h.post_remove_label = uicontrol('Style', 'text', 'String', 'Remove:');
            self.h.post_remove_edit = uicontrol('Style', 'edit', 'Callback', @self.pp_remove_edit_cb);
            
            self.h.post_run_pp_button = uicontrol('Style', 'pushbutton', 'String', 'Run Post', ...
                'Callback', @self.pp_run_pp_button_cb);
            self.h.post_clear_pp_button = uicontrol('Style', 'pushbutton', 'String', 'Clear Post', ...
                'Callback', @self.pp_clear_pp_button_cb);
            
            % Visualization/Cluster tab
            self.h.update_viz_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Update Viz', 'Callback', @self.update_viz_button_cb);
            self.h.clear_viz_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Clear Viz', 'Callback', @self.clear_viz_button_cb);
            
            self.h.map_pow_label = uicontrol('Style', 'text', 'String', 'Map^:');
            self.h.map_pow_slider = uicontrol('Style', 'slider', 'Callback', @self.viz_settings_cb, ...
                'Min', 0, 'Max', 5, 'SliderStep', [0.02, 0.1]);
            self.h.map_pow_indicator = uicontrol('Style', 'text', 'String', '0');
            self.h.color_pow_label = uicontrol('Style', 'text', 'String', 'Color^:');
            self.h.color_pow_slider = uicontrol('Style', 'slider', 'Callback', @self.viz_settings_cb, ...
                'Min', 0, 'Max', 5, 'SliderStep', [0.02 0.1]);
            self.h.color_pow_indicator = uicontrol('Style', 'text', 'String', '0');
            self.h.alpha_label = uicontrol('Style', 'text', 'String', 'Alpha:');
            self.h.alpha_slider = uicontrol('Style', 'slider', 'Callback', @self.viz_settings_cb, ...
                'Min', 0, 'Max', 1, 'SliderStep', [0.02, 0.1]);
            self.h.alpha_indicator = uicontrol('Style', 'text', 'String', '0');
            
            % These are buttons for clustering -- this is typically done
            % using the visualizations, so this goes in viz tab
            self.h.estimate_clusters_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Estimate Clusters', 'Callback', @self.estimate_clusters_cb);
            self.h.set_cluster_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Set Cluster', 'Callback', @self.set_cluster_button_cb);
            self.h.uncluster_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Uncluster', 'Callback', @self.uncluster_button_cb);
            
            
            % Segment tab
            self.h.segment_ics_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Segment ICs', 'Callback', @self.segment_ics_cb);
            self.h.down_size_label = uicontrol('Style', 'text', 'String', 'Down:');
            self.h.down_size_slider = uicontrol('Style', 'slider', 'Callback', @self.down_size_slider_cb, ...
                'Min', 1, 'Max', 10);
            self.h.down_size_indicator = uicontrol('Style', 'edit', 'Callback', @self.down_size_indicator_cb);
            self.h.thresh_label = uicontrol('Style', 'text', 'String', 'Thresh:');
            self.h.thresh_slider = uicontrol('Style', 'slider', 'Callback', @self.thresh_slider_cb);
            self.h.thresh_indicator = uicontrol('Style', 'edit', 'Callback', @self.thresh_indicator_cb);
            
            self.h.max_corr_thresh_button = uicontrol('Style', 'pushbutton', ...
                'String', 'Max Corr Thresh', 'Callback', @self.max_corr_thresh_button_cb);
            
            set(self.h.down_size_slider, 'Min', -4, 'Max', 4);
            set(self.h.down_size_indicator, 'String', '0');
            set(self.h.thresh_slider, 'Min', 0, 'Max', 10, 'SliderStep', [0.01, 0.1]);
            set(self.h.thresh_indicator, 'String', '0');
            
            % Viewers and visualization tools
            self.h.pc_pixel_viewer = HighDViewer(self.h.fh);
            self.h.pc_ica_viewer = HighDViewer(self.h.fh);
            self.h.pc_ica_viewer.gui.fast_mode = 0; % We want colors on this one
            self.h.ica_coherence = CoherenceGui(self.h.fh);
            
            self.h.pc_pixel_viewer.gui.fast_mode = 1;
            self.h.pc_pixel_viewer.gui.text_mode = 0;
            
            self.h.pc_ica_viewer.gui.fast_mode = 0;
            self.h.pc_ica_viewer.gui.text_mode = 1;
            
            self.h.ica_coherence.gui.fast_mode = 0;
            self.h.ica_coherence.gui.text_mode = 1;
            
            addlistener(self.h.pc_ica_viewer, 'DataClicked', @self.data_clicked_cb);
            addlistener(self.h.ica_coherence, 'DataClicked', @self.data_clicked_cb);
            
            addlistener(self.h.pc_ica_viewer, 'DimensionsChanged', @self.update_viz_button_cb);
            addlistener(self.h.ica_coherence, 'BaseChanged', @self.update_viz_button_cb);
            addlistener(self.h.ica_coherence, 'SigLevelChanged', @self.update_viz_button_cb);
            addlistener(self.h.ica_coherence, 'FreqChanged', @self.update_viz_button_cb);
            
            self.h.viewer_tab_panel = uiextras.TabPanel('Callback', @self.viewer_tab_panel_cb);
            self.h.viewer_pixel_tab = uiextras.Panel('Parent', self.h.viewer_tab_panel);
            self.h.viewer_pca_tab = uiextras.Panel('Parent', self.h.viewer_tab_panel);
            self.h.viewer_coherence_tab = uiextras.Panel('Parent', self.h.viewer_tab_panel);
            
            self.h.viewer_tab_panel.TabNames = {'Pixels', 'PCA', 'Coherence'};
            self.h.viewer_tab_panel.SelectedChild = 1;
            
            % Menu
            self.h.main_menu = uimenu(self.h.fh, 'Label', 'ICM');
            self.h.load_image_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Load Data', 'Callback', @self.load_image_cb);
            
            self.h.load_session_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Load Session', 'Callback', @self.load_session_cb, ...
                'Separator', 'on');
            self.h.save_session_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Save Session', 'Callback', @self.save_session_cb);
            
            self.h.load_settings_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Load Settings', 'Callback', @self.load_settings_cb);
            set(self.h.load_settings_item, 'Separator', 'on');
            self.h.save_settings_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Save Settings', 'Callback', @self.save_settings_cb);
            self.h.edit_settings_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Edit Settings');
            self.h.edit_preprocessing_item = uimenu('Parent', self.h.edit_settings_item, ...
                'Label', 'Preprocessing', 'Callback', @self.edit_preprocessing_cb);
            self.h.edit_pca_item = uimenu('Parent', self.h.edit_settings_item, ...
                'Label', 'PCA', 'Callback', @self.edit_pca_cb);
            self.h.edit_ica_item = uimenu('Parent', self.h.edit_settings_item, ...
                'Label', 'ICA', 'Callback', @self.edit_ica_cb);
            
            self.h.load_rois_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Load ROIs', 'Callback', @self.load_rois_cb,...
                'Separator', 'on');
            self.h.save_rois_item = uimenu('Parent', self.h.main_menu, ...
                'Label', 'Save ROIs', 'Callback', @self.save_rois_cb);
            
            
            %self = self.reset_layout();
            self = self.uiextras_layout();
        end
        
        function self = uiextras_layout(self)
            % uiextras_layout: Sets the layout of all of the gui components.
            
            % Ok, I'm going to do this with the layouts, and reset the
            % parents here.
            disp('uiextras_layout');
            
            % Component axes elements
            self.h.component_panel = uiextras.BoxPanel('Title', 'Component Plot');
            self.h.component_lock_vbox = uiextras.VBox();
            self.h.lock_button_hbox = uiextras.HButtonBox();
            self.h.component_pc3_vbox = uiextras.VBoxFlex();
            
            % Data axes elements
            self.h.data_panel = uiextras.BoxPanel('Title', 'Data Plot');
            
            % Stage elements
            %self.h.stage_button_hbox = uiextras.HButtonBox();
            self.h.editor_button_vbox = uiextras.VBox();
            
            self.h.roi_stage_hbox = uiextras.HBox();
            self.h.roi_control_vbox = uiextras.VBox();
            self.h.roi_button_hbox = uiextras.HButtonBox();
            self.h.trial_control_vbox = uiextras.VBox();
            self.h.trial_button_hbox = uiextras.HButtonBox();
            
            % Tab layout elements
            self.h.pp_settings_panel = uiextras.BoxPanel('Title', 'Pre-Processing Settings');
            self.h.pp_main_vbox = uiextras.VBox();
            self.h.pp_settings_grid = uiextras.Grid('Padding', 10, 'Spacing', 5);
            self.h.pp_button_hbox = uiextras.HButtonBox();
            
            self.h.pca_button_hbox = uiextras.HButtonBox();
            
            self.h.ica_main_hbox = uiextras.HBox();
            self.h.ica_settings_panel = uiextras.BoxPanel('Title', 'ICA Settings');
            self.h.ica_postprocessing_panel = uiextras.BoxPanel('Title', 'ICA Post-Processing');
            self.h.ica_settings_vbox = uiextras.VButtonBox('ButtonSize', [150 40]);
            self.h.ica_which_pcs_hbox = uiextras.HBox('Padding', 10, 'Spacing', 5);
            self.h.ica_button_vbox = uiextras.VButtonBox();
            self.h.ica_pp_vbox = uiextras.VBox();
            self.h.ica_pp_remove_hbox = uiextras.HBox('Padding', 10, 'Spacing', 5);
            self.h.ica_pp_filter_grid = uiextras.Grid('Padding', 10, 'Spacing', 5);
            self.h.ica_pp_control_vbox = uiextras.VButtonBox();
            
            self.h.viz_main_hbox = uiextras.HBox();
            %self.h.viz_button_hbox = uiextras.HButtonBox();
            self.h.viz_settings_panel = uiextras.BoxPanel('Title', 'Visualization Settings');
            self.h.viz_settings_vbox = uiextras.VBox();
            self.h.viz_settings_grid = uiextras.Grid('Padding', 10, 'Spacing', 5);
            self.h.viz_button_vbox = uiextras.VButtonBox();
            self.h.viz_cluster_panel = uiextras.BoxPanel('Title', 'Cluster');
            self.h.viz_cluster_vbox = uiextras.VButtonBox();
            
            self.h.sc_main_hbox = uiextras.HBox();
            self.h.sc_segment_panel = uiextras.BoxPanel('Title', 'Segmentation');
            self.h.sc_segment_vbox = uiextras.VBox();
            self.h.sc_segment_grid = uiextras.Grid('Padding', 10, 'Spacing', 5);
            self.h.sc_segment_button_hbox = uiextras.HButtonBox();
            %self.h.sc_down_size_hbox = uiextras.HBox('Padding', 10, 'Spacing', 5);
            %self.h.sc_thresh_hbox = uiextras.HBox('Padding', 10, 'Spacing', 5);
            
            self.h.data_button_hbox = uiextras.HButtonBox();
            
            self.h.main_hbox = uiextras.HBoxFlex();
            
            % Top-level hierarchy
            set(self.h.main_hbox, 'Parent', self.h.panel);
            set(self.h.editor_button_vbox, 'Parent', self.h.main_hbox);
            set(self.h.component_pc3_vbox, 'Parent', self.h.main_hbox);
            
            % Button, ROI Editor hierarchy
            set(self.h.roi_editor, 'Parent', self.h.editor_button_vbox);
            set(self.h.roi_stage_hbox, 'Parent', self.h.editor_button_vbox);
            set(self.h.stage_status, 'Parent', self.h.editor_button_vbox.double());
            
            set(self.h.trial_control_vbox, 'Parent', self.h.roi_stage_hbox);
            set(self.h.roi_control_vbox, 'Parent', self.h.roi_stage_hbox);
            set(self.h.stage_tab_panel, 'Parent', self.h.roi_stage_hbox);
            
            % Trial list and buttons
            set(self.h.trial_listbox, 'Parent', self.h.trial_control_vbox.double());
            set(self.h.trial_button_hbox, 'Parent', self.h.trial_control_vbox.double());
            set(self.h.add_trial_button, 'Parent', self.h.trial_button_hbox.double());
            set(self.h.delete_trial_button, 'Parent', self.h.trial_button_hbox.double());
            
            % Roi list and buttons
            set(self.h.roi_listbox, 'Parent', self.h.roi_control_vbox.double());
            set(self.h.roi_button_hbox, 'Parent', self.h.roi_control_vbox);
            set(self.h.add_rois_button, 'Parent', self.h.roi_button_hbox.double());
            set(self.h.delete_rois_button, 'Parent', self.h.roi_button_hbox.double());
            
            % Data tab
            set(self.h.data_button_hbox, 'Parent', self.h.data_tab);
            set(self.h.reset_button, 'Parent', self.h.data_button_hbox.double());
            set(self.h.motion_correct_button, 'Parent', self.h.data_button_hbox.double());
            set(self.h.concat_trials_toggle, 'Parent', self.h.data_button_hbox.double());
            
            % PP tab
            set(self.h.pp_settings_panel, 'Parent', self.h.pp_tab);
            set(self.h.pp_main_vbox, 'Parent', self.h.pp_settings_panel);
            set(self.h.pp_settings_grid, 'Parent', self.h.pp_main_vbox);
            set(self.h.pp_button_hbox, 'Parent', self.h.pp_main_vbox);
            
            self.h.pp_empty = uiextras.Empty('Parent', self.h.pp_settings_grid);
            set(self.h.pp_smooth_label, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_down_label, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_M_label, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_smooth_M, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_down_M, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_N_label, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_smooth_N, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_down_N, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_T_label, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_smooth_T, 'Parent', self.h.pp_settings_grid.double());
            set(self.h.pp_down_T, 'Parent', self.h.pp_settings_grid.double());
            
            set(self.h.wavelets_check, 'Parent', self.h.pp_button_hbox.double());
            set(self.h.preprocess_button, 'Parent', self.h.pp_button_hbox.double());
            
            % PCA tab
            set(self.h.pca_button_hbox, 'Parent', self.h.pca_tab);
            set(self.h.runpca_button, 'Parent', self.h.pca_button_hbox.double());
            
            % ICA tab
            set(self.h.ica_main_hbox, 'Parent', self.h.ica_tab);
            set(self.h.ica_settings_panel, 'Parent', self.h.ica_main_hbox);
            set(self.h.ica_postprocessing_panel, 'Parent', self.h.ica_main_hbox);
            %set(self.h.ica_button_vbox, 'Parent', self.h.ica_main_hbox);
            set(self.h.ica_settings_vbox, 'Parent', self.h.ica_settings_panel);
            set(self.h.ica_which_pcs_hbox, 'Parent', self.h.ica_settings_vbox);
            set(self.h.ica_button_vbox, 'Parent', self.h.ica_settings_vbox);
            set(self.h.runica_button, 'Parent', self.h.ica_button_vbox.double());
            set(self.h.ic_show_viz_check, 'Parent', self.h.ica_button_vbox.double());
            %set(self.h.runica_button, 'Parent', self.h.ica_settings_vbox.double());
            %set(self.h.ic_show_viz_check, 'Parent', self.h.ica_settings_vbox.double());
            
            set(self.h.which_pcs_label, 'Parent', self.h.ica_which_pcs_hbox.double());
            set(self.h.which_pcs_edit, 'Parent', self.h.ica_which_pcs_hbox.double());     
            %set(self.h.calc_rois_button, 'Parent', self.h.ica_button_vbox.double());
            
            set(self.h.ica_pp_vbox, 'Parent', self.h.ica_postprocessing_panel);
            set(self.h.ica_pp_remove_hbox, 'Parent', self.h.ica_pp_vbox);
            set(self.h.ica_pp_filter_grid, 'Parent', self.h.ica_pp_vbox);
            set(self.h.ica_pp_control_vbox, 'Parent', self.h.ica_pp_vbox);
            set(self.h.post_remove_label, 'Parent', self.h.ica_pp_remove_hbox.double());
            set(self.h.post_remove_edit, 'Parent', self.h.ica_pp_remove_hbox.double());
            set(self.h.post_poly_label, 'Parent', self.h.ica_pp_filter_grid.double());
            set(self.h.post_smooth_label, 'Parent', self.h.ica_pp_filter_grid.double());
            set(self.h.post_poly_slider, 'Parent', self.h.ica_pp_filter_grid.double());
            set(self.h.post_smooth_slider, 'Parent', self.h.ica_pp_filter_grid.double());
            set(self.h.post_poly_edit, 'Parent', self.h.ica_pp_filter_grid.double());
            set(self.h.post_smooth_edit, 'Parent', self.h.ica_pp_filter_grid.double());
            set(self.h.post_run_pp_button, 'Parent', self.h.ica_pp_control_vbox.double());
            set(self.h.post_clear_pp_button, 'Parent', self.h.ica_pp_control_vbox.double());
            
            % Viz tab
            set(self.h.viz_main_hbox, 'Parent', self.h.viz_tab);
            set(self.h.viz_settings_panel, 'Parent', self.h.viz_main_hbox);
            set(self.h.viz_settings_vbox, 'Parent', self.h.viz_settings_panel)
            set(self.h.viz_settings_grid, 'Parent', self.h.viz_settings_vbox);
            set(self.h.viz_button_vbox, 'Parent', self.h.viz_settings_vbox);
            set(self.h.viz_cluster_panel, 'Parent', self.h.viz_main_hbox);
            set(self.h.viz_cluster_vbox, 'Parent', self.h.viz_cluster_panel);

            set(self.h.map_pow_label, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.color_pow_label, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.alpha_label, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.map_pow_slider, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.color_pow_slider, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.alpha_slider, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.map_pow_indicator, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.color_pow_indicator, 'Parent', self.h.viz_settings_grid.double());
            set(self.h.alpha_indicator, 'Parent', self.h.viz_settings_grid.double());
            
            set(self.h.update_viz_button, 'Parent', self.h.viz_button_vbox.double());
            set(self.h.clear_viz_button, 'Parent', self.h.viz_button_vbox.double());
            
            set(self.h.set_cluster_button, 'Parent', self.h.viz_cluster_vbox.double());
            set(self.h.uncluster_button, 'Parent', self.h.viz_cluster_vbox.double());
            set(self.h.estimate_clusters_button, 'Parent', self.h.viz_cluster_vbox.double());
            
            % Segment tab
            set(self.h.sc_main_hbox, 'Parent', self.h.sc_tab);
            set(self.h.sc_segment_panel, 'Parent', self.h.sc_main_hbox);
            set(self.h.sc_segment_vbox, 'Parent', self.h.sc_segment_panel);
            
            set(self.h.sc_segment_grid, 'Parent', self.h.sc_segment_vbox);
            set(self.h.sc_segment_button_hbox, 'Parent', self.h.sc_segment_vbox);
            
            set(self.h.down_size_label, 'Parent', self.h.sc_segment_grid.double());
            set(self.h.thresh_label, 'Parent', self.h.sc_segment_grid.double());
            set(self.h.down_size_slider, 'Parent', self.h.sc_segment_grid.double());
            set(self.h.thresh_slider, 'Parent', self.h.sc_segment_grid.double());
            set(self.h.down_size_indicator, 'Parent', self.h.sc_segment_grid.double());
            set(self.h.thresh_indicator, 'Parent', self.h.sc_segment_grid.double());
            
            set(self.h.max_corr_thresh_button, 'Parent', self.h.sc_segment_button_hbox.double());
            set(self.h.segment_ics_button, 'Parent', self.h.sc_segment_button_hbox.double());
            
            % Component axis hierarchy
            set(self.h.data_panel, 'Parent', self.h.component_pc3_vbox);
            set(self.h.component_panel, 'Parent', self.h.component_pc3_vbox);
            set(self.h.viewer_tab_panel, 'Parent', self.h.component_pc3_vbox);
            %set(self.h.pc3_main_panel, 'Parent', self.h.component_pc3_vbox);
            
            set(self.h.component_lock_vbox, 'Parent', self.h.component_panel);
            set(self.h.component_axes, 'Parent', self.h.component_lock_vbox.double());
            set(self.h.lock_button_hbox, 'Parent', self.h.component_lock_vbox);
            set(self.h.lock_component_button, 'Parent', self.h.lock_button_hbox.double());
            set(self.h.clear_locked_button, 'Parent', self.h.lock_button_hbox.double());
            
            set(self.h.data_axes, 'Parent', self.h.data_panel.double());
            
            % 3D plot tabs
            set(self.h.pc_pixel_viewer, 'Parent', self.h.viewer_pixel_tab);
            set(self.h.pc_ica_viewer, 'Parent', self.h.viewer_pca_tab);
            set(self.h.ica_coherence, 'Parent', self.h.viewer_coherence_tab);
            
            % Now set all of the sizes
            set(self.h.component_pc3_vbox, 'Sizes', [-1, -1, -1]);
            
            set(self.h.component_lock_vbox, 'Sizes', [-1, self.gui.BUTTON_H]);
            
            set(self.h.editor_button_vbox, 'Sizes', [-1, self.gui.CONTROL_H, self.gui.BUTTON_H]);
            set(self.h.roi_stage_hbox, 'Sizes', [-1, -1, -3]);
            set(self.h.trial_control_vbox, 'Sizes', [-1, self.gui.BUTTON_H]);
            set(self.h.roi_control_vbox, 'Sizes', [-1, self.gui.BUTTON_H]);
            
            set(self.h.main_hbox, 'Sizes', [-1 -1]);
            
            set(self.h.viz_settings_grid, ...
                'ColumnSizes', [self.gui.VIZ_SETTINGS_ITEM_W, -1, self.gui.VIZ_SETTINGS_ITEM_W], ...
                'RowSizes', [self.gui.VIZ_SETTINGS_ITEM_H, self.gui.VIZ_SETTINGS_ITEM_H, self.gui.VIZ_SETTINGS_ITEM_H]);
            
            set(self.h.sc_segment_grid, ...
                'ColumnSizes', [self.gui.VIZ_SETTINGS_ITEM_W, -1, self.gui.VIZ_SETTINGS_ITEM_W], ...
                'RowSizes', [self.gui.VIZ_SETTINGS_ITEM_H, self.gui.VIZ_SETTINGS_ITEM_H]);
            
            %set(self.h.ica_pp_remove_hbox, 'Sizes', [self.gui.VIZ_SETTINGS_ITEM_W, -1]);
            set(self.h.ica_pp_vbox, 'Sizes', [2*self.gui.VIZ_SETTINGS_ITEM_H, -1, -1]);
            set(self.h.ica_pp_filter_grid, ...
                'ColumnSizes', [self.gui.VIZ_SETTINGS_ITEM_W, -1, self.gui.VIZ_SETTINGS_ITEM_W], ...
                'RowSizes', [self.gui.VIZ_SETTINGS_ITEM_H, self.gui.VIZ_SETTINGS_ITEM_H]);
            
            set(self.h.pp_settings_grid, 'ColumnSizes', [-1, 30, 30, 30], 'RowSizes', [30, 30, 30]);
            set(self.h.pp_main_vbox, 'Sizes', [-1, 30]);
            
            set(self.Parent, 'Position', [100, 100, self.Position(3), self.Position(4)]);
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function window_key_press_cb(self, source_h, eventdata)
            disp('window_keypress_cb');
        end
        
        function reset_button_cb(self, source_h, eventdata)
            disp('reset_button_cb');
            self.reset();
        end
        
        function motion_correct_button_cb(self, source_h, eventdata)
            disp('motion_correct_button_cb');
            self.run_motion_correction();
        end
        
        function preprocess_button_cb(self, source_h, eventdata)
            disp('preprocess_button_cb');
            
            self.run_preprocessing();
        end
        
        function wavelets_check_cb(self, source_h, eventdata)
            disp('wavelets_check_cb');
            self.set_use_wavelets(get(self.h.wavelets_check, 'Value'));
        end
        
        function runpca_button_cb(self, source_h, eventdata)
            disp('runpca_button_cb');
            
            self.run_pca();
        end
        
        function runica_button_cb(self, source_h, eventdata)
            disp('runica_button_cb');
            
            self.run_ica();
        end
        
        function segment_ics_cb(self, source_h, eventdata)
            disp('segment_ics_cb');
            
            self.run_segmentation();
        end
        
        function update_viz_button_cb(self, source_h, eventdata)
            self.run_visualization();
        end
        
        function clear_viz_button_cb(self, source_h, eventdata)
            disp('clear_viz_button_cb');
            self.clear_visualization();
            self.update();
        end
        
        function estimate_clusters_cb(self, source_h, eventdata)
            self.estimate_clusters();
        end
        
        function set_cluster_button_cb(self, source_h, eventdata)
            disp('set_cluster_button_cb');
            
            self.set_cluster();
        end
        
        function uncluster_button_cb(self, source_h, eventdata)
            disp('uncluster_button_cb');
            
            self.uncluster();
        end
        
        function stage_tab_panel_cb(self, source_h, eventdata)
            disp('stage_tab_panel_cb');
            
            self.gui.d(self.gui.current_trial).display = eventdata.SelectedChild;
            self.update();
        end
        
        function viewer_tab_panel_cb(self, source_h, eventdata)
            disp('viewer_tab_panel_cb');
        end
        
        function x_popup_cb(self, sh, ed)
            % x_popup_cb: callback for when x popup is changed.
            
            v = get(sh, 'Value');
            self.gui.d(self.gui.current_trial).x_pc = v;
            
            % Now make sure y, z aren't x.
            if self.gui.d(self.gui.current_trial).y_pc == self.gui.d(self.gui.current_trial).x_pc
                % Then y is equal to x
                for i = 1:10
                    if i ~= self.gui.d(self.gui.current_trial).x_pc && i ~= self.gui.d(self.gui.current_trial).z_pc
                        self.gui.d(self.gui.current_trial).y_pc = i;
                        break;
                    end
                end
            end
            if self.gui.d(self.gui.current_trial).z_pc == self.gui.d(self.gui.current_trial).x_pc
                % Then z is equal to x
                for i = 1:10
                    if i ~= self.gui.d(self.gui.current_trial).x_pc && i ~= self.gui.d(self.gui.current_trial).y_pc
                        self.gui.d(self.gui.current_trial).z_pc = i;
                        break;
                    end
                end
            end
            self.update();
        end
        
        function y_popup_cb(self, sh, ed)
            % y_popup_cb: callback for when y popup is changed.
            
            v = get(sh, 'Value');
            self.gui.d(self.gui.current_trial).y_pc = v;
            
            % Now make sure x, z aren't y.
            if self.gui.d(self.gui.current_trial).x_pc == self.gui.d(self.gui.current_trial).y_pc
                % Then x is equal to y
                for i = 1:10
                    if i ~= self.gui.d(self.gui.current_trial).y_pc && i ~= self.gui.d(self.gui.current_trial).z_pc
                        self.gui.d(self.gui.current_trial).x_pc = i;
                        break;
                    end
                end
            end
            if self.gui.d(self.gui.current_trial).z_pc == self.gui.d(self.gui.current_trial).y_pc
                % Then z is equal to y
                for i = 1:10
                    if i ~= self.gui.d(self.gui.current_trial).y_pc && i ~= self.gui.d(self.gui.current_trial).x_pc
                        self.gui.d(self.gui.current_trial).z_pc = i;
                        break;
                    end
                end
            end
            self.update();
        end
        
        function z_popup_cb(self, sh, ed)
            % z_popup_cb: callback for when z popup is changed.
            
            v = get(sh, 'Value');
            self.gui.d(self.gui.current_trial).z_pc = v;
            
            % Now make sure y, x aren't z.
            if self.gui.d(self.gui.current_trial).y_pc == self.gui.d(self.gui.current_trial).z_pc
                % Then y is equal to z
                for i = 1:10
                    if i ~= self.gui.d(self.gui.current_trial).x_pc && i ~= self.gui.d(self.gui.current_trial).z_pc
                        self.gui.d(self.gui.current_trial).y_pc = i;
                        break;
                    end
                end
            end
            if self.gui.d(self.gui.current_trial).x_pc == self.gui.d(self.gui.current_trial).z_pc
                % Then x is equal to z
                for i = 1:10
                    if i ~= self.gui.d(self.gui.current_trial).z_pc && i ~= self.gui.d(self.gui.current_trial).y_pc
                        self.gui.d(self.gui.current_trial).x_pc = i;
                        break;
                    end
                end
            end
            self.update();
        end
        
        function xy_button_cb(self, sh, ed)
            % xy_button_cb: callback that rotates pc axes to show xy.
            view(self.h.pc3_axes, [0 90]);
        end
        
        function yz_button_cb(self, sh, ed)
            % yz_button_cb: callback that rotates pc axes to show yz.
            view(self.h.pc3_axes, [90 0]);
        end
        
        function zx_button_cb(self, sh, ed)
            % zx_button_cb: callback that rotates pc axes to show zx.
            view(self.h.pc3_axes, [0 0]);
        end
        
        function rotate_toggle_cb(self, sh, ed)
            v = get(sh, 'Value');
            
            if v
                start(self.gui.rotate_timer);
            else
                stop(self.gui.rotate_timer);
            end
        end
        
        function rotate_timer_cb(self, sh, ed)
            [az, el] = view(self.h.pc3_axes);
            view(self.h.pc3_axes, az + self.gui.rotate_angle_step, el);
        end
        
        function re_selection_changed_cb(self, source_h, eventdata)
            disp('re_selection_changed_cb');
            self.update();
        end
        
        function re_new_rois_cb(self, source_h, eventdata)
            disp('re_new_rois_cb');
            self.update_current_roi_set();
            self.update();
        end
        
        function re_altered_rois_cb(self, source_h, eventdata)
            disp('re_altered_rois_cb');
            self.update_current_roi_set();
            self.update();
        end
        
        function re_deleted_rois_cb(self, source_h, eventdata)
            disp('re_deleted_rois_cb');
            self.update_current_roi_set();
            self.update();
        end
        
        function re_frame_changed_cb(self, source_h, eventdata)
            disp('re_frame_changed_cb');
            f = self.h.roi_editor.current_frame;
            
            self.gui.d(self.gui.current_trial).current_frame(self.gui.d(self.gui.current_trial).display) = f;
            self.update();
        end
        
        function re_levels_changed_cb(self, source_h, eventdata)
            disp('re_levels_changed_cb');
            ld = self.gui.d(self.gui.current_trial).last_display;
            
            if ld > 0
                self.gui.d(self.gui.current_trial).levels(:,:,ld) = self.h.roi_editor.get_levels();
            end
        end
        
        function load_settings_cb(self, source_h, eventdata)
            disp('load_settings_cb');
        end
        
        function save_settings_cb(self, source_h, eventdata)
            disp('save_settings_cb');
        end
        
        function edit_preprocessing_cb(self, source_h, eventdata)
            disp('edit_preprocessing_cb');
            
            self.edit_preprocessing_settings();
        end
        
        function edit_pca_cb(self, source_h, eventdata)
            disp('edit_pca_cb');
        end
        
        function edit_ica_cb(self, source_h, eventdata)
            disp('edit_ica_cb');
        end
        
        function pp_settings_cb(self, source_h, eventdata)
            disp('pp_settings_cb');
            % Get all of the data from the gui. If there are bad
            % values, then these will be NaN. The set function will handle
            % the NaN case.
            smooth_M_val = str2double(get(self.h.pp_smooth_M, 'String'));
            smooth_N_val = str2double(get(self.h.pp_smooth_N, 'String'));
            smooth_T_val = str2double(get(self.h.pp_smooth_T, 'String'));
            
            down_M_val = str2double(get(self.h.pp_down_M, 'String'));
            down_N_val = str2double(get(self.h.pp_down_N, 'String'));
            down_T_val = str2double(get(self.h.pp_down_T, 'String'));
            
            self.set_pp_smooth_window(smooth_M_val, smooth_N_val, smooth_T_val);
            self.set_pp_down_sample(down_M_val, down_N_val, down_T_val);
        end
        
        function pp_settings_cancel_cb(self, source_h, eventdata)
            close(self.h.pp_dialog);
        end
        
        function lock_component_button_cb(self, source_h, eventdata)
            disp('lock_component_button_cb');
            self.lock_current_component();
        end
        
        function clear_locked_button_cb(self, source_h, eventdata)
            disp('clear_locked_button_cb');
            self.clear_locked_components();
        end
        
        function component_label_cb(self, source_h, eventdata)
            disp('component_label_cb');
            c = get(source_h, 'UserData');
            
            if isscalar(c)
                % Then jump to the IC
                self.gui.d(self.gui.current_trial).display = 4;
                self.gui.d(self.gui.current_trial).current_frame(4) = c;
                self.update();
                %self.h.roi_editor.set_current_frame(c);
            end
        end
        
        function trial_listbox_cb(self, source_h, eventdata)
            disp('trial_listbox_cb');
            
            sel = get(self.h.trial_listbox, 'Value');
            self.set_selected_trial(sel);
        end
        
        function add_trial_button_cb(self, source_h, eventdata)
            disp('add_trial_button_cb');
            
            self.load_data();
        end
        
        function delete_trial_button_cb(self, source_h, eventdata)
            disp('delete_trial_button_cb');
            
            sel = get(self.h.trial_listbox, 'Value');
            self.delete_trial();
        end
        
        function roi_listbox_cb(self, source_h, eventdata)
            disp('roi_listbox_cb');
            
            sel = get(self.h.roi_listbox, 'Value');
            self.select_roi_set(sel);
        end
        
        function add_rois_button_cb(self, source_h, eventdata)
            disp('add_rois_button_cb');
            self.create_new_roi_set();
        end
        
        function delete_rois_button_cb(self, source_h, eventdata)
            disp('delete_rois_button_cb');
            self.delete_roi_set();
        end
        
        function calc_rois_cb(self, source_h, eventdata)
            disp('calc_rois_cb');
            self.calc_rois();
        end
        
        function save_rois_cb(self, source_h, eventdata)
            self.save_rois();
        end
        
        function load_rois_cb(self, source_h, eventdata)
            self.load_rois();
        end
        
        function load_image_cb(self, source_h, eventdata)
            self.load_data();
        end
        
        function load_session_cb(self, source_h, eventdata)
            self.load_session();
        end
        
        function save_session_cb(self, source_h, eventdata)
            self.save_session();
        end
        
        function viz_settings_cb(self, source_h, eventdata)
            disp('viz_settings_cb');
            self.data(self.gui.current_trial).settings.viz.map_pow = get(self.h.map_pow_slider, 'Value');
            self.data(self.gui.current_trial).settings.viz.color_pow = get(self.h.color_pow_slider, 'Value');
            self.data(self.gui.current_trial).settings.viz.alpha = get(self.h.alpha_slider, 'Value');
            
            self.draw_component_viz();
        end
        
        function concat_trials_toggle_cb(self, source_h, eventdata)
            disp('concat_trials_togle_cb');
            self.align_trials();
        end
        
        function which_pcs_edit_cb(self, source_h, eventdata)
            disp('which_pcs_edit_cb');
            [which_pcs, status] = str2num(get(self.h.which_pcs_edit, 'String'));
            
            if status
                self.set_which_pcs(which_pcs);
            else
                disp('PCs input innapropriately formatted.');
                self.update();
            end
        end
        
        function down_size_slider_cb(self, source_h, eventdata)
            disp('down_slider_cb');
            v = get(self.h.down_size_slider, 'Value');
            self.set_segment_down_size(v);
        end
        
        function down_size_indicator_cb(self, source_h, eventdata)
            disp('down_indicator_cb');
            [val, status] = str2num(get(self.h.down_size_indicator, 'String'));
            
            if status
                self.set_segment_down_size(val);
            else
                disp('Down Size input innapropriately formatted.');
                self.update();
            end
        end
        
        function thresh_slider_cb(self, source_h, eventdata)
            disp('thresh_slider_cb');
            v = get(self.h.thresh_slider, 'Value');
            self.set_segment_thresh(v);
        end
        
        function thresh_indicator_cb(self, source_h, eventdata)
            disp('thresh_indicator_cb');
            [val, status] = str2num(get(self.h.thresh_indicator, 'String'));
            
            if status
                self.set_segment_thresh(val);
            else
                disp('Threshold input innapropriately formatted.');
                self.update();
            end
        end
        
        function max_corr_thresh_button_cb(self, source_h, eventdata)
            disp('max_corr_thresh_button_cb');
        end
        
        function data_clicked_cb(self, source_h, eventdata)
            disp(eventdata);
            idx = eventdata.ClickedIndex;
            
            if isfield(self.data(self.gui.current_trial).segment, 'segment_info')
                roi_idx = find(self.data(self.gui.current_trial).segment.segment_info.ic_ids == idx);
                self.h.roi_editor.set_selected_rois(roi_idx);
            end
        end
        
        function post_poly_slider_cb(self, source_h, eventdata)
            disp('post_poly_slider_cb');
            
            val = get(source_h, 'Value');
            
            self.set_poly_order(val);
        end
        
        function post_poly_edit_cb(self, source_h, eventdata)
            disp('post_poly_edit_cb');
            
            str = get(source_h, 'String');
            val = round(str2num(str));
            
            self.set_poly_order(val);
        end
        
        function post_smooth_slider_cb(self, source_h, eventdata)
            disp('post_smooth_slider_cb');
            
            val = get(source_h, 'Value');
            
            self.set_smooth_order(val);
        end
        
        function post_smooth_edit_cb(self, source_h, eventdata)
            disp('post_smooth_edit_cb');
            
            str = get(source_h, 'String');
            val = round(str2num(str));
            
            self.set_smooth_order(val);
        end
        
        function pp_remove_edit_cb(self, source_h, eventdata)
            disp('pp_remove_edit_cb');
        end
        
        function pp_run_pp_button_cb(self, source_h, eventdata)
            disp('pp_run_pp_button_cb');
            
            self.run_postprocessing();
        end
        
        function pp_clear_pp_button_cb(self, source_h, eventdata)
            disp('pp_clear_pp_button_cb');
            
            self.clear_postprocessing();
        end
        
        function ic_show_viz_check_cb(self, source_h, eventdata)
            disp('ic_show_viz_check_cb');
            
            val = get(source_h, 'Value');
            self.gui.d(self.gui.current_trial).ic_show_viz = val;
            % make sure the roi editor updates.
            self.gui.d(self.gui.current_trial).last_display = 0;
            self.update();
        end
        
        %%%%%%%%%% Main Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function update(self)
            % update(self): main update function
            
            disp('ICP: update');
            
            f = self.h.roi_editor.current_frame;
            if self.gui.d(self.gui.current_trial).display > length(self.gui.d(self.gui.current_trial).current_frame)
                self.gui.d(self.gui.current_trial).current_frame(self.gui.d(self.gui.current_trial).display) = f;
            end
            
            f = self.gui.d(self.gui.current_trial).current_frame(self.gui.d(self.gui.current_trial).display);
            
            set(self.h.stage_tab_panel, 'SelectedChild', self.gui.d(self.gui.current_trial).display);
            
            rois = self.h.roi_editor.rois.xyrra(self.h.roi_editor.selected_rois, :, 1);
            
            cla(self.h.data_axes);
            if ~isempty(rois)
                % plot the original data from the ROI.
                if isfield(self.data(self.gui.current_trial).pp, 'im_data_mc')
                    data = mean_roi(self.data(self.gui.current_trial).pp.im_data_mc, rois, self.data(self.gui.current_trial).pp.mc_x, self.data(self.gui.current_trial).pp.mc_y);
                else
                    data = mean_roi(self.data(self.gui.current_trial).im_data, rois);
                end
                
                % need to do a check on norm_frame
                if size(data, 1) < self.gui.data_norm_frame
                    self.gui.data_norm_frame = 1; % I guess just do this?
                end
                
                data_t = self.data(self.gui.current_trial).im_z;
                
                data = 100 * (data ./ repmat(data(self.gui.data_norm_frame, :), size(data, 1), 1) - 1);
                
                plot(self.h.data_axes, data_t, data);
            end
            
            if self.gui.d(self.gui.current_trial).display == 5 && self.data(self.gui.current_trial).stage >= self.PostProcessingStage ...
                    && isfield(self.data(self.gui.current_trial).segment, 'im_data') && ~isempty(self.data(self.gui.current_trial).segment.im_data)
                
                %                 if self.gui.d(self.gui.current_trial).last_display ~= self.gui.d(self.gui.current_trial).display
                %                     % Don't update the roi editor if its the same
                %                     self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).cluster.im_data, [], self.data(self.gui.current_trial).cluster.im_x, self.data(self.gui.current_trial).cluster.im_y);
                %                 end
                %                 self.gui.d(self.gui.current_trial).last_display = self.gui.d(self.gui.current_trial).display;
                %
                %                 cla(self.h.component_axes);
                %                 plot(self.h.component_axes, self.data(self.gui.current_trial).ica.ics(:, f), 'k', 'LineWidth', 2);
                %
                %                 plot(self.h.component_axes, self.data(self.gui.current_trial).ica.ics(:, self.data(self.gui.current_trial).cluster.top3(f, 3)), 'b');
                %                 plot(self.h.component_axes, self.data(self.gui.current_trial).ica.ics(:, self.data(self.gui.current_trial).cluster.top3(f, 2)), 'g');
                %                 plot(self.h.component_axes, self.data(self.gui.current_trial).ica.ics(:, self.data(self.gui.current_trial).cluster.top3(f, 1)), 'r');
                
                %             elseif self.gui.display == 5 && self.data(self.gui.current_trial).stage >= self.PostProcessingStage ...
                %                     && isfield(self.data(self.gui.current_trial).segment, 'im_data') && ~isempty(self.data(self.gui.current_trial).segment.im_data)
                %                 % Then view the segments
                if self.gui.d(self.gui.current_trial).last_display ~= self.gui.d(self.gui.current_trial).display
                    self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).segment.im_data, [], self.data(self.gui.current_trial).segment.im_x, self.data(self.gui.current_trial).segment.im_y);
                    f = self.h.roi_editor.set_current_frame(f);
                end
                self.gui.d(self.gui.current_trial).last_display = self.gui.d(self.gui.current_trial).display;
                
                % Plot the current ic
                cla(self.h.component_axes);
                legend(self.h.component_axes, 'off');
                
                data_t = self.data(self.gui.current_trial).im_z(self.data(self.gui.current_trial).pp.im_z);
                plot(self.h.component_axes, data_t, self.data(self.gui.current_trial).ica.ics(:, f), 'k');
                ica_idx = f;
                
                text_x = 0.90;
                
                self.h.component_labels = text(text_x, 0.9, num2str(ica_idx), ...
                    'Parent', self.h.component_axes, 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'UserData', ica_idx, ...
                    'Color', 'k', 'ButtonDownFcn', @self.component_label_cb);
                
            elseif self.gui.d(self.gui.current_trial).display == 6 && self.data(self.gui.current_trial).stage >= self.PostProcessingStage ...
                    && isfield(self.data(self.gui.current_trial).viz, 'im_data') && ~isempty(self.data(self.gui.current_trial).viz.im_data)
                % View the visualization
                if self.gui.d(self.gui.current_trial).last_display ~= self.gui.d(self.gui.current_trial).display
                    %%% This is a HACK for ROI Editor. It can show an RGB
                    %%% image, but it needs a 4th dimension and I can't
                    %%% make it a singleton 4th dimension.
                    im4D = repmat(self.data(self.gui.current_trial).viz.im_data, [1 1 1 2]);
                    %%%
                    
                    self.h.roi_editor.set_im_data(im4D, [], self.data(self.gui.current_trial).viz.im_x, self.data(self.gui.current_trial).viz.im_y);
                end
                self.gui.d(self.gui.current_trial).last_display = self.gui.d(self.gui.current_trial).display;
                
            elseif self.gui.d(self.gui.current_trial).display == 4 && self.data(self.gui.current_trial).stage >= self.IcaStage
                % Then view the ICs
                if self.gui.d(self.gui.current_trial).last_display ~= self.gui.d(self.gui.current_trial).display
                    % Don't update the roi editor if its the same
                    if isfield(self.data(self.gui.current_trial).viz, 'component_colors') ...
                            && ~isempty(self.data(self.gui.current_trial).viz.component_colors) ...
                            && self.gui.d(self.gui.current_trial).ic_show_viz
                        self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).viz.component_colors, ...
                            false, self.data(self.gui.current_trial).ica.im_x, self.data(self.gui.current_trial).ica.im_y);
                    else
                        self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).ica.im_data, ...
                            [], self.data(self.gui.current_trial).ica.im_x, self.data(self.gui.current_trial).ica.im_y);
                    end
                end
                self.gui.d(self.gui.current_trial).last_display = self.gui.d(self.gui.current_trial).display;
                
                % Plot the current ic
                cla(self.h.component_axes);
                legend(self.h.component_axes, 'off');
                
                data_t = self.data(self.gui.current_trial).im_z(self.data(self.gui.current_trial).pp.im_z);

                plot(self.h.component_axes, data_t, self.data(self.gui.current_trial).ica.ics(:, f), 'k');
                
            elseif self.gui.d(self.gui.current_trial).display == 3 && self.data(self.gui.current_trial).stage >= self.PcaStage
                % Then view the PCs
                if self.gui.d(self.gui.current_trial).last_display ~= self.gui.d(self.gui.current_trial).display
                    % Don't update the roi editor if its the same
                    self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).pca.im_data, [], self.data(self.gui.current_trial).pca.im_x, self.data(self.gui.current_trial).pca.im_y);
                end
                self.gui.d(self.gui.current_trial).last_display = self.gui.d(self.gui.current_trial).display;
                
                % Plot the current pc
                cla(self.h.component_axes);
                legend(self.h.component_axes, 'off');
                
                %plot(self.h.component_axes, self.data(self.gui.current_trial).pca.pcs(:, f), 'k');
                data_t = self.data(self.gui.current_trial).im_z(self.data(self.gui.current_trial).pp.im_z);

                if isfield(self.data(self.gui.current_trial).pca, 'pc_rec')
                    plot(self.h.component_axes, data_t, self.data(self.gui.current_trial).pca.pc_rec(:,f));
                else
                    plot(self.h.component_axes, data_t, self.data(self.gui.current_trial).pca.pcs(:, f), 'k');
                end
            elseif self.gui.d(self.gui.current_trial).display == 2 && self.data(self.gui.current_trial).stage >= self.PreProcessingStage
                % View the Preprocessing data
                if self.gui.d(self.gui.current_trial).last_display ~= self.gui.d(self.gui.current_trial).display
                    % Don't update the roi editor if its the same
                    self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).pp.im_data, [], self.data(self.gui.current_trial).pp.im_x, self.data(self.gui.current_trial).pp.im_y);
                end
                self.gui.d(self.gui.current_trial).last_display = self.gui.d(self.gui.current_trial).display;
            else
                % View the raw data.
                if self.gui.d(self.gui.current_trial).last_display ~= 1
                    % Don't update the roi editor if its the same
                    self.h.roi_editor.set_im_data(self.data(self.gui.current_trial).im_data);
                end
                self.gui.d(self.gui.current_trial).last_display = 1;
            end
            
            self.h.roi_editor.set_current_frame(f, 0);
            
            % I just want to see everything with the full axis range
            set(self.h.roi_editor.h.im_axes, 'Xlim', self.data(self.gui.current_trial).im_x([1, end]),...
                'YLim', self.data(self.gui.current_trial).im_y([1, end]));
            
            % Set the levels,
            levels = self.gui.d(self.gui.current_trial).levels(:,:,self.gui.d(self.gui.current_trial).last_display);
            if ~any(isnan(levels))
                % Only do it if we actually have the last levels.
                self.h.roi_editor.set_levels(levels, [], 0);
            end
            
            set(self.h.which_pcs_edit, 'String', mat2str(self.data(self.gui.current_trial).settings.ica.which_pcs));
            
            switch self.data(self.gui.current_trial).stage
                case self.InitStage, s = 'Initialized';
                case self.PreProcessingStage, s = 'Pre-Processing Complete';
                case self.PcaStage, s = 'PCA Complete';
                case self.IcaStage, s = 'ICA Complete';
                case self.PostProcessingStage, s = 'Post-Processing Complete';
            end
            
            set(self.h.stage_status, 'String', s);
            
            self.h.roi_editor.color_rois = true;
            if self.gui.d(self.gui.current_trial).display == 6 && self.data(self.gui.current_trial).stage == self.PostProcessingStage  ...
                    && isfield(self.data(self.gui.current_trial).cluster, 'im_data') && ~isempty(self.data(self.gui.current_trial).cluster.im_data)
                self.h.roi_editor.color_rois = false;
                self.draw_clustered_rois();
                
            elseif self.data(self.gui.current_trial).is_component_set(self.gui.d(self.gui.current_trial).current_roi_set) ...
                    && self.data(self.gui.current_trial).stage >= self.PostProcessingStage ...
                    && ~isempty(self.h.roi_editor.selected_rois) ...
                    && isfield(self.data(self.gui.current_trial).segment, 'segment_info')
                cla(self.h.component_axes);
                
                self.h.component_labels = [];
                data_t = self.data(self.gui.current_trial).im_z(self.data(self.gui.current_trial).pp.im_z);

                for i = 1:length(self.h.roi_editor.selected_rois)
                    c = self.gui.locked_colors(mod(i-1, length(self.gui.locked_colors))+1, :);
                    ica_idx = self.data(self.gui.current_trial).segment.segment_info.ic_ids(self.h.roi_editor.selected_rois(i));
                    plot(self.h.component_axes, data_t, self.data(self.gui.current_trial).ica.ics(:, ica_idx), 'Color', c);
                    
                    text_x = 0.95 - (length(self.h.roi_editor.selected_rois) - i) * 0.05;
                    self.h.component_labels(i) = text(text_x, 0.9, num2str(ica_idx), ...
                        'Parent', self.h.component_axes, 'Units', 'normalized', ...
                        'HorizontalAlignment', 'center', 'UserData', ica_idx, ...
                        'Color', c, 'ButtonDownFcn', @self.component_label_cb);
                end
            else
                self.show_best_selected_components(rois);
            end
            
            % Update ICA settings gui
            set(self.h.post_poly_slider, 'Value', self.data(self.gui.current_trial).settings.post.poly_order);
            set(self.h.post_poly_edit, 'String', num2str(self.data(self.gui.current_trial).settings.post.poly_order));
            set(self.h.post_smooth_slider, 'Value', self.data(self.gui.current_trial).settings.post.smooth_order);
            set(self.h.post_smooth_edit, 'String', num2str(self.data(self.gui.current_trial).settings.post.smooth_order));
            
            set(self.h.ic_show_viz_check, 'Value', self.gui.d(self.gui.current_trial).ic_show_viz);
            
            % Update the visualization settings gui.
            set(self.h.map_pow_slider, 'Value', self.data(self.gui.current_trial).settings.viz.map_pow);
            set(self.h.map_pow_indicator, 'String', num2str(self.data(self.gui.current_trial).settings.viz.map_pow));
            set(self.h.color_pow_slider, 'Value', self.data(self.gui.current_trial).settings.viz.color_pow);
            set(self.h.color_pow_indicator, 'String', num2str(self.data(self.gui.current_trial).settings.viz.color_pow));
            set(self.h.alpha_slider, 'Value', self.data(self.gui.current_trial).settings.viz.alpha);
            set(self.h.alpha_indicator, 'String', num2str(self.data(self.gui.current_trial).settings.viz.alpha));
            
            % Update segment settings gui
            if isfield(self.data(self.gui.current_trial).ica, 'im_data')
                % Then reset the range of the thresh slider
                set(self.h.thresh_slider, 'Min', min(self.data(self.gui.current_trial).ica.im_data(:)), 'Max', max(self.data(self.gui.current_trial).ica.im_data(:)));
            else
                if self.data(self.gui.current_trial).settings.segment.thresh > 10 ...
                        || self.data(self.gui.current_trial).settings.segment.thresh < 0
                    self.data(self.gui.current_trial).settings.segment.thresh = 2.5
                end
                set(self.h.thresh_slider, 'Min', 0, 'Max', 10);
            end
            % @todo: make sure these are in the right range.
            set(self.h.down_size_slider, 'Value', self.data(self.gui.current_trial).settings.segment.down_size);
            set(self.h.down_size_indicator, 'String', num2str(self.data(self.gui.current_trial).settings.segment.down_size));
            set(self.h.thresh_slider, 'Value', self.data(self.gui.current_trial).settings.segment.thresh);
            set(self.h.thresh_indicator, 'String', num2str(self.data(self.gui.current_trial).settings.segment.thresh));
            
            % reset the HighDViewers if necessary
            if self.data(self.gui.current_trial).stage >= self.PcaStage
                %self.h.pc_pixel_viewer.set_scores(self.data(self.gui.current_trial).pca.scores);
            else
                self.h.pc_pixel_viewer.set_scores([]);
            end
            
            
            if self.data(self.gui.current_trial).stage >= self.IcaStage
                % Then can use the viewer and coherence
                %self.h.pc_ica_viewer.set_scores(self.data(self.gui.current_trial).ica.A');
                %self.h.ica_coherence.set_data(1:size(self.data(self.gui.current_trial).ica.ics, 1), self.data(self.gui.current_trial).ica.ics');
            else
                self.h.pc_ica_viewer.set_scores([]);
                self.h.ica_coherence.set_data([]);
            end
            
            self.plot_locked_components();
            %self.plot_3d();
            
            self.build_roi_listbox();
            self.build_trial_listbox();
            
            drawnow;
        end
        
        function warp = run_motion_correction(self)
            % run_motion_correction(self): Runs the motion correction.
            
            disp('run_motion_correction');
            
            set(self.h.stage_status, 'String', 'Running Motion Correction...');
            drawnow;
            
            s = self.data(self.gui.current_trial).settings.preprocessing;
            
            [self.data(self.gui.current_trial).pp.im_data_mc, warp] = s.motion_correct_func(self.data(self.gui.current_trial).im_data);
            
            % Fix the size of the corrected data.
            sx = floor((size(self.data(self.gui.current_trial).im_data, 2) - size(self.data(self.gui.current_trial).pp.im_data_mc, 2))/2) + 1;
            sy = floor((size(self.data(self.gui.current_trial).im_data, 1) - size(self.data(self.gui.current_trial).pp.im_data_mc, 1))/2) + 1;
            
            self.data(self.gui.current_trial).pp.mc_x = sx:(size(self.data(self.gui.current_trial).pp.im_data_mc, 2) + sx - 1);
            self.data(self.gui.current_trial).pp.mc_y = sy:(size(self.data(self.gui.current_trial).pp.im_data_mc, 1) + sy - 1);
        end
        
        function run_filters(self)
            % run_filters(self): Runs the filtering stage of preprocessing.
            
        end
        
        function run_preprocessing(self)
            % run_preprocessing(self): Runs the preprocessing stage of the
            % analysis.
            %
            % Preprocessing turns image data (MxNxt) into a data matrix
            % (M*Nxt).
            disp('run_preprocessing');
            
            % @todo: checks on current state
            
            set(self.h.stage_status, 'String', 'Running Pre-Processing...');
            drawnow;
            
            s = self.data(self.gui.current_trial).settings.preprocessing;
            
            if isfield(self.data(1), 'concat') % @todo: and some other flag
                disp('concat pp');
                % Then we're running the concatenated ICA
                im_data = self.data(1).concat.im_data;
                im_x = self.data(1).concat.im_x;
                im_y = self.data(1).concat.im_y;
                im_z = self.data(1).concat.im_z;
                
                % Set the concat flag
                for i = 1:length(self.data)
                    self.data(i).pp.is_concat = true;
                end
                
                % The concat data always goes into trial 1.
                self.gui.current_trial = 1;
            else
                if isfield(self.data(self.gui.current_trial).pp, 'im_data_mc')
                    % then we have motion corrected data.
                    im_data = self.data(self.gui.current_trial).pp.im_data_mc;
                    im_x = self.data(self.gui.current_trial).pp.mc_x;
                    im_y = self.data(self.gui.current_trial).pp.mc_y;
                    im_z = 1:size(im_data, 3);
                else
                    % Then use the original data.
                    im_data = self.data(self.gui.current_trial).im_data;
                    im_x = 1:size(im_data, 2);
                    im_y = 1:size(im_data, 1);
                    im_z = 1:size(im_data, 3);
                end
                
                % Turn the concat flag off.
                self.data(self.gui.current_trial).pp.is_concat = false;
                
                im_data(:,:,s.remove_frames) = [];
                im_z(s.remove_frames) = [];
            end
            
            block = ones(s.smooth_window) ./ (prod(s.smooth_window));
            
            im_conv = convn(im_data, block, 'same');
            
            xs_remove = floor((size(block, 2)-1)/2);
            xe_remove = (size(block, 2)-1) - xs_remove;
            ys_remove = floor((size(block, 1)-1)/2);
            ye_remove = (size(block, 2)-1) - ys_remove;
            zs_remove = floor((size(block, 3)-1)/2);
            ze_remove = (size(block, 3)-1) - zs_remove;
            
            im_x(1:xs_remove) = [];
            im_x((end-xe_remove):end) = [];
            im_y(1:ys_remove) = [];
            im_y((end-ye_remove):end) = [];
            im_z(1:zs_remove) = [];
            im_z((end-ze_remove):end) = [];
            
            im_conv([1:ys_remove, (end-ye_remove):end], :, :) = [];
            im_conv(:, [1:xs_remove, (end-xe_remove):end], :) = [];
            im_conv(:, :, [1:zs_remove, (end-ze_remove):end]) = [];
            
            xidx = 1:s.down_sample(1):length(im_x);
            yidx = 1:s.down_sample(2):length(im_y);
            zidx = 1:s.down_sample(3):length(im_z);
            
            % Ok, now need to take out frames
            self.data(self.gui.current_trial).pp.im_y = im_y(yidx);
            self.data(self.gui.current_trial).pp.im_x = im_x(xidx);
            self.data(self.gui.current_trial).pp.im_z = im_z(zidx);
            
            self.data(self.gui.current_trial).pp.im_data = im_conv(yidx, xidx, zidx);
            self.data(self.gui.current_trial).pp.data = reshape(self.data(self.gui.current_trial).pp.im_data, [], size(self.data(self.gui.current_trial).pp.im_data, 3));
            
            self.data(self.gui.current_trial).pp.use_wavelets = self.gui.d(self.gui.current_trial).use_wavelets;
            
            if self.data(self.gui.current_trial).pp.use_wavelets
                % Then we want to do the wavelet decomposition
                disp('Computing Wavelets...');
                set(self.h.stage_status, 'String', 'Computing Wavelets...');
                drawnow;
                
                cwt_struct = cwtft(self.data(self.gui.current_trial).pp.data(1,:));
                num_scales = length(cwt_struct.scales);
                num_frames = size(self.data(self.gui.current_trial).pp.data, 2);
                
                self.data(self.gui.current_trial).pp.cwt_data = zeros(size(self.data(self.gui.current_trial).pp.data, 1), 2 * num_scales * num_frames);
                
                rcwt = real(cwt_struct.cfs);
                icwt = imag(cwt_struct.cfs);
                
                self.data(self.gui.current_trial).pp.cwt_data(1, :) = reshape([rcwt, icwt], 1, []);
                
                self.data(self.gui.current_trial).pp.cwt_struct = cwt_struct;
                
                for i = 2:size(self.data(self.gui.current_trial).pp.data, 1)
                    cwt_struct = cwtft(self.data(self.gui.current_trial).pp.data(i, :));
                    
                    rcwt = real(cwt_struct.cfs);
                    icwt = imag(cwt_struct.cfs);
                    
                    self.data(self.gui.current_trial).pp.cwt_data(i, :) = reshape([rcwt, icwt], 1, []);
                end
                
                % @todo: other things with the wavelets, like removing
                % frequencies etc. Things that can be done to cwt_data
            end
            
            % Ok, so if we are doing the concat then restructure the data
            if isfield(self.data(1), 'concat') % @todo: some other flag
                % Right, so put the all data together in the concat struct,
                % and then split the data back to the trials.
                
                self.data(1).concat.pp_im_data = self.data(self.gui.current_trial).pp.im_data;
                self.data(1).concat.pp_im_x = self.data(self.gui.current_trial).pp.im_x;
                self.data(1).concat.pp_im_y = self.data(self.gui.current_trial).pp.im_y;
                self.data(1).concat.pp_im_z = self.data(self.gui.current_trial).pp.im_z;
                
                frame_ids = self.data(1).concat.frame_ids;
                frame_ids(1:zs_remove) = [];
                frame_ids((end-zs_remove):end) = [];
                self.data(1).concat.pp_frame_ids = frame_ids(zidx);
                
                % so frame_ids should be the same length as im_z
                assert(length(self.data(1).concat.pp_frame_ids) == length(self.data(1).concat.pp_im_z));
                
                % @todo: if you're using the wavelets more stuff has to
                % happen.
                
                for i = 1:length(self.data)
                    % Ok, so now we need to split the im_data...
                    idx = find(self.data(1).concat.pp_frame_ids == i);
                    
                    self.data(i).pp.im_data = self.data(1).concat.pp_im_data(:,:,idx);
                    self.data(i).pp.im_x = self.data(1).concat.pp_im_x;
                    self.data(i).pp.im_y = self.data(1).concat.pp_im_y;
                    self.data(i).pp.im_z = self.data(1).concat.pp_im_z(idx);
                    self.data(i).stage = self.PreProcessingStage;
                end
            end
            
            %%% I'm going ot hack in a filter here to test
            %hd = load('icp_filter.mat');
            %data = self.data(self.gui.current_trial).pp.data - repmat(mean(self.data(self.gui.current_trial).pp.data, 2), 1, size(self.data(self.gui.current_trial).pp.data, 2));
            %self.data(self.gui.current_trial).pp.data = filter(hd.Hd, data')';
            %%%
            
            self.data(self.gui.current_trial).stage = self.PreProcessingStage;
            
            self.gui.d(self.gui.current_trial).last_display = 0;
            self.update();
        end
        
        function run_pca(self)
            % run_pca(self): Runs the pca stage of the analysis.
            
            disp('run_pca');
            
            % @todo: checks on state
            if self.data(self.gui.current_trial).stage == self.InitStage
                disp('Running previous stage...');
                self.run_preprocessing();
            end
            
            set(self.h.stage_status, 'String', 'Running PCA...');
            drawnow;
            
            s = self.data(self.gui.current_trial).settings.pca;
            
            if isfield(self.data(1), 'concat') && isfield(self.data(1).concat, 'pp_im_data') % @todo: another flag?
                disp('concat pca');
                
                d = reshape(self.data(1).concat.pp_im_data, [], size(self.data(1).concat.pp_im_data, 3))';
                
                if exist('pca') == 2
                    [scores, pcs, eigs] = pca(d);
                else
                    [scores, pcs, eigs] = princomp(d);
                end
                
                self.data(1).concat.pca_scores = scores;
                self.data(1).concat.pca_pcs = pcs;
                self.data(1).concat.pca_eigs = eigs;
                self.data(1).concat.pca_im_data = reshape(self.data(1).concat.pca_scores, ...
                    size(self.data(1).concat.pp_im_data,1), size(self.data(1).concat.pp_im_data,2), size(self.data(1).concat.pca_scores, 2));
                
                for i = 1:length(self.data)
                    self.data(i).pca.scores = self.data(1).concat.pca_scores;
                    self.data(i).pca.im_data = self.data(1).concat.pca_im_data;
                    self.data(i).pca.eigs = self.data(1).concat.pca_eigs;
                    self.data(i).pca.im_x = self.data(1).concat.pp_im_x;
                    self.data(i).pca.im_y = self.data(1).concat.pp_im_y;
                    
                    idx = self.data(1).concat.pp_frame_ids == i;
                    self.data(i).pca.pcs = self.data(1).concat.pca_pcs(idx, :);
                    
                    self.data(i).stage = self.PcaStage;
                end
                
            else
                if self.data(self.gui.current_trial).pp.use_wavelets
                    if s.corr_pca == 1
                        d = zscore(self.data(self.gui.current_trial).pp.cwt_data');
                    else
                        d = self.data(self.gui.current_trial).pp.cwt_data';
                    end
                    
                    if exist('pca') == 2
                        [scores, pcs, eigs] = pca(d);
                    else
                        [scores, pcs, eigs] = princomp(d);
                    end
                    
                    % Reconstruct the original data from wavelets
                    cwt_struct = self.data(self.gui.current_trial).pp.cwt_struct;
                    num_frames = size(self.data(self.gui.current_trial).pp.data, 2);
                    wavelet_rec = zeros(num_frames, size(pcs, 2));
                    for i = 1:size(pcs, 2)
                        pc_cfs = reshape(pcs(:,i), length(cwt_struct.scales), []);
                        cwt_struct.cfs = complex(pc_cfs(:, 1:num_frames), pc_cfs(:, (num_frames+1):end));
                        
                        wavelet_rec(:, i) = icwtft(cwt_struct);
                    end
                    self.data(self.gui.current_trial).pca.pc_rec = wavelet_rec;
                else
                    if s.corr_pca == 1
                        d = zscore(self.data(self.gui.current_trial).pp.data');
                    else
                        d = self.data(self.gui.current_trial).pp.data';
                    end
                    
                    if exist('pca') == 2
                        [scores, pcs, eigs] = pca(d);
                    else
                        [scores, pcs, eigs] = princomp(d);
                    end
                end
                
                self.data(self.gui.current_trial).pca.scores = scores;
                self.data(self.gui.current_trial).pca.pcs = pcs;
                self.data(self.gui.current_trial).pca.eigs = eigs;
                
                
                self.data(self.gui.current_trial).pca.im_data = reshape(self.data(self.gui.current_trial).pca.scores, ...
                    size(self.data(self.gui.current_trial).pp.im_data,1), size(self.data(self.gui.current_trial).pp.im_data,2), size(self.data(self.gui.current_trial).pca.scores, 2));
                
                self.data(self.gui.current_trial).pca.im_x = self.data(self.gui.current_trial).pp.im_x;
                self.data(self.gui.current_trial).pca.im_y = self.data(self.gui.current_trial).pp.im_y;
            end
            
            self.h.pc_pixel_viewer.set_scores(self.data(self.gui.current_trial).pca.scores);
            
            self.data(self.gui.current_trial).stage = self.PcaStage;
            self.gui.d(self.gui.current_trial).last_display = 0;
            self.update();
        end
        
        function run_ica(self)
            % run_ica(self): Runs the ica stage of the analysis.
            
            disp('run_ica');
            
            % @todo: checks on state.
            if self.data(self.gui.current_trial).stage == self.InitStage || self.data(self.gui.current_trial).stage == self.PreProcessingStage
                disp('Running previous stages...');
                self.run_pca();
            end
            
            set(self.h.stage_status, 'String', 'Running ICA...');
            drawnow;
            
            s = self.data(self.gui.current_trial).settings.ica;
            
            % Make sure that the pcs requested are in range.
            which_pcs = s.which_pcs;
            which_pcs(which_pcs > size(self.data(self.gui.current_trial).pca.scores, 2)) = [];
            
            if strcmp(s.ica_func, 'CellsortICA')
                disp('Running CellsortICA');
                [ics, im_data, A, niter] = CellsortICA(self.data(self.gui.current_trial).pca.pcs(:, which_pcs)', ...
                    self.data(self.gui.current_trial).pca.im_data(:, :, which_pcs), self.data(self.gui.current_trial).pca.eigs(which_pcs), [], s.mu);
                
                self.data(self.gui.current_trial).ica.ics = ics';
                self.data(self.gui.current_trial).ica.im_data = shiftdim(im_data, 1);
                self.data(self.gui.current_trial).ica.A = A;
                
            elseif strcmp(s.ica_func, 'fastica')
                disp('Running fastica');
                
                if s.init_guess == -1
                    % This means that the init guess should be the previous A
                    % matrix.
                    if isfield(self.data(self.gui.current_trial).ica, 'A') && size(self.data(self.gui.current_trial).ica.A, 1) == length(which_pcs)
                        % Then the last A matrix is valid.
                        [icasig, A, W] = fastica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)', 'initGuess', self.data(self.gui.current_trial).ica.A);
                    else
                        % Then the last A matrix is invalid.
                        disp('Could not use previous A as initial guess.');
                        [icasig, A, W] = fastica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)');
                    end
                elseif s.init_guess == 0
                    % Then we just use the normal random guess.
                    %%%
                    %[icasig, A, W] = fastica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)');
                    %%% Messing around with the other fastica params
                    disp('fastica params');
                    [icasig, A, W] = fastica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)', 'g', 'tanh', 'a1', 3, 'stabilization', 'on');
                    %%%
                else
                    % Then s.init_guess should be the A matrix itself.
                    if size(s.init_guess, 1) == length(which_pcs)
                        disp('Using Init Guess');
                        [icasig, A, W] = fastica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)', 'initGuess', s.init_guess);
                    else
                        disp('Initial Guess incorrectly formatted.');
                        [icasig, A, W] = fastica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)');
                    end
                end
                
                icasig = icasig';
                
                if s.positive_skew
                    % Then we want the component scores to all skew positively.
                    is_neg_skew = skewness(icasig) < 0;
                    icasig(:, is_neg_skew) = -icasig(:, is_neg_skew);
                    A(:, is_neg_skew) = -A(:, is_neg_skew);
                end
                
                self.data(self.gui.current_trial).ica.A = A;
                self.data(self.gui.current_trial).ica.W = W;
                ics = self.data(self.gui.current_trial).pca.pcs(:, which_pcs) * A;
                
                if isfield(self.data(self.gui.current_trial).pp, 'use_wavelets') ...
                        && self.data(self.gui.current_trial).pp.use_wavelets
                    % Reconstruct the original data from wavelets
                    cwt_struct = self.data(self.gui.current_trial).pp.cwt_struct;
                    num_frames = size(self.data(self.gui.current_trial).pp.data, 2);
                    wavelet_rec = zeros(num_frames, size(ics, 2));
                    for i = 1:size(ics, 2)
                        ic_cfs = reshape(ics(:,i), length(cwt_struct.scales), []);
                        cwt_struct.cfs = complex(ic_cfs(:, 1:num_frames), ic_cfs(:, (num_frames+1):end));
                        
                        wavelet_rec(:, i) = icwtft(cwt_struct);
                    end
                    self.data(self.gui.current_trial).ica.ics = wavelet_rec;
                else
                    self.data(self.gui.current_trial).ica.ics = ics;
                end
                
                self.data(self.gui.current_trial).ica.im_data = reshape(icasig, ...
                    size(self.data(self.gui.current_trial).pp.im_data,1), size(self.data(self.gui.current_trial).pp.im_data,2), size(icasig, 2));
            elseif strcmp(s.ica_func, 'TreeICA')
                
            elseif strcmp(s.ica_func, 'RadICAl')
                
            elseif strcmp(s.ica_func, 'KernelICA')
                %                 disp('Running Kernel ICA');
                %                 tic;
                %                 W = kernel_ica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)');
                %
                %                 self.data(self.gui.current_trial).ica.scores = (W * self.data(self.gui.current_trial).pca.scores(:, which_pcs)')';
                %                 self.data(self.gui.current_trial).ica.ics = self.data(self.gui.current_trial).pca.pcs(:, which_pcs) / W;
                %
                %                 self.data(self.gui.current_trial).ica.im_data = reshape(self.data(self.gui.current_trial).ica.scores, ...
                %                     size(self.data(self.gui.current_trial).pp.im_data,1), size(self.data(self.gui.current_trial).pp.im_data, 2), size(self.data(self.gui.current_trial).ica.scores, 2));
                %
                %                 toc;
                %             elseif strcmp(s.ica_func, 'imageica')
                
            elseif strcmp(s.ica_func, 'icasso')
                
            elseif strcmp(s.ica_func, 'fourierica')
                [S_Ft, A, W] = fourierica(self.data(self.gui.current_trial).pca.scores(:, which_pcs)', length(which_pcs), 50, 0, 20);
                
                icasig = (W * self.data(self.gui.current_trial).pca.scores(:, which_pcs)')';
                self.data(self.gui.current_trial).ica.ics = self.data(self.gui.current_trial).pca.pcs(:, which_pcs) * A;
                
                self.data(self.gui.current_trial).ica.im_data = reshape(icasig, ...
                    size(self.data(self.gui.current_trial).pp.im_data,1), size(self.data(self.gui.current_trial).pp.im_data, 2), size(icasig, 2));
            else
                error('Incorrect ICA function');
            end
            self.data(self.gui.current_trial).ica.im_x = self.data(self.gui.current_trial).pca.im_x;
            self.data(self.gui.current_trial).ica.im_y = self.data(self.gui.current_trial).pca.im_y;
            
            if isfield(self.data(1), 'concat') && isfield(self.data(1).concat, 'pca_pcs')
                % OK, so we just do the ica on the scores, so now can get
                % the ics for all of the rest of the trials by multiplying
                % by the pcs
                disp('ica concatenated trials');
                A = self.data(self.gui.current_trial).ica.A;
                W =  self.data(self.gui.current_trial).ica.W;
                ics = self.data(self.gui.current_trial).pca.pcs(:, which_pcs) * A;
                im_data = self.data(self.gui.current_trial).ica.im_data;
                
                for i = 1:length(self.data)
                    
                    self.data(i).ica.im_data = im_data;
                    self.data(i).ica.ics = self.data(i).pca.pcs(:, which_pcs) * A;
                    self.data(i).ica.A = A;
                    self.data(i).ica.im_x = self.data(i).pca.im_x;
                    self.data(i).ica.im_y = self.data(i).pca.im_y;
                    
                    self.data(i).stage = self.IcaStage;
                end
            end
            
            self.h.pc_ica_viewer.set_scores(self.data(self.gui.current_trial).ica.A');
            
            data_t = self.data(self.gui.current_trial).im_z(self.data(self.gui.current_trial).pp.im_z);
            self.h.ica_coherence.set_data(data_t, self.data(self.gui.current_trial).ica.ics');
            
            self.data(self.gui.current_trial).stage = self.IcaStage;
            self.gui.d(self.gui.current_trial).last_display = 0;
            self.update();
        end
        
        function run_segmentation(self)
            % run_segmentation(self): Runs the segmentation algorithm on
            % the ICs.
            %
            % This looks for ic components that are spatially localized.
            
            if self.data(self.gui.current_trial).stage < self.IcaStage
                disp('Run ICA first');
                return;
            end
            
            set(self.h.stage_status, 'String', 'Running Segmentation...');
            drawnow;
            
            thresh = self.data(self.gui.current_trial).settings.segment.thresh;
            down_size = 1./self.data(self.gui.current_trial).settings.segment.down_size;
            min_area = self.data(self.gui.current_trial).settings.segment.min_area;
            
            [segment_masks, segment_info] = segment_ics(self.data(self.gui.current_trial).ica.im_data, ...
                thresh, down_size, min_area);
            
            % Make segment masks for each IC
            im_data = zeros(size(self.data(self.gui.current_trial).ica.im_data));
            for i = 1:size(self.data(self.gui.current_trial).ica.im_data, 3)
                % Ok, make the im data all the masks for 1 segment.
                idxs = find(segment_info.ic_ids == i);
                if isempty(idxs)
                    % Then we didn't get anything out of a segment, which
                    % shouldn't happen...
                    disp(['No segments! ' num2str(i)]);
                    continue;
                end
                
                im_sum = zeros(size(segment_masks(:,:,idxs(1))));
                
                pos_idxs = find(segment_info.is_pos(idxs));
                neg_idxs = find(~segment_info.is_pos(idxs));
                for j = 1:length(pos_idxs)
                    im_sum = im_sum + j * segment_masks(:,:,idxs(pos_idxs(j)));
                end
                for j = 1:length(neg_idxs)
                    im_sum = im_sum - j * segment_masks(:,:,idxs(neg_idxs(j)));
                end
                
                im_data(:,:,i) = norm_range(im_sum);
            end
            
            % Now need to fix the rois
            im_x = self.data(self.gui.current_trial).ica.im_x;
            im_y = self.data(self.gui.current_trial).ica.im_y;
            segment_info.rois(:, 1) = interp1(1:size(segment_masks, 2), im_x, segment_info.rois(:, 1));
            segment_info.rois(:, 2) = interp1(1:size(segment_masks, 1), im_y, segment_info.rois(:, 2));
            segment_info.rois(:, 3) = mean(diff(im_x)) * segment_info.rois(:, 3) ./ sqrt(2);
            segment_info.rois(:, 4) = mean(diff(im_y)) * segment_info.rois(:, 4) ./ sqrt(2);
            
            self.data(self.gui.current_trial).segment.im_data = im_data;
            self.data(self.gui.current_trial).segment.im_x = self.data(self.gui.current_trial).ica.im_x;
            self.data(self.gui.current_trial).segment.im_y = self.data(self.gui.current_trial).ica.im_y;
            self.data(self.gui.current_trial).segment.segment_info = segment_info;
            
            self.create_new_roi_set('Segment_ROIs', true);
            self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set} = segment_info.rois;
            
            self.h.roi_editor.set_rois(self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set}, false);
            
            self.update();
            
            
            self.data(self.gui.current_trial).stage = self.PostProcessingStage;
            
            self.gui.d(self.gui.current_trial).last_display = 0;
            self.update();
        end
        
        function run_visualization(self, pc_viz)
            % run_visualization(self): computes ica visualizations.
            
            disp('run_visualization');
            
            if self.data(self.gui.current_trial).stage < self.IcaStage
                disp('Run ICA first');
                return;
            end
            
            if nargin < 2 || isempty(pc_viz)
                % Then want to pick which ever one is currently being shown
                selected_tab = self.h.viewer_tab_panel.SelectedChild;
                
                if selected_tab == 2
                    % Then looking at the PCs
                    pc_viz = 1;
                elseif selected_tab == 3
                    % Then looking at the coherence
                    pc_viz = 0;
                else
                    % Then we're looking at pixels, so don't do anything.
                    return;
                end
            end
            
            %colors = viz_function(self);
            
            if pc_viz
                colors = self.h.pc_ica_viewer.gui.colors;
            else
                colors = self.h.ica_coherence.get_colors();
            end
            
            self.set_viz_colors(colors);
        end
        
        function run_postprocessing(self)
            % Runs post-processing on the ICA data.
            
            if self.data(self.gui.current_trial).stage < self.IcaStage
                disp('Run ICA first');
                return;
            end
            
        end
        
        function clear_postprocessing(self)
            
        end
        
        function clear_visualization(self)
            disp('clear_visualization');
            
            self.data(self.gui.current_trial).viz.im_data = [];
            self.data(self.gui.current_trial).viz.component_color_map = [];
            self.data(self.gui.current_trial).viz.component_colors = [];
        end
        
        function set_viz_colors(self, colors)
            % set_viz_colors(self, colors): sets the colors for each IC for
            % the visualization.
            %
            % So whatever the function, there should be 1 color per IC. The
            % color is taken as RGB, it can just be a scalar, or it can be
            % RGBA (alpha).
            
            if self.data(self.gui.current_trial).stage < self.IcaStage
                disp('Run ICA first.');
                return;
            end
            
            s = self.data(self.gui.current_trial).settings.viz;
            
            self.data(self.gui.current_trial).viz.colors = colors;
            
            self.data(self.gui.current_trial).stage = self.PostProcessingStage;
            
            self.draw_component_viz();
        end
        
        function rois = calc_rois(self)
            % calc_rois(self): calculates the ROIs from the independent
            % components.
            
            if self.data(self.gui.current_trial).stage < self.IcaStage
                disp('Run ICA first');
                return;
            end
            
            
            rois = self.data(self.gui.current_trial).settings.segment.calc_rois_func(self.data(self.gui.current_trial).ica.im_data, self.data(self.gui.current_trial).ica.im_x, self.data(self.gui.current_trial).ica.im_y);
            
            self.create_new_roi_set('IC_Generated_ROIs', true);
            self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set} = rois;
            
            self.h.roi_editor.set_rois(self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set}, false);
            
            self.update();
            
        end
        
        function estimate_clusters(self)
            disp('estimate_clusters');
            
            if self.data(self.gui.current_trial).stage < self.PostProcessingStage
                disp('Run Segmentation first');
                return;
            end
                       
            s = self.data(self.gui.current_trial).settings.cluster;
            
            [feature_matrix, feature_weights] = s.feature_matrix_func(self.data(self.gui.current_trial).ica.ics, self.data(self.gui.current_trial).ica.im_data);
            
            self.data(self.gui.current_trial).cluster.feature_matrix = feature_matrix;
            self.data(self.gui.current_trial).cluster.feature_weights = feature_weights;
            
            self.data(self.gui.current_trial).cluster.similarity_matrix = s.calc_sim_matrix_func(self.data(self.gui.current_trial).cluster.feature_weights, self.data(self.gui.current_trial).cluster.feature_matrix);
            
            [self.data(self.gui.current_trial).cluster.im_data, top3] = s.visualization_func(self.data(self.gui.current_trial).cluster.similarity_matrix, self.data(self.gui.current_trial).ica.im_data);
            
            self.data(self.gui.current_trial).cluster.im_x = self.data(self.gui.current_trial).ica.im_x;
            self.data(self.gui.current_trial).cluster.im_y = self.data(self.gui.current_trial).ica.im_y;
            
            self.data(self.gui.current_trial).cluster.top3 = top3;
            
            %%% Not sure how/when to set this
            self.data(self.gui.current_trial).cluster.cluster_matrix = zeros(size(self.data(self.gui.current_trial).cluster.similarity_matrix));
            % THis is just a hack for testing
            self.data(self.gui.current_trial).cluster.cluster_matrix(1, 5) = 1;
            self.data(self.gui.current_trial).cluster.cluster_matrix(2, [10, 20]) = 1;
            %%%
            
            self.update();
        end
        
        function load_settings(self, filename)
            % load_settings(self, filename): loads settings from a saved
            % file.
            
            disp('load_settings');
        end
        
        function save_settings(self, filename)
            % save_settings(self, filename): saves the settings to a file.
            disp('save_settings');
        end
        
        function edit_preprocessing_settings(self)
            % edit_preprocessing_settings(self): shows the edit
            % preprocessing settings dialog.
            
            self.h.pp_dialog = dialog('Name', 'Edit Preprocessing Settings', 'Units', 'pixels');
            
            self.h.pp_main_vbox = uiextras.VBox('Parent', self.h.pp_dialog, ...
                'Spacing', self.gui.MARGIN, 'Padding', self.gui.MARGIN);
            self.h.pp_settings_grid = uiextras.Grid('Parent', self.h.pp_main_vbox, 'Spacing', self.gui.MARGIN);
            self.h.pp_button_hbox = uiextras.HButtonBox('Parent', self.h.pp_main_vbox, 'Spacing', self.gui.MARGIN);
            
            % The order of these matters, as they are added to the grid
            % based on the order.
            % First column
            uiextras.Empty('Parent', self.h.pp_settings_grid);
            self.h.pp_smooth_label = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'text', 'String', 'Smooth Window:', 'TooltipString', ...
                'Sets dimensions of smooth window - MxNxT', ...
                'HorizontalAlignment', 'left');
            self.h.pp_down_label = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'text', 'String', 'Down Sampling:', 'TooltipString', ...
                'Sets the down sampling in each dimensoin - MxNxT', ...
                'HorizontalAlignment', 'left');
            % Second column
            self.h.pp_M_label = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'text', 'String', 'M', 'TooltipString', ...
                'M corresponds to the rows of the image (vertical)');
            self.h.pp_smooth_M = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'edit', 'String', self.data(self.gui.current_trial).settings.preprocessing.smooth_window(1));
            self.h.pp_down_M = uicontrol('Parent', self.h.pp_settings_grid,...
                'Style', 'edit', 'String', self.data(self.gui.current_trial).settings.preprocessing.down_sample(1));
            
            % Third column
            self.h.pp_N_label = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'text', 'String', 'N', 'TooltipString', ...
                'N corresponds to the columns of th eimage (horizontal)');
            self.h.pp_smooth_N = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'edit', 'String', self.data(self.gui.current_trial).settings.preprocessing.smooth_window(2));
            self.h.pp_down_N = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'edit', 'String', self.data(self.gui.current_trial).settings.preprocessing.down_sample(2));
            
            % Fourth column
            self.h.pp_T_label = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'text', 'String', 'T', 'TooltipString', ...
                'T corresponds to the frames (depth)');
            self.h.pp_smooth_T = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'edit', 'String', self.data(self.gui.current_trial).settings.preprocessing.smooth_window(3));
            self.h.pp_down_T = uicontrol('Parent', self.h.pp_settings_grid, ...
                'Style', 'edit', 'String', self.data(self.gui.current_trial).settings.preprocessing.down_sample(3));
            
            
            self.h.pp_ok_button = uicontrol('Parent', self.h.pp_button_hbox, ...
                'Style', 'pushbutton', 'String', 'OK', 'Callback', @self.pp_settings_cb);
            self.h.pp_cancel_button = uicontrol('Parent', self.h.pp_button_hbox, ...
                'Style', 'pushbutton', 'String', 'Cancel', 'Callback', @self.pp_settings_cancel_cb);
            
            set(self.h.pp_settings_grid, 'ColumnSizes', [-1, 30, 30, 30], 'RowSizes', [30, 30, 30]);
            set(self.h.pp_main_vbox, 'Sizes', [-1, 30]);
            
            fh_pos = get(self.h.fh, 'Position');
            set(self.h.pp_dialog, 'Position', [fh_pos(1) + 100, fh_pos(2) + 100, 300, 200]);
        end
        
        function set_pp_smooth_window(self, smM, smN, smT)
            % set_smooth_window: sets the size of the smoothing convolution
            % window.
            
            if nargin == 2
                % Then the 3 values should all be in smM
                assert(length(smM) == 3);
                smN = smM(2);
                smT = smM(3);
                smM = smM(1);
            elseif nargin < 2 || isempty(smM)
                % Default will be to leave unchanged.
                smM = NaN;
            elseif nargin < 3 || isempty(smN)
                smN = NaN;
            elseif nargin < 4 || isempty(smT)
                smT = NaN;
            end
            
            % Get the old values
            sm_old = self.data(self.gui.current_trial).settings.preprocessing.smooth_window;
            
            % Set the new values
            self.data(self.gui.current_trial).settings.preprocessing.smooth_window = [smM, smN, smT];
            
            % Check for bad values
            nan_vals = isnan(self.data(self.gui.current_trial).settings.preprocessing.smooth_window) ...
                | self.data(self.gui.current_trial).settings.preprocessing.smooth_window < 0;
            if any(nan_vals)
                % Then some of the values are bad/missing, use the old
                % values.
                disp('Some smooth window values bad/missing.');
                self.data(self.gui.current_trial).settings.preprocessing.smooth_window(nan_vals) = sm_old(nan_vals);
            end
            
            % update the gui
            set(self.h.pp_smooth_M, 'String', self.data(self.gui.current_trial).settings.preprocessing.smooth_window(1));
            set(self.h.pp_smooth_N, 'String', self.data(self.gui.current_trial).settings.preprocessing.smooth_window(2));
            set(self.h.pp_smooth_T, 'String', self.data(self.gui.current_trial).settings.preprocessing.smooth_window(3));
        end
        
        function set_pp_down_sample(self, dsM, dsN, dsT)
            % set_down_sample: sets the size of the down sampling
            
            if nargin == 2
                % Then the 3 values should all be in smM
                assert(length(dsM) == 3);
                dsN = dsM(2);
                dsT = dsM(3);
                dsM = dsM(1);
            elseif nargin < 2 || isempty(dsM)
                % Default will be to leave unchanged.
                dsM = NaN;
            elseif nargin < 3 || isempty(dsN)
                dsN = NaN;
            elseif nargin < 4 || isempty(dsT)
                dsT = NaN;
            end
            
            % Get the old values
            ds_old = self.data(self.gui.current_trial).settings.preprocessing.down_sample;
            
            % Set the new values
            self.data(self.gui.current_trial).settings.preprocessing.down_sample = [dsM, dsN, dsT];
            
            % Check for bad values
            nan_vals = isnan(self.data(self.gui.current_trial).settings.preprocessing.down_sample) ...
                | self.data(self.gui.current_trial).settings.preprocessing.down_sample < 0;
            if any(nan_vals)
                % Then some of the values are bad/missing, use the old
                % values.
                disp('Some down sample values bad/missing.');
                self.data(self.gui.current_trial).settings.preprocessing.down_sample(nan_vals) = ds_old(nan_vals);
            end
            
            set(self.h.pp_down_M, 'String', self.data(self.gui.current_trial).settings.preprocessing.down_sample(1));
            set(self.h.pp_down_N, 'String', self.data(self.gui.current_trial).settings.preprocessing.down_sample(2));
            set(self.h.pp_down_T, 'String', self.data(self.gui.current_trial).settings.preprocessing.down_sample(3));
        end
        
        function edit_pca_settings(self)
            
        end
        
        function edit_ica_settings(self)
            % edit_ica_settings(self): shows the edit ica settings dialog.
            
            self.h.ica_dialog = dialog('Name', 'Edit Preprocessing Settings', 'Units', 'pixels');
            
        end
        
        function component = get_current_component(self)
            % Returns the currently selected component
            component = [];
            f = self.h.roi_editor.current_frame;
            
            switch self.data(self.gui.current_trial).stage
                case self.InitStage
                    return
                case self.PreProcessingStage
                    return
                case self.PcaStage
                    component = self.data(self.gui.current_trial).pca.pcs(:, f);
                    return
                case self.IcaStage
                    component = self.data(self.gui.current_trial).ica.ics(:, f);
            end
        end
        
        function lock_current_component(self)
            % self.lock_current_component:
            
            % ok so just get the whatever is plotted on the component axes
            comp_lines = get(self.h.component_axes, 'Children');
            
            for i = 1:length(comp_lines)
                if ~ismember(comp_lines(i), self.gui.locked_components.handle_ids) ...
                        && strcmp(get(comp_lines(i), 'Type'), 'line')
                    % Ok so we don't have this component, so add it to the
                    % list.
                    idx = length(self.gui.locked_components.handle_ids) + 1;
                    
                    self.gui.locked_components.handle_ids(idx) = comp_lines(i);
                    self.gui.locked_components.xdata(:,idx) = get(comp_lines(i), 'XData');
                    self.gui.locked_components.ydata(:,idx) = get(comp_lines(i), 'YData');
                end
            end
            
            self.update();
        end
        
        function clear_locked_components(self)
            self.gui.locked_components.handle_ids = [];
            self.gui.locked_components.xdata = [];
            self.gui.locked_components.ydata = [];
            
            self.update();
        end
        
        function top_idxs = show_best_selected_components(self, rois)
            % This plots the top components with an roi
            
            disp('show_best_selected_components');
            
            if isempty(rois)
                % Then nothing to plot.
                return
            end
            
            im_data = [];
            comp = [];
            im_x = [];
            im_y = [];
            
            if self.gui.d(self.gui.current_trial).display == 4 && self.data(self.gui.current_trial).stage >= self.IcaStage
                % Then view the ICs
                im_data = self.data(self.gui.current_trial).ica.im_data;
                im_x = self.data(self.gui.current_trial).ica.im_x;
                im_y = self.data(self.gui.current_trial).ica.im_y;
                comp = self.data(self.gui.current_trial).ica.ics;
            elseif self.gui.d(self.gui.current_trial).display == 3 && self.data(self.gui.current_trial).stage >= self.PcaStage
                % Then view the PCs
                im_data = self.data(self.gui.current_trial).pca.im_data;
                im_x = self.data(self.gui.current_trial).pca.im_x;
                im_y = self.data(self.gui.current_trial).pca.im_y;
                comp = self.data(self.gui.current_trial).pca.pcs;
            elseif self.data(self.gui.current_trial).stage == self.PcaStage
                % Then view the PCs
                im_data = self.data(self.gui.current_trial).pca.im_data;
                im_x = self.data(self.gui.current_trial).pca.im_x;
                im_y = self.data(self.gui.current_trial).pca.im_y;
                comp = self.data(self.gui.current_trial).pca.pcs;
            elseif self.data(self.gui.current_trial).stage == self.IcaStage
                % Then view the ICs
                im_data = self.data(self.gui.current_trial).ica.im_data;
                im_x = self.data(self.gui.current_trial).ica.im_x;
                im_y = self.data(self.gui.current_trial).ica.im_y;
                comp = self.data(self.gui.current_trial).ica.ics;
            else
                return;
            end
            
            s = self.data(self.gui.current_trial).settings.visualize;
            
            top_idxs = [];
            top_vals = [];
            residuals = [];
            for i = 1:size(rois, 1)
                % Lets just start with the center of the roi.
                cx = interp1(im_x, 1:size(im_data, 2), rois(i, 1), 'nearest');
                cy = interp1(im_y, 1:size(im_data, 1), rois(i, 2), 'nearest');
                
                % @todo: check if in the right range
                
                % Now get the 3 largest scores at the point
                point_data = squeeze(im_data(cy, cx, :));
                
                %                 if s.best_selection_type == 0
                %                     % Then use the data exactly
                %
                %                 elseif s.best_selection_type == 1
                %                     % Use the absolute value
                %                     point_data = abs(point_data);
                %                 elseif s.best_selection_type == 2
                %                     %
                %                 end
                
                [vals, sidx] = sort(point_data, 1, 'descend');
                
                n_best = min(s.num_best_components, length(sidx));
                top_idxs = sidx(1:n_best);
                top_vals = vals(1:n_best);
                
                if length(sidx > n_best)
                    residual_idxs = sidx((n_best+1):end);
                    residuals(i,:) = sum(comp(:, residual_idxs) .* repmat(vals((n_best+1):end)', size(comp, 1), 1), 2);
                end
            end
            
            [top_idxs, ia, ic] = unique(top_idxs);
            top_vals = top_vals(ia);
            
            cla(self.h.component_axes);
            legend(self.h.component_axes, 'off');
            hold(self.h.component_axes, 'all');
            
            data_t = self.data(self.gui.current_trial).im_z(self.data(self.gui.current_trial).pp.im_z);

            
            %             if isfield(self.h, 'component_labels')
            %                 delete(self.h.component_labels);
            %             end
            
            self.h.component_labels = [];
            
            for i = 1:length(top_idxs)
                c = self.gui.locked_colors(mod(i-1, length(self.gui.locked_colors))+1, :);
                
                component = comp(:, top_idxs(i));
                
                if ~s.norm_best_components
                    % Then multiply the component by its value.
                    component = component * top_vals(i);
                end
                
                plot(self.h.component_axes, data_t, component, 'Color', c);
                text_x = 0.95 - (length(top_idxs) + size(residuals, 1) - i) * 0.05;
                self.h.component_labels(i) = text(text_x, 0.9, num2str(top_idxs(i)), ...
                    'Parent', self.h.component_axes, 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'UserData', top_idxs(i), ...
                    'Color', c, 'ButtonDownFcn', @self.component_label_cb);
            end
            
            if s.show_residual
                for i = 1:size(residuals, 1)
                    c = self.gui.locked_colors(mod(i+length(top_idxs)-1, length(self.gui.locked_colors))+1, :);
                    
                    plot(self.h.component_axes, data_t, residuals(i,:), ':', 'Color', c);
                    text_x = 0.95 - (size(residuals, 1) - i) * 0.05;
                    self.h.component_labels(i) = text(text_x, 0.9, 'res', ...
                        'Parent', self.h.component_axes, 'Units', 'normalized', ...
                        'HorizontalAlignment', 'center', ...
                        'Color', c, 'ButtonDownFcn', @self.component_label_cb);
                end
            end
            
            %self.h.lh = legend(self.h.component_axes, 'show');
        end
        
        function create_new_roi_set(self, name, is_component_set)
            % create_new_roi_set(self, name): creates a new roi set.
            
            disp('create_new_roi_set');
            
            if nargin < 3 || isempty(is_component_set)
                is_component_set = false;
            end
            
            if nargin < 2 || isempty(name)
                % Then prompt for a name for the roi set.
                name = inputdlg('Enter name for ROI set:');
                name = name{1};
            end
            
            if isempty(name)
                % Then at this point it was canceled
                return;
            end
            
            % @todo: other checks on name
            
            % Add a new empty set of rois.
            self.data(self.gui.current_trial).rois{end+1} = [];
            
            self.data(self.gui.current_trial).roi_names{length(self.data(self.gui.current_trial).rois)} = name;
            self.data(self.gui.current_trial).is_component_set(length(self.data(self.gui.current_trial).rois)) = is_component_set;
            
            self.gui.d(self.gui.current_trial).current_roi_set = length(self.data(self.gui.current_trial).rois);
            
            self.h.roi_editor.set_rois(self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set});
            
            if is_component_set
                self.h.roi_editor.disable_roi_editing();
            else
                self.h.roi_editor.enable_roi_editing();
            end
            
            self.update();
        end
        
        function delete_roi_set(self, idx)
            % delete_roi_set(self, idx): deletes an roi set.
            
            disp('delete_roi_set');
            
            if nargin < 2
                % Then just delete the currently selected set(?)
                idx = self.gui.d(self.gui.current_trial).current_roi_set;
            end
            
            % prompt?
            
            % Make sure idx is in range
            if idx < 1 || idx > length(self.data(self.gui.current_trial).rois)
                % umm... do nothing?
                disp('Requested ROI set not found. Nothing deleted.');
                return;
            end
            
            self.data(self.gui.current_trial).rois(idx) = [];
            self.data(self.gui.current_trial).roi_names(idx) = [];
            self.data(self.gui.current_trial).is_component_set(idx) = [];
            
            if isempty(self.data(self.gui.current_trial).rois)
                self.build_roi_listbox();
            end
            
            if self.gui.d(self.gui.current_trial).current_roi_set > length(self.data(self.gui.current_trial).rois)
                self.gui.d(self.gui.current_trial).current_roi_set = length(self.data(self.gui.current_trial).rois);
            end
            
            self.h.roi_editor.set_rois(self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set}, false);
            self.update();
        end
        
        function select_roi_set(self, idx)
            % select_roi_set(self, idx): sets the currently selected roi
            % set.
            
            disp('select_roi_set');
            
            if nargin < 2 || isempty(idx)
                idx = 1;
            end
            
            % Check for empty
            if isempty(self.data(self.gui.current_trial).rois)
                self.build_roi_listbox();
            end
            
            % Make sure idx is in range.
            if idx < 1 || idx > length(self.data(self.gui.current_trial).rois)
                % Then idx is out of range.
                idx = length(self.data(self.gui.current_trial).rois);
            end
            
            if idx == self.gui.d(self.gui.current_trial).current_roi_set
                % Then nothing needs to be done.
                return;
            end
            
            self.gui.d(self.gui.current_trial).current_roi_set = idx;
            
            self.h.roi_editor.set_rois(self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set}, false);
            
            if self.data(self.gui.current_trial).is_component_set(idx)
                self.h.roi_editor.disable_roi_editing();
            else
                self.h.roi_editor.enable_roi_editing();
            end
            
            self.update();
        end
        
        function set_ica_spatial_guess(self, masks, which_pcs)
            % set_ica_spatial_guess(self, masks): Sets an initial guess for
            % the ICs given a series of spatial masks.
            %
            % This adjusts the settings.ica.which_pcs to match the number
            % of masks.
            %
            % @param: masks mxnxG array of masks indicating the location of
            % the ics. G is the number of masks.
            % @param: which_pcs the pcs to use for the guess, this must
            % have a length of G. Default is to use 1:G pcs
            
            if nargin < 3 || isempty(which_pcs)
                which_pcs = 1:size(masks, 3);
            end
            
            % Must have already run pca at least.
            if self.data(self.gui.current_trial).stage == self.InitStage || self.data(self.gui.current_trial).stage == self.PreProcessingStage
                disp('Running previous stages...');
                self.run_pca();
            end
            
            pc_scores = self.data(self.gui.current_trial).pca.scores(:, which_pcs)';
            
            % reformat the masks into scores form
            ic_scores = reshape(masks, [], size(masks, 3))';
            
            A_guess = pc_scores / ic_scores;
            
            self.data(self.gui.current_trial).settings.ica.init_guess = A_guess;
            self.data(self.gui.current_trial).settings.ica.which_pcs = which_pcs;
        end
        
        function save_rois(self, filename)
            % save_rois(self, filename): saves the rois to a mat file.
            %
            % If filename is not given then user will be prompted
            
            if nargin < 2 || isempty(filename)
                % Prompt for filename
                [file, path] = uiputfile({'*.mat'}, 'Save ROIs');
                if file == 0
                    % Dialog was canceled
                    return;
                end
                filename = [path file];
            end
            rois = self.data(self.gui.current_trial).rois;
            names = self.data(self.gui.current_trial).roi_names;
            
            save(filename, 'rois', 'names');
        end
        
        function load_rois(self, filename)
            % load_rois(self, filename): loads rois from a mat file.
            
            if nargin < 2 || isempty(filename)
                [file, path] = uigetfile({'*.mat'}, 'Load ROIs');
                
                if file == 0
                    % Dialog was canceled
                    return;
                end
                filename = [path file];
            end
            
            roi_s = load(filename);
            
            for i = 1:length(roi_s.rois)
                self.create_new_roi_set(roi_s.names{i});
                self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set} = roi_s.rois{i};
            end
            
            self.h.roi_editor.set_rois(self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set}, false);
            
            self.update();
        end
        
        function set_cluster(self, ic_idxs)
            % set_cluster(self, ic_idxs): Sets the ics given by ic_idxs as
            % a cluster.
            
            disp('set_cluster');
            
            % @todo: checks on state, cluster
            if nargin < 2 || isempty(ic_idxs)
                % Then the ic_idxs should be the rois that are selected.
                ic_idxs = self.h.roi_editor.selected_rois;
            end
            % @todo: more checks
            
            % Basically, just set the cluster matrix to 1 at the ic_idxs.
            self.data(self.gui.current_trial).cluster.cluster_matrix(ic_idxs, ic_idxs) = 1;
            
            self.update();
        end
        
        function uncluster(self, idxs)
            % uncluster(self, idxs): unclusters the given idxs.
            disp('uncluster');
            
            if nargin < 2 || isempty(idxs)
                % Then idxs are the currently selected rois
                idxs = self.h.roi_editor.selected_rois;
            end
            
            self.data(self.gui.current_trial).cluster.cluster_matrix(idxs, idxs) = 0;
            
            self.update();
        end
        
        function clear_clusters(self)
            % clear_clusters(self): removes all clusters
        end
        
        function load_data(self, filename)
            % load_data(self, filename): loads data from a file.
            %
            % File must be a tif image stack or a mat file with an mxnxt
            % variable.
            
            if nargin < 2 || isempty(filename)
                % Then ask the user for a file with the prompt
                [file_name, path_name] = uigetfile({'*.mat;*.tif;*.tiff', 'Image Files'}, 'Load Data File');
                %[file_name, path_name] = uigetfile();
                
                if file_name == 0
                    % cancelled
                    return;
                end
                filename = [path_name file_name];
            end
            
            set(self.h.stage_status, 'String', 'Loading Data...');
            drawnow;
            
            ext_idx = strfind(filename, '.');
            
            ext = filename((ext_idx(end)+1):end);
            
            if strcmp(ext, 'tif') || strcmp(ext, 'tiff')
                % Ok we should be able to just load a file using tifread
                data = tifread(filename);
                self.add_trial(data);
            elseif strcmp(ext, 'mat')
                % Ok then we need to load the mat file and find the image
                % data.
                data = load(filename);
                
                if isstruct(data)
                    % then [data] should have a field thats the image data
                    fn = fieldnames(data);
                    notfound = true;
                    for i = 1:length(fn)
                        if ndims(data.(fn{i})) == 3
                            % So then this must be the data that we're
                            % looking for.
                            self.add_trial(data.(fn{i}));
                            notfound = false;
                            break;
                        end
                    end
                    
                    if notfound
                        % So if we get to this point then we didn't find
                        % anything suitable for data.
                        disp('No Image data found. Need NxMxT matrix.');
                        return;
                    end
                elseif ndims(data) == 3
                    % then [data] is the image data
                    self.add_trial(data);
                else
                    % then data is not valid.
                    disp('Data file must be MxNxT movie.');
                end
            else
                % Then something is weird...
                disp('ICM: Invalid File.');
            end
            
            % @todo: set the trial name to be the filename here.
            
            self.update();
        end
        
        function set_data(self, im, trial_idx)
            % set_data(self, im): sets the image data.
            %
            % @param: im image data (MxNxt)
            % @param: trial_idx the trial to set the im_data
            
            disp('set_data');
            
            if nargin < 3 || isempty(trial_idx)
                trial_idx = self.gui.current_trial;
            end
            
            % @todo: checks on inputs
            self.init_data(im, trial_idx);
            
            self.update();
        end
        
        function set_frame_times(self, frame_times, trial_idx)
           
            if nargin < 3 || isempty(trial_idx)
                trial_idx = self.gui.current_trial;
            end
            
            % @todo: checks on frame_times
            
            self.data(trial_idx).im_z = frame_times;
            
            self.update();
        end
        
        function add_trial(self, im_data)
            % add_trial(self, im_data): adds a trial to the ICP
            
            disp('add_trial');
            
            if length(self.data) == 1 && self.gui.default_data
                % Then we have defualt data which can be replaced. This
                % should always be the first data, and should only be true
                % if there is 1 thing in the data.
                self.set_data(im_data, 1);
                self.gui.default_data = false;
            else
                self.set_data(im_data, length(self.data)+1);
            end
            
        end
        
        function delete_trial(self, idx)
            % delete_trial(self, idx): removes a trial from the ICP
            
        end
        
        function align_trials(self)
            % align_trials(self): aligns the frames of several trials.
            
            f1 = mean(self.data(1).im_data, 3);
            all_warp = [];
            im_data_all = [];
            frame_ids = []; % which trial each frame belongs to
            im_z = [];
            c = 1;
            
            % Hmm... these should be the same for all the images.
            im_x = self.data(1).im_x;
            im_y = self.data(1).im_y;
            
            for t = 1:length(self.data)
                f1f2 = [];
                f1f2(:,:,1) = f1;
                f1f2(:,:,2) = mean(self.data(t).im_data, 3);
                
                [im_stack, warp] = align_im_stack(f1f2, 20, 3);
                
                all_warp(:,:,t) = warp(:,:,2);
                
                for j = 1:size(self.data(t).im_data, 3)
                    im_data_all(:,:,c) = spatial_interp(self.data(t).im_data(:,:,j), ...
                        all_warp(:,:,t), 'linear', 'affine', ...
                        im_x, im_y);
                    frame_ids(c) = t;
                    %im_z(c) = j;
                    im_z(c) = self.data(t).im_z(j);
                    c = c + 1;
                end
                
                % Get how far it shifts for removal of the edges
                dxy(:,t) = all_warp(:,:,t) * [1;1;1] - [1;1];
            end
            
            max_pos = ceil(max(dxy, [], 2));
            max_neg = ceil(max(-dxy, [], 2));
            
            row_keep = (max_neg(2) + 1):(size(im_data_all, 1) - max_pos(2) - 1);
            col_keep = (max_neg(1) + 1):(size(im_data_all, 2) - max_pos(1) - 1);
            
            % Ok max_pos take out from right and bottom
            
            self.data(1).concat.im_data = im_data_all(row_keep, col_keep, :);
            self.data(1).concat.im_x = col_keep;
            self.data(1).concat.im_y = row_keep;
            self.data(1).concat.im_z = im_z;
            self.data(1).concat.all_warp = all_warp;
            self.data(1).concat.frame_ids = frame_ids;
        end
        
        function set_selected_trial(self, idx)
            % set_selected_trial(self, idx): sets the current trial.
            
            % @todo: checks
            disp('set_selected_trial');
            self.gui.current_trial = idx;
            self.gui.d(self.gui.current_trial).last_display = 0;
            
            % reset the viewer data
            
            % reset the HighDViewers if necessary
            if self.data(self.gui.current_trial).stage >= self.PcaStage
                self.h.pc_pixel_viewer.set_scores(self.data(self.gui.current_trial).pca.scores);
            else
                self.h.pc_pixel_viewer.set_scores([]);
            end
            
            
            if self.data(self.gui.current_trial).stage >= self.IcaStage
                % Then can use the viewer and coherence
                self.h.pc_ica_viewer.set_scores(self.data(self.gui.current_trial).ica.A');
                self.h.ica_coherence.set_data(1:size(self.data(self.gui.current_trial).ica.ics, 1), self.data(self.gui.current_trial).ica.ics');
            else
                self.h.pc_ica_viewer.set_scores([]);
                self.h.ica_coherence.set_data([]);
            end
            
            self.update();
        end
        
        function set_use_wavelets(self, val)
            % set_use_wavelets(self, val): sets whether to use the wavelets
            
            %todo: checks, update the checkbox in the gui
            self.gui.d(self.gui.current_trial).use_wavelets = val;
        end
        
        function reset(self)
            % reset(self); resets to the init stage.
            self.data(self.gui.current_trial).stage = self.InitStage;
            self.data(self.gui.current_trial).pp = [];
            self.data(self.gui.current_trial).pca = [];
            self.data(self.gui.current_trial).ica = [];
            self.update();
        end
        
        function load_session(self, filename)
            % load_session(self, filename): loads an ICP session from a
            % file.
            
            if nargin < 2 || isempty(filename)
                % Then ask the user for a file with the prompt
                [file_name, path_name] = uigetfile({'*.mat;*.icp;', 'ICP Session Files'}, 'Load Session File');
                %[file_name, path_name] = uigetfile();
                
                if file_name == 0
                    % cancelled
                    return;
                end
                filename = [path_name file_name];
            end
            
            % @todo: clear all the data
            
            set(self.h.stage_status, 'String', 'Loading Session...');
            drawnow;
            
            ext = filename((end-2):end);
            
            ds = load(filename);
            
            if isstruct(ds)
                % Ok well it should be a struct no matter what
                if isfield(ds, 'data')
                    % This is the most normal thing that should happen,
                    % this is what should happen on a file that is saved by
                    % the save_session function
                    
                    % delete all of the current settings
                    self.data =[];
                    self.gui.d = [];
                    
                    % reinit the gui states
                    for i = 1:length(ds.data)
                        self.init_gui_display(i);
                    end
                    
                    % Now just set the data
                    self.data = ds.data;
                else
                    % ds could be data itself? but just going to say no for
                    % now
                    disp('data struct not found.');
                    return;
                end
            else
                % Then we have a weird problem...
                disp('Data in file invalid.');
                return;
            end
            
            self.update();
            set(self.h.stage_status, 'String', 'Load Complete');
            drawnow;
        end
        
        function save_session(self, filename)
            % save_session(self, filename): saves the ICP session to a
            % file.
            %
            % @param: filename the name of the file to save the session.
            % Default [] will open an file window
            
            if nargin < 2 || isempty(filename)
                % Then ask the user for a file with the prompt
                [file_name, path_name] = uiputfile({'*.mat;*.icp;', 'ICP Session Files'}, 'Load Session File');
                %[file_name, path_name] = uigetfile();
                
                if file_name == 0
                    % cancelled
                    return;
                end
                filename = [path_name file_name];
            end
            
            set(self.h.stage_status, 'String', 'Saving Session...');
            drawnow;
            
            % First lets get the extension
            if filename(end-3) == '.'
                % Then there is an extension
                ext = filename((end-2):end);
                
                % So now just make sure it is mat or icp
                if strcmp(ext, 'mat') || strcmp(ext, 'icp')
                    % Then we're good.
                else
                    % Then replace the extension
                    filename((end-2):end) = 'icp';
                end
            else
                % Then no extension so add one
                filename = [filename '.icp'];
            end
            
            % Ok, so baically we just save data to the file
            data = self.data;
            
            save(filename, '-mat', '-v7.3', 'data');
            
            set(self.h.stage_status, 'String', 'Session Saved');
            drawnow;
        end
        
        function set_which_pcs(self, which_pcs, trial)
            % set_which_pcs(self, which_pcs): sets the pcs to use for ica.
            
            if nargin < 3 || isempty(trial)
                trial = self.gui.current_trial;
            end
            
            % @todo: check on which_pcs
            
            self.data(trial).settings.ica.which_pcs = which_pcs;
        end
        
        function set_segment_thresh(self, thresh, trial_idx)
            % self.set_segment_thresh(thresh, [trial_idx]): sets the threshold used during
            % segmentation.
            
            if nargin < 3 || isempty(trial_idx)
                trial_idx = self.gui.current_trial;
            end
            
            % @todo: checks on the input
            
            self.data(trial_idx).settings.segment.thresh = thresh;
            
            self.update();
        end
        
        function set_segment_down_size(self, down_size, trial_idx)
            % self.set_down_size(down_size, [trial_idx]): sets the down size parameter
            % used during segmentation.
            
            if nargin < 3 || isempty(trial_idx)
                trial_idx = self.gui.current_trial;
            end
            
            % @todo: checks on the input
            
            self.data(trial_idx).settings.segment.down_size = down_size;
            
            self.update();
        end
        
        function set_post_poly_order(self, poly_order, trial_idx)
            % self.set_post_poly_order(poly_order, [trial_idx]): sets the
            % order of polynomial used to fit the data. Use 0 for no fit.
            
            if nargin < 3 || isempty(trial_idx)
                trial_idx = self.gui.current_trial;
            end
            
            % @todo: checks on input
            
            % poly order must be an integer
            poly_order = round(poly_order);
            
            self.data(trial_idx).settings.post.poly_order = poly_order;
        end
        
        function set_post_smooth_order(self, smooth_order, trial_idx)
            % self.set_post_smooth_order(smooth_order, [trial_idx]): sets
            % the number of samples to use for smoothing. Use 0 for no
            % smoothing.
            
            if nargin < 3 || isempty(trial_idx)
                trial_idx = self.gui.current_trial;
            end
            
            % @todo: checks on input
            
            % smooth order must be an integer
            smooth_order = round(smooth_order);
            
            self.data(trial_idx).settings.post.smooth_order = smooth_order;
        end            
        
        %%%%%%%%%% hgsetget Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
        function set.Parent(self, val)
            set(self.h.panel, 'Parent', double(val))
        end
        
        function val = get.Parent(self)
            val = get(self.h.panel, 'Parent');
        end
        
        %%%%%%%%%% Utility Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function default_settings(self)
            % default_settings(self): sets the settings to the default.
            
            self.data(self.gui.current_trial).settings.concat.align_func = @align_im_stack;
            
            
            %self.settings.preprocessing.block_size = 6;
            self.data(self.gui.current_trial).settings.preprocessing.smooth_window = [6, 6, 1];
            %self.data(self.gui.current_trial).settings.preprocessing.step_size = 2;
            self.data(self.gui.current_trial).settings.preprocessing.down_sample = [1, 1, 1];
            
            self.data(self.gui.current_trial).settings.preprocessing.remove_frames = [];
            
            self.data(self.gui.current_trial).settings.preprocessing.motion_correct_func = @align_im_stack;
            
            self.data(self.gui.current_trial).settings.preprocessing.default_filter_file = 'icp_default_filters.mat';
            self.data(self.gui.current_trial).settings.preprocessing.filter_file = self.data(self.gui.current_trial).settings.preprocessing.default_filter_file;
            
            self.data(self.gui.current_trial).settings.pca.mean_center = 0;
            self.data(self.gui.current_trial).settings.pca.corr_pca = 0;
            
            self.data(self.gui.current_trial).settings.ica.which_pcs = 1:100;
            self.data(self.gui.current_trial).settings.ica.positive_skew = true;
            self.data(self.gui.current_trial).settings.ica.init_guess = -1;
            self.data(self.gui.current_trial).settings.ica.ica_func = 'fastica';
            self.data(self.gui.current_trial).settings.ica.mu = 0.2; % This is a parameter for Cellsort ICA
            
            self.data(self.gui.current_trial).settings.post.poly_order = 0;
            self.data(self.gui.current_trial).settings.post.smooth_order = 0;
            
            self.data(self.gui.current_trial).settings.segment.calc_rois_func = @calc_rois_from_components;
            self.data(self.gui.current_trial).settings.segment.segment_ics_func = @segment_ics;
            self.data(self.gui.current_trial).settings.segment.down_size = 2;
            self.data(self.gui.current_trial).settings.segment.thresh = 3.2;
            self.data(self.gui.current_trial).settings.segment.min_area = 18;
            
            self.data(self.gui.current_trial).settings.viz.map_pow = 2;
            self.data(self.gui.current_trial).settings.viz.color_pow = 2;
            self.data(self.gui.current_trial).settings.viz.alpha = 0.25;
            
            self.data(self.gui.current_trial).settings.cluster.feature_matrix_func = @make_feature_matrix;
            self.data(self.gui.current_trial).settings.cluster.feature_weights = 1;
            self.data(self.gui.current_trial).settings.cluster.visualization_func = @viz_best3;
            self.data(self.gui.current_trial).settings.cluster.calc_sim_matrix_func = @(b, x) sum(repmat(b, [size(x,1), size(x,2), 1]) .* x, 3);
            
            
            self.data(self.gui.current_trial).settings.visualize.norm_best_components = false;
            self.data(self.gui.current_trial).settings.visualize.num_best_components = 3;
            self.data(self.gui.current_trial).settings.visualize.show_residual = true;
            self.data(self.gui.current_trial).settings.visualize.best_selection_type = 1;
        end
        
        function init_data(self, im_data, trial_idx, isdefault)
            % initializes the data struct and data gui elements
            
            disp('init_data');
            
            if nargin < 2 || isempty(im_data)
                % Then we have no im_data, so set the default
                im_data = rand(128,128,10);
            end
            
            if nargin < 3 || isempty(trial_idx)
                % Then add a new struct to the end.
                trial_idx = length(self.data) + 1;
            end
            
            if nargin < 4 || isempty(isdefault)
                isdefault = false;
            end
            
            self.gui.default_data = isdefault;
            
            self.data(trial_idx).im_data = im_data;
            self.data(trial_idx).im_x = 1:size(im_data, 2);
            self.data(trial_idx).im_y = 1:size(im_data, 1);
            self.data(trial_idx).im_z = 1:size(im_data, 3);
            self.data(trial_idx).pp = [];
            self.data(trial_idx).pca = [];
            self.data(trial_idx).ica = [];
            self.data(trial_idx).viz = [];
            self.data(trial_idx).segment = [];
            self.data(trial_idx).cluster = [];
            self.data(trial_idx).stage = self.InitStage;
            
            self.data(trial_idx).rois{1} = [];
            self.data(trial_idx).roi_names{1} = 'ROI_set_1';
            self.data(trial_idx).is_component_set = false;
            
            self.init_gui_display(trial_idx);
            
            if self.gui.default_data
                self.data(trial_idx).trial_name = 'Default Data';
                
            else
                self.data(trial_idx).trial_name = ['Trial ' num2str(trial_idx)];
            end
            
            self.gui.current_trial = trial_idx;
            
            % Finally copy the settings or do the default
            if length(self.data) == 1
                % Then just do the default settings
                self.default_settings();
            elseif length(self.data) > 1 && self.gui.current_trial > 1
                % Then copy the settings from the previous trial
                self.data(self.gui.current_trial).settings = self.data(self.gui.current_trial - 1).settings;
            else
                % Then do the default
                self.default_settings();
            end
        end
        
        function init_gui_display(self, trial_idx)
            % Inits the gui state variables that are needed for each trial.
            
            % @todo: use_wavelets may need to be initialized based on the
            % settings.
            self.gui.d(trial_idx).use_wavelets = false;
            self.gui.d(trial_idx).current_roi_set = 1;
            
            self.gui.d(trial_idx).ic_show_viz = true;
            
            % 3d-axis state variables
            self.gui.d(trial_idx).x_pc = 1; % The PC scores to plot on the x-axis
            self.gui.d(trial_idx).y_pc = 2; % The PC scores to plot on the y-axis
            self.gui.d(trial_idx).z_pc = 3; % The PC scores to plot on the z-axis
            
            self.gui.d(trial_idx).display = 1;
            self.gui.d(trial_idx).last_display = 0;
            
            % Keep track of the frame for each of the display panels
            self.gui.d(trial_idx).current_frame = ones(6, 1);
            self.gui.d(trial_idx).levels = nan(2, 3, 6);
        end
        
        function plot_locked_components(self)
            hold(self.h.component_axes, 'on');
            for i = 1:length(self.gui.locked_components.handle_ids)
                c = self.gui.locked_colors(mod(i-1, length(self.gui.locked_colors))+1, :);
                plot(self.h.component_axes, self.gui.locked_components.xdata(:,i), self.gui.locked_components.ydata(:,i), 'Color', c);
            end
        end
        
        function plot_3d(self)
            % plot_3d(self): plots the currently selected components in
            % 3-space.
            disp('plot_3d');
            
%             if self.gui.d(self.gui.current_trial).display == 4 && self.data(self.gui.current_trial).stage == self.IcaStage
%                 % Then view the ICs
%                 sc = reshape(self.data(self.gui.current_trial).ica.im_data, [], size(self.data(self.gui.current_trial).ica.im_data, 3));
%                 self.build_3d_gui_components(self.IcaStage)
%             elseif self.gui.d(self.gui.current_trial).display == 3 && self.data(self.gui.current_trial).stage >= self.PcaStage
%                 % Then view the PCs
%                 sc = self.data(self.gui.current_trial).pca.scores;
%                 self.build_3d_gui_components(self.PcaStage);
%                 
%             elseif self.data(self.gui.current_trial).stage == self.PcaStage
%                 % Then view the PCs
%                 sc = self.data(self.gui.current_trial).pca.scores;
%                 self.build_3d_gui_components(self.PcaStage);
%             elseif self.data(self.gui.current_trial).stage == self.IcaStage
%                 % Then view the ICs
%                 sc = reshape(self.data(self.gui.current_trial).ica.im_data, [], size(self.data(self.gui.current_trial).ica.im_data, 3));
%                 self.build_3d_gui_components(self.IcaStage);
%             else
%                 cla(self.h.pc3_axes);
%                 self.build_3d_gui_components(self.data(self.gui.current_trial).stage);
%                 return;
%             end
%             
%             if isempty(sc)
%                 % Then there's nothing to plot
%                 return;
%             end
%             
%             % Make sure everything is in range
%             if self.gui.d(self.gui.current_trial).x_pc < 1 || self.gui.d(self.gui.current_trial).x_pc > size(sc, 2)
%                 % Just set to 1 for now.
%                 self.gui.d(self.gui.current_trial).x_pc = 1;
%             end
%             if self.gui.d(self.gui.current_trial).y_pc < 1 || self.gui.d(self.gui.current_trial).y_pc > size(sc, 2)
%                 self.gui.d(self.gui.current_trial).y_pc = 1;
%             end
%             if self.gui.d(self.gui.current_trial).z_pc < 1 || self.gui.d(self.gui.current_trial).z_pc > size(sc, 2)
%                 self.gui.d(self.gui.current_trial).z_pc = 1;
%             end
%             
%             xv = sc(:, self.gui.d(self.gui.current_trial).x_pc);
%             yv = sc(:, self.gui.d(self.gui.current_trial).y_pc);
%             zv = sc(:, self.gui.d(self.gui.current_trial).z_pc);
%             
%             [az, el] = view(self.h.pc3_axes);
%             plot3(self.h.pc3_axes, xv, yv, zv, '.k');
%             axis(self.h.pc3_axes, 'vis3d');
%             view(self.h.pc3_axes, az, el);
%             
%             popup_str = get(self.h.x_popup, 'String');
%             xlabel(self.h.pc3_axes, popup_str{self.gui.d(self.gui.current_trial).x_pc});
%             ylabel(self.h.pc3_axes, popup_str{self.gui.d(self.gui.current_trial).y_pc});
%             zlabel(self.h.pc3_axes, popup_str{self.gui.d(self.gui.current_trial).z_pc});
        end
        
        function build_3d_gui_components(self, stage)
            % build_3d_gui_components(self): builds the 3d axis gui
            
            switch stage
                case {self.InitStage, self.PreProcessingStage}
                    % There's nothing to do in this case
                    set(self.h.x_popup, 'String', {'None'}, 'Value', 1);
                    set(self.h.y_popup, 'String', {'None'}, 'Value', 1);
                    set(self.h.z_popup, 'String', {'None'}, 'Value', 1);
                    return;
                case self.PcaStage
                    popup_str = cellfun(@(n) ['PC ' num2str(n)], num2cell(1:size(self.data(self.gui.current_trial).pca.scores, 2)), ...
                        'UniformOutput', 0);
                    set(self.h.x_popup, 'String', popup_str);
                    set(self.h.y_popup, 'String', popup_str);
                    set(self.h.z_popup, 'String', popup_str);
                case self.IcaStage
                    popup_str = cellfun(@(n) ['IC ' num2str(n)], num2cell(1:size(self.data(self.gui.current_trial).ica.im_data, 3)), ...
                        'UniformOutput', 0);
                    set(self.h.x_popup, 'String', popup_str);
                    set(self.h.y_popup, 'String', popup_str);
                    set(self.h.z_popup, 'String', popup_str);
                case self.PostProcessingStage
                    popup_str = cellfun(@(n) ['IC ' num2str(n)], num2cell(1:size(self.data(self.gui.current_trial).ica.im_data, 3)), ...
                        'UniformOutput', 0);
                    set(self.h.x_popup, 'String', popup_str);
                    set(self.h.y_popup, 'String', popup_str);
                    set(self.h.z_popup, 'String', popup_str);
            end
            
            set(self.h.x_popup, 'Value', self.gui.d(self.gui.current_trial).x_pc);
            set(self.h.y_popup, 'Value', self.gui.d(self.gui.current_trial).y_pc);
            set(self.h.z_popup, 'Value', self.gui.d(self.gui.current_trial).z_pc);
        end
        
        function build_roi_listbox(self)
            % build_roi_listbox(self): creates the roi_listbox.
            
            if isempty(self.data(self.gui.current_trial).rois)
                % Then there is nothing in the rois, so create an empty
                % list.
                self.data(self.gui.current_trial).rois{1} = [];
                self.gui.d(self.gui.current_trial).current_roi_set = 1;
                self.data(self.gui.current_trial).roi_names = {};
                self.data(self.gui.current_trial).roi_names{1} = 'ROI_set_1';
                self.data(self.gui.current_trial).is_component_set = false;
            end
            
            % Check ranges
            assert(length(self.data(self.gui.current_trial).rois) == length(self.data(self.gui.current_trial).roi_names));
            if self.gui.d(self.gui.current_trial).current_roi_set < 1 || self.gui.d(self.gui.current_trial).current_roi_set > length(self.data(self.gui.current_trial).rois)
                self.gui.d(self.gui.current_trial).current_roi_set = length(self.data(self.gui.current_trial).rois);
            end
            
            set(self.h.roi_listbox, 'String', self.data(self.gui.current_trial).roi_names, 'Value', self.gui.d(self.gui.current_trial).current_roi_set);
        end
        
        function build_trial_listbox(self)
            % build_trial_listbox(self): creates the contents of the trial
            % listbox.
            
            if isempty(self.data)
                % Then something is weird... Perhaps generate the default
                % data?
                disp('no data!');
                return;
            end
            
            % @todo: check ranges
            for i = 1:length(self.data)
                if isfield(self.data(i), 'trial_name') && ~isempty(self.data(i).trial_name)
                    self.gui.trial_names{i} = self.data(i).trial_name;
                else
                    self.data(i).trial_name = ['Trial ' num2str(i)];
                    self.gui.trial_names{i} = self.data(i).trial_name;
                end
            end
            
            set(self.h.trial_listbox, 'String', self.gui.trial_names, 'Value', self.gui.current_trial);
        end
        
        function update_current_roi_set(self)
            % update_current_roi_set(self): synchronizes the current roi
            % set with the roi_editor.
            
            disp('update_current_roi_set');
            
            self.data(self.gui.current_trial).rois{self.gui.d(self.gui.current_trial).current_roi_set} = self.h.roi_editor.rois.xyrra(:,:,1);
            self.update();
        end
        
        function draw_clustered_rois(self)
            % Ok
            disp('draw_clustered_rois');
            
            roi_idx = self.h.roi_editor.selected_rois;
            roi_h = self.h.roi_editor.h.rois;
            
            set(roi_h, 'Color', [0.5, 0.5, 0.5], 'Marker', 'none');
            
            set(roi_h(roi_idx), 'Color', 'w');
            
            % First see if there are other clustered rois
            cluster_idx = [];
            if ~isempty(roi_idx)
                cluster_idx = find(self.data(self.gui.current_trial).cluster.cluster_matrix(roi_idx(1), :));
            end
            
            if ~isempty(cluster_idx)
                % Then highlight the clustered rois
                set(roi_h(cluster_idx), 'Color', [0.9, 0.9, 0.9]);
            end
            
            % Draw the estimates
            
            f = self.h.roi_editor.current_frame;
            
            set(roi_h(f), 'Marker', 's', 'MarkerSize', 1, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'w');
            set(roi_h(self.data(self.gui.current_trial).cluster.top3(f, 1)), 'Marker', 's', 'MarkerSize', 1, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'r');
            set(roi_h(self.data(self.gui.current_trial).cluster.top3(f, 2)), 'Marker', 's', 'MarkerSize', 1, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'g');
            set(roi_h(self.data(self.gui.current_trial).cluster.top3(f, 3)), 'Marker', 's', 'MarkerSize', 1, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b');
            
            
        end
        
        function draw_component_viz(self)
            % draws the component color map onto the ccd image
            
            % @todo: checks
            
            s = self.data(self.gui.current_trial).settings.viz;
            
            if ~isfield(self.data(self.gui.current_trial).viz, 'colors') ...
                    || isempty(self.data(self.gui.current_trial).viz.colors)
                % Then we don't have the data
                disp('Run ICA before trying to draw.');
                self.update();
                return;
            end
            
            colors = self.data(self.gui.current_trial).viz.colors;
            im_data = self.data(self.gui.current_trial).ica.im_data;
            component_color_map = zeros(size(self.data(self.gui.current_trial).ica.im_data, 1), size(self.data(self.gui.current_trial).ica.im_data, 2), 3);
            [s1,s2,s3] = size(self.data(self.gui.current_trial).ica.im_data);
            component_colors = zeros(s1,s2,3,s3);
            
            %%%
            im_data(im_data < 0) = 0;
            %%%
            
            for i = 1:size(self.data(self.gui.current_trial).ica.im_data, 3)
                cc = zeros(size(component_color_map));
                
                if size(colors, 2) == 1
                    % Then we have a scalar, just do red channel for now
                    cc(:,:,1) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i) .^ s.color_pow;
                elseif size(colors, 2) == 3
                    % Then we have RGB                   
                    cc(:,:,1) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i, 1) .^ s.color_pow;
                    cc(:,:,2) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i, 2) .^ s.color_pow;
                    cc(:,:,3) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i, 3) .^ s.color_pow;
                elseif size(colors, 2) == 4
                    % Then we have RGBA
                    cc(:,:,1) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i, 1) .^ s.color_pow .* colors(i, 4);
                    cc(:,:,2) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i, 2) .^ s.color_pow .* colors(i, 4);
                    cc(:,:,3) = norm_range(im_data(:,:,i)) .^ s.map_pow .* colors(i, 3) .^ s.color_pow .* colors(i, 4);
                else
                    % Something is not right....
                    disp('Incorrect input');
                end
                
                component_colors(:,:,:,i) = cc;
                component_color_map = component_color_map + cc;
            end
            
            self.data(self.gui.current_trial).viz.component_color_map = norm_range(component_color_map);
            self.data(self.gui.current_trial).viz.component_colors = component_colors;
            self.data(self.gui.current_trial).viz.ccm_x = self.data(self.gui.current_trial).ica.im_x;
            self.data(self.gui.current_trial).viz.ccm_y = self.data(self.gui.current_trial).ica.im_y;
            %self.data(self.gui.current_trial).viz.ccm_z = self.data(self.gui.current_trial).ica.im_z;
            
            nccd = repmat(mean(self.data(self.gui.current_trial).im_data, 3), [1 1 3]);
            component_resize = zeros(size(nccd));
            
            % These will be real values at some point...
            im_x = 1:size(nccd, 2);
            im_y = 1:size(nccd, 1);
            
            [x,y] = meshgrid(self.data(self.gui.current_trial).viz.ccm_x, self.data(self.gui.current_trial).viz.ccm_y);
            [xi,yi] = meshgrid(im_x, im_y);
            
            component_resize(:,:,1) = interp2(x, y, self.data(self.gui.current_trial).viz.component_color_map(:,:,1), xi, yi);
            component_resize(:,:,2) = interp2(x, y, self.data(self.gui.current_trial).viz.component_color_map(:,:,2), xi, yi);
            component_resize(:,:,3) = interp2(x, y, self.data(self.gui.current_trial).viz.component_color_map(:,:,3), xi, yi);
            
            component_resize(isnan(component_resize)) = 0;
            
            self.data(self.gui.current_trial).viz.im_data = norm_range((1 - s.alpha) * component_resize + s.alpha * norm_range(nccd));
            self.data(self.gui.current_trial).viz.im_x = im_x;
            self.data(self.gui.current_trial).viz.im_y = im_y;
            
            self.gui.d(self.gui.current_trial).last_display = 0;
            
            self.update();
        end
    end
    
end