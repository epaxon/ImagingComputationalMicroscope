classdef HighDViewer < hgsetget
    % class PcaViewer: interactive gui to calculate, view and manipulate
    % high-dimensional coefficients
    %
    % @file: HighDViewer.m
    % @brief: interactive gui for pca analysis.
    % @author: Paxon Frady
    % @created: 3/9/2012
    
    properties
        % gui properties
        h; % graphic object handles.
        gui; % settings for the gui.
        
        % hgsetget properties
        Parent; % The parent of the object
        Position; % The position of the object
        Visible;
        
        % object properties
        data; % The data matrix to do the analysis on. observations x variables.
        class; % Vector describe which class each observation belongs to.
        times; % Vector describing the time-stamp for each observation.
        
        pcs; % The pricipal components.
        scores; % The scores of the data.
        lambda; % The eigenvalues of the pcs.
        
    end % properties
    
    events
        DimensionsChanged; % triggered when different dimensions are selected
        DataClicked;
    end

    methods
        %%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = HighDViewer(parent, data)
            % constructor: creates a new PcaViewer object.
            %
            % @param: parent the parent handle of this object. If no parent
            % is given, a new figure will be created and used as the
            % parent.
            % @param: data
            % @return: self handle to the PcaViewer object.
            
            if nargin < 1
                parent = [];
            end
            if nargin < 2
                data = [];
            end
            
            self = self.init_state();
            self = self.init_gui(parent);
            
            self.set_data(data);
            self.calc_pca();
            self.update();
        end
        
        function self = init_state(self)
            % init_state: initializes the state variables of the gui.
            
            self.h.Position = [0 0 600 600];
            
            self.pcs = [];
            self.scores = [];
            self.lambda = [];
            
            self.gui.colors = [];
            
            % Size parameters
            self.gui.MARGIN = 5;
            self.gui.PANEL_W = 120;
            self.gui.BUTTON_H = 25;
            self.gui.PANEL_M = 5;
            
            self.gui.LABEL_W = 20;
            
            self.gui.prefix = 'PC:';
            
            self.gui.fast_mode = 0;
            self.gui.text_mode = 0;
            
            % Gui state variables
            self.gui.x_pc = 1; % The PC scores to plot on the x-axis
            self.gui.y_pc = 2; % The PC scores to plot on the y-axis
            self.gui.z_pc = 3; % The PC scores to plot on the z-axis            
            
            cc = colorcube(119);
            self.gui.class_colors = cc(mod([0:(length(cc)-1)] * 10 + 1, 119)+1, :);
            
            self.gui.rotate_rate = 0.05;
            self.gui.rotate_angle_step = 2;
            self.gui.rotate_timer = timer('TimerFcn', @self.rotate_timer_cb, ...
                                          'ExecutionMode', 'fixedRate', ...
                                          'Period', self.gui.rotate_rate);
        end
        
        function self = init_gui(self, parent)
            % init_gui: initializes the gui objects.
            %
            % @param: parent the parent handle of this object. Default is
            % to create a new figure. Use [] for default.
            
            if nargin < 2 || isempty(parent)
                % No parent given, then make a new figure as the parent.
                parent = figure;
                set(parent, 'Position', [100, 100, self.h.Position(3), self.h.Position(4)]);
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
            %self.gui.fen = FigureEventNotifier(self.h.fh);
            %addlistener(self.gui.fen, 'WindowKeyPress', @self.window_key_press_cb);
            
            % Create the main panel.
            %self.h.panel = uipanel(self.Parent, 'Units', 'pixels');
            %set(self.h.panel, 'BorderType', 'none');

            self.h.panel = uiextras.BoxPanel('Parent', self.h.parent, 'Title', 'Component Viewer');
            
            % Axes to display three PCs
            self.h.pc_axes = axes('Units', 'normalized', 'OuterPosition', [0 0 1 1]);           
            % Axes to display the x PC
            %self.h.xpc_axes = axes('Units', 'pixels');
            %set(self.h.xpc_axes, 'YTick', [], 'XTick', []);
            % Axes to display the eigenvalues
            %self.h.eig_axes = axes('Units', 'pixels');
            %set(self.h.eig_axes, 'YTick', [], 'XTick', []);
            
            self.h.plot3_h = [];
            
            % Popups for the plot.
            self.h.x_popup = uicontrol('Style', 'popupmenu', ...
                'Units', 'pixels', 'String', {'None'});
            self.h.y_popup = uicontrol('Style', 'popupmenu', ...
                'Units', 'pixels', 'String', {'None'});
            self.h.z_popup = uicontrol('Style', 'popupmenu', ...
                'Units', 'pixels', 'String', {'None'});
            set(self.h.x_popup, 'Callback', @self.x_popup_cb);
            set(self.h.y_popup, 'Callback', @self.y_popup_cb);
            set(self.h.z_popup, 'Callback', @self.z_popup_cb);
            
            % Buttons to auto-rotate to the 2-d plots.
            self.h.xy_button = uicontrol('Style', 'pushbutton', ...
                'Units', 'pixels', 'String', 'xy', 'Callback', @self.xy_button_cb);
            self.h.yz_button = uicontrol('Style', 'pushbutton', ...
                'Units', 'pixels', 'String', 'yz', 'Callback', @self.yz_button_cb);
            self.h.zx_button = uicontrol('Style', 'pushbutton', ...
                'Units', 'pixels', 'String', 'xz', 'Callback', @self.zx_button_cb);
            
            % Labels for the plot controls. Even though these are labels,
            % strange things were happening when I didn't keep the handles.
            self.h.xl = uicontrol('Style', 'text', 'String', 'X:');
            self.h.yl = uicontrol('Style', 'text', 'String', 'Y:');
            self.h.zl = uicontrol('Style', 'text', 'String', 'Z:');
            
            
            % List box to display and edit the class colors.
%             self.h.class_listbox = uicontrol('Style', 'listbox', ...
%                 'Units', 'pixels', 'String', {'None'}, 'Callback', @self.class_listbox_cb);
%             
            % Toggle button to turn continuous rotation on and off.
            self.h.rotate_toggle = uicontrol('Style', 'togglebutton', ...
                'Units', 'pixels', 'String', 'Rotate', 'Callback', @self.rotate_toggle_cb);
            
            
            % Buttons to recalculate the principal components.
%             self.h.recalc_button = uicontrol('Style', 'pushbutton', ...
%                 'Units', 'pixels', 'String', 'Recalc PCA', 'Callback', @self.recalc_button_cb);
%             self.h.reset_button = uicontrol('Style', 'pushbutton', ...
%                 'Units', 'pixels', 'String', 'Reset', 'Callback', @self.reset_button_cb);            
%             
%             % Double-scroll to change the time ranges.
%             self.h.time_scroll = DoubleScroll(self.h.panel.double());
%             addlistener(self.h.time_scroll, 'SelectionChanged', @self.time_scroll_cb);            
%             
            self = self.uiextras_layout();
        end
        
        function self = uiextras_layout(self)
            
            self.h.pc3_main_hbox = uiextras.HBoxFlex();
            self.h.pc3_control_rotate_vbox = uiextras.VBox();
            self.h.pc3_control_panel = uiextras.BoxPanel('Title', '3D Plot Controls');
            self.h.pc3_control_grid = uiextras.Grid();
            
            % 3D plot hierarchy
            set(self.h.pc3_main_hbox, 'Parent', self.h.panel);
            
            set(self.h.pc_axes, 'Parent', self.h.pc3_main_hbox.double());
            set(self.h.pc3_control_rotate_vbox, 'Parent', self.h.pc3_main_hbox);
            
            set(self.h.pc3_control_panel, 'Parent', self.h.pc3_control_rotate_vbox);
            set(self.h.rotate_toggle, 'Parent', self.h.pc3_control_rotate_vbox.double());
            
            set(self.h.pc3_control_grid, 'Parent', self.h.pc3_control_panel);
            
            set(self.h.xl, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.yl, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.zl, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.x_popup, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.y_popup, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.z_popup, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.xy_button, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.yz_button, 'Parent', self.h.pc3_control_grid.double());
            set(self.h.zx_button, 'Parent', self.h.pc3_control_grid.double());
            
            set(self.h.pc3_control_grid,...
                'ColumnSizes', [self.gui.LABEL_W, -1, self.gui.LABEL_W],...
                'RowSizes', [self.gui.BUTTON_H, self.gui.BUTTON_H, self.gui.BUTTON_H]);
            set(self.h.pc3_control_rotate_vbox, 'Sizes', [-1, self.gui.BUTTON_H]);
            set(self.h.pc3_main_hbox, 'Sizes', [-4, -1]);
            
        end
        
        function self = reset_layout(self)
            % reset_layout: resets the gui object's and their positions.
            AX_H = self.Position(4) - 2 * self.gui.BUTTON_H - 3 * self.gui.MARGIN;
            AX_W = self.Position(3) - self.gui.PANEL_W - 3 * self.gui.MARGIN;
            AX_B = 2 * self.gui.MARGIN + 2 * self.gui.BUTTON_H;
            
            PANEL_L = AX_W + 2 * self.gui.MARGIN;            
            PANEL_B = @(N) AX_H + self.gui.MARGIN - N * (self.gui.BUTTON_H + self.gui.PANEL_M);
            
            LABEL_W = 20;
            POPUP_W = self.gui.PANEL_W - 2 * LABEL_W;
            
            %%% Axes
            xpc_W_ratio = 2 / 3;
            axis(self.h.pc_axes, 'vis3d');
            %set(self.h.pc_axes, 'OuterPosition', [self.gui.MARGIN, AX_B, AX_W, AX_H]);
            set(self.h.pc_axes, 'Position', [self.gui.MARGIN, AX_B, AX_W, AX_H]);
            
            
            set(self.h.xpc_axes, 'Position', [self.gui.MARGIN, self.gui.MARGIN, AX_W * xpc_W_ratio - self.gui.PANEL_M, 2 * self.gui.BUTTON_H]);
            set(self.h.eig_axes, 'Position', [self.gui.MARGIN + AX_W * xpc_W_ratio, self.gui.MARGIN, AX_W * (1 - xpc_W_ratio), 2 * self.gui.BUTTON_H]);
            %%%
            
            %%% The plot control buttons
            set(self.h.xl, 'Position', [PANEL_L, PANEL_B(1), LABEL_W, self.gui.BUTTON_H]);
            set(self.h.x_popup, 'Position', [PANEL_L+LABEL_W, PANEL_B(1), POPUP_W, self.gui.BUTTON_H]);
            set(self.h.xy_button, 'Position', [PANEL_L+LABEL_W+POPUP_W, PANEL_B(1), LABEL_W, self.gui.BUTTON_H]);
            
            set(self.h.yl, 'Position', [PANEL_L, PANEL_B(2), LABEL_W, self.gui.BUTTON_H]);
            set(self.h.y_popup, 'Position', [PANEL_L+LABEL_W, PANEL_B(2), POPUP_W, self.gui.BUTTON_H]);
            set(self.h.yz_button, 'Position', [PANEL_L+LABEL_W+POPUP_W, PANEL_B(2), LABEL_W,self.gui.BUTTON_H]);
            
            set(self.h.zl, 'Position', [PANEL_L, PANEL_B(3), LABEL_W, self.gui.BUTTON_H]);
            set(self.h.z_popup, 'Position', [PANEL_L+LABEL_W, PANEL_B(3), POPUP_W, self.gui.BUTTON_H]);
            set(self.h.zx_button, 'Position', [PANEL_L+LABEL_W+POPUP_W, PANEL_B(3), LABEL_W, self.gui.BUTTON_H]);            
            %%%
            
            % Class listbox
            set(self.h.class_listbox, 'Position', [PANEL_L, PANEL_B(8), self.gui.PANEL_W, self.gui.BUTTON_H * 4]);            
            
            % time double scroll
            set(self.h.time_scroll, 'Position', [PANEL_L, PANEL_B(10), self.gui.PANEL_W, self.gui.BUTTON_H]);
            
            % Rotate toggle button
            set(self.h.rotate_toggle, 'Position', [PANEL_L, PANEL_B(12), self.gui.PANEL_W, self.gui.BUTTON_H]);
            
            % Calc buttons
            set(self.h.reset_button, 'Position', [PANEL_L, self.gui.MARGIN, self.gui.PANEL_W, self.gui.BUTTON_H]);
            set(self.h.recalc_button, 'Position', [PANEL_L, self.gui.MARGIN + self.gui.BUTTON_H, self.gui.PANEL_W, self.gui.BUTTON_H]);
            
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function x_popup_cb(self, sh, ed)
            % x_popup_cb: callback for when x popup is changed.
            
            v = get(sh, 'Value');
            self.gui.x_pc = v;
            
            % Now make sure y, z aren't x.
            if self.gui.y_pc == self.gui.x_pc
                % Then y is equal to x
                for i = 1:size(self.pcs, 2)
                    if i ~= self.gui.x_pc && i ~= self.gui.z_pc
                        self.gui.y_pc = i;
                        break;
                    end 
                end
            end
            if self.gui.z_pc == self.gui.x_pc
                % Then z is equal to x
                for i = 1:size(self.pcs, 2)
                    if i ~= self.gui.x_pc && i ~= self.gui.y_pc
                        self.gui.z_pc = i;
                        break;
                    end 
                end
            end
            self.update();
            notify(self, 'DimensionsChanged');
        end
        
        function y_popup_cb(self, sh, ed)
            % y_popup_cb: callback for when y popup is changed.
            
            v = get(sh, 'Value');
            self.gui.y_pc = v;
            
            % Now make sure x, z aren't y.
            if self.gui.x_pc == self.gui.y_pc
                % Then x is equal to y
                for i = 1:size(self.pcs, 2)
                    if i ~= self.gui.y_pc && i ~= self.gui.z_pc
                        self.gui.x_pc = i;
                        break;
                    end 
                end
            end
            if self.gui.z_pc == self.gui.y_pc
                % Then z is equal to y
                for i = 1:size(self.pcs, 2)
                    if i ~= self.gui.y_pc && i ~= self.gui.x_pc
                        self.gui.z_pc = i;
                        break;
                    end 
                end
            end
            self.update();
            notify(self, 'DimensionsChanged');
        end
        
        function z_popup_cb(self, sh, ed)
            % z_popup_cb: callback for when z popup is changed.
            
            v = get(sh, 'Value');
            self.gui.z_pc = v;
            
            % Now make sure y, x aren't z.
            if self.gui.y_pc == self.gui.z_pc
                % Then y is equal to z
                for i = 1:size(self.pcs, 2)
                    if i ~= self.gui.x_pc && i ~= self.gui.z_pc
                        self.gui.y_pc = i;
                        break;
                    end 
                end
            end
            if self.gui.x_pc == self.gui.z_pc
                % Then x is equal to z
                for i = 1:size(self.pcs, 2)
                    if i ~= self.gui.z_pc && i ~= self.gui.y_pc
                        self.gui.x_pc = i;
                        break;
                    end 
                end
            end
            self.update();
            notify(self, 'DimensionsChanged');
        end
        
        function xy_button_cb(self, sh, ed)
            % xy_button_cb: callback that rotates pc axes to show xy.
            view(self.h.pc_axes, [0 90]);
        end
        
        function yz_button_cb(self, sh, ed)
            % yz_button_cb: callback that rotates pc axes to show yz.
            view(self.h.pc_axes, [90 0]);
        end
        
        function zx_button_cb(self, sh, ed)
            % zx_button_cb: callback that rotates pc axes to show zx.
            view(self.h.pc_axes, [0 0]);
        end
        
        function class_listbox_cb(self, sh, ed)
            % class_listbox_cb: callback responding to changes in the
            % class_listbox.
        end

        function recalc_button_cb(self, sh, ed)
            % recalc_button_cb: callback when recalc button is pressed.
            self.calc_pca();
        end
        
        function reset_button_cb(self, sh, ed)
            % reset_button_cb: callback when reset button is pressed.
            
            % reset all of the data variables.
            self.set_data(self.data, self.class, self.times);
        end
        
        function time_scroll_cb(self, sh, ed)
            % time_scroll_cb: callback when the time_scroll is changed.
            self.gui.time_range = sh.Value;
            self.update();
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
            [az, el] = view(self.h.pc_axes);
            view(self.h.pc_axes, az + self.gui.rotate_angle_step, el);
        end
        
        function plot_buttondown_cb(self, sh, ed)
            disp('plot_buttondown_cb');
            disp(sh);
            disp(ed);
        end
        
        function data_clicked_cb(self, sh, ed)
            disp('data_clicked_cb');
            
            idx = find(sh == self.h.plot3_h);
            disp(idx);
            
            notify(self, 'DataClicked', DataClickedEvent(idx));
        end
        
        %%%%%%%%%% Main Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function update(self)
            % update: main update function. Matches gui with internal
            % state.
            
            self.plot_scores();
            
            % If there is no pca data, then set the gui up with no data.
            if isempty(self.pcs)
                set(self.h.x_popup, 'Value', 1);
                set(self.h.y_popup, 'Value', 1);
                set(self.h.z_popup, 'Value', 1);
                cla(self.h.pc_axes);
                %cla(self.h.xpc_axes);
                %cla(self.h.eig_axes);
                return;
            end
            
            % Make sure the listboxes are displaying correctly            
            set(self.h.x_popup, 'value', self.gui.x_pc);
            set(self.h.y_popup, 'value', self.gui.y_pc);
            set(self.h.z_popup, 'value', self.gui.z_pc);
            
            % Make sure the time_scroll has the right range.
            %set(self.h.time_scroll, 'Value', self.gui.time_range);
            
            % Plot the x PC
            %self.plot_xpc();
            
            % Plot the eigenvalues
            %self.plot_eig();
        end
        
        function set_data(self, data, class, times)
            % set_data: sets the data.
            %
            % @param: data NxM matrix where N is the number of things and M
            % is the number of samples...@todo: fix this
            
            if nargin < 2
                % Then there was nothing passed as data, so just make it an
                % empty matrix.
                data = [];
            end
            if nargin < 3
                % Then there is no value for class. Set to [], default will
                % be handled by set_class.
                class = [];
            end
            if nargin < 4
                % Then there is no value for times. Set to [], default will
                % be handled by set_times
                times = [];
            end
                
            self.data = data;
            
            %self.set_class(class);
            %self.set_times(times);
            
            self.calc_pca();
        end
        
        function set_class(self, class)
            % set_class:
            %
            % @param: class
            
            if nargin < 2 || isempty(class)
                % Default for class.
                class = ones(size(self.data, 2), 1);
            end
            
            self.class = class;
            
            self.gui.sub_class = self.class;
            
            %self.build_class_listbox();
        end
        
        function set_times(self, times)
            % set_times: 
            %
            % @param: times

            if nargin < 2 || isempty(times)
                % Default for times, based on class.
                times = self.default_times();
            end
            self.times = times;
            
            self.gui.time_range = [min(self.times), max(self.times)];
            
            self.gui.sub_times = self.times;
            
            %self.build_time_scroll();
        end
        
        function set_scores(self, scores)
            % set_scores(self, scores): overrides pca and just sets the
            % scores explicitly
            
            self.scores = scores;
            self.pcs = zeros(1, size(self.scores, 2));
            
            self.build_pc_popup();
            self.update();
        end
        
        function calc_pca(self)
            % calc_pca: calculates the principal components of the data.
            %
            % This function will calculate pca based on the current subset
            % of the data that is selected. Once a subset has been
            % calculated on it cannot be expanded. However, a smaller
            % subset can be viewed by selecting a smaller time-range. To
            % view the whole data set again, you have to reset the data
            % with the reset button. 
%             
%             X = self.get_selected_data();
%             self.gui.ids = 1:size(X, 1);
%             self.gui.missing = [];
%             
%             % If there are columns that have nan values remove them as they
%             % can't go through the pca.
%             [~, col] = find(isnan(X));
%             if ~isempty(col)
%                 % Then there are nan entries. So remove these columns from
%                 % the pca matrix.
%                 self.gui.missing = unique(col);
%                 X(:, self.gui.missing) = [];
%                 self.gui.ids(self.gui.missing) = [];
%             end
%                 
%             zX = zscore(X);
%             
%             %%% This broke moving to 2013a
%             %[self.scores, self.pcs, self.lambda] = princomp(zX);
%             [self.scores, self.pcs, self.lambda] = pca(zX);
%             %%%
%             self.build_pc_popup();
%             self.build_time_scroll();
%             
%             self.update();
        end
        
        function X = get_selected_data(self)
            % get_selected_data: returns the selected subset of data.
            
            if isempty(self.data)
                % Then there is no data.
                X = [];
                return;
            end
            
            time_idxs = (self.times >= self.gui.time_range(1) & self.times <= self.gui.time_range(2));
            
            X = self.data(time_idxs, :);
            self.gui.sub_times = self.times(time_idxs);
            self.gui.sub_class = self.class(time_idxs);
        end
        
        %%%%%%%%%% hgsetget functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function set.Parent(self, val)
            set(self.h.panel, 'Parent', double(val))
        end
        
        function val = get.Parent(self)
            val = double(self.h.panel);
        end
        
        function set.Position(self, val)
            set(self.h.panel, 'Position', val);
        end
        
        function val = get.Position(self)
            val = get(self.h.panel, 'Position');
        end
        
        function set.Visible(self, val)
            set(self.h.panel, 'Visible', val)
        end
        
        function val = get.Visible(self)
            val = get(self.h.panel, 'Visible');
        end
        
        %%%%%%%%%% Utility functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function plot_scores(self)
            % plot_scores(self): plots the currently selected scores.
            
            if isempty(self.scores)
                % Then there's nothing to plot...
                return;
            end
            
            [az, el] = view(self.h.pc_axes);
            
            % @todo: checks on x_pc values
            cols = zeros(size(self.scores, 1), 3);
            
            cols(:, 1) = norm_range(self.scores(:, self.gui.x_pc));
            cols(:, 2) = norm_range(self.scores(:, self.gui.y_pc));
            cols(:, 3) = norm_range(self.scores(:, self.gui.z_pc));
            
            self.gui.current_colors = cols;
            
            tic;
            
            cla(self.h.pc_axes);
            
            hold(self.h.pc_axes, 'on');
            
            if self.gui.fast_mode
                % We're going to plot it like this because it goes way
                % faster than using scatter. This is necessary when you
                % have a lot of data (like pixels in an imaging data set).
                delete(self.h.plot3_h(ishandle(self.h.plot3_h)));
                
                self.h.plot3_h = plot3(self.h.pc_axes, self.scores(:, self.gui.x_pc), ...
                    self.scores(:, self.gui.y_pc), ...
                    self.scores(:, self.gui.z_pc), '.');
                set(self.h.plot3_h, 'ButtonDownFcn', @self.data_clicked_cb);
            else
                delete(self.h.plot3_h(ishandle(self.h.plot3_h)));
                self.h.plot3_h = zeros(1,size(self.scores,1));
                % This way takes a lot more time, but can have the colors
                for i = 1:size(self.scores, 1)
                    if self.gui.text_mode
                        self.h.plot3_h(i) = text(self.scores(i, self.gui.x_pc), ...
                            self.scores(i, self.gui.y_pc), ...
                            self.scores(i, self.gui.z_pc), num2str(i), ...
                            'Parent', self.h.pc_axes, 'Color', cols(i,:), 'HorizontalAlignment', 'center');
                    else
                        self.h.plot3_h(i) = plot3(self.h.pc_axes, self.scores(i, self.gui.x_pc), ...
                            self.scores(i, self.gui.y_pc), ...
                            self.scores(i, self.gui.z_pc), 'o', 'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor', cols(i,:));
                    end
                end
                axis(self.h.pc_axes, [min(self.scores(:,self.gui.x_pc)), max(self.scores(:, self.gui.x_pc)), ...
                    min(self.scores(:,self.gui.y_pc)), max(self.scores(:, self.gui.y_pc)), ...
                    min(self.scores(:,self.gui.z_pc)), max(self.scores(:, self.gui.z_pc))]);
                axis(self.h.pc_axes, 'vis3d');
                axis(self.h.pc_axes, 'square');
                set(self.h.plot3_h, 'ButtonDownFcn', @self.data_clicked_cb);
%                 self.h.scatter3_h = scatter3(self.h.pc_axes, self.scores(:, self.gui.x_pc), ...
%                     self.scores(:, self.gui.y_pc), ...
%                     self.scores(:, self.gui.z_pc), ...
%                     10, cols, 'fill');
%                 set(self.h.scatter3_h, 'ButtonDownFcn', @self.plot_buttondown_cb);
            end
            
%                 
%                 
%                 self.h.scatter_h = scatter3(self.h.pc_axes, self.scores(:, self.gui.x_pc), ...
%                     self.scores(:, self.gui.y_pc), ...
%                     self.scores(:, self.gui.z_pc), ...
%                     10, cols, ...
% %                     'fill', 'Parent', self.h.pc_axes);
%             set(self.h.scatter_h, 'ButtonDownFcn', @self.plot_buttondown_cb);
                
            self.gui.colors = cols;
            
            xlabel(self.h.pc_axes, [self.gui.prefix ' ' num2str(self.gui.x_pc)]);
            ylabel(self.h.pc_axes, [self.gui.prefix ' ' num2str(self.gui.y_pc)]);
            zlabel(self.h.pc_axes, [self.gui.prefix ' ' num2str(self.gui.z_pc)]);
            
            axis(self.h.pc_axes, 'vis3d');
            view(self.h.pc_axes, [az, el]);
            toc;
        end
        
        function plot_pcs(self)
            % plot_pcs: plots the three selected pcs.
            
            if isempty(self.scores)
                % Then there is nothing to plot...
                return;
            end
            
            % Keep the view constant. plot3 will reset the view.
            [az, el] = view(self.h.pc_axes);
            cla(self.h.pc_axes);
            hold(self.h.pc_axes, 'on');
            time_idxs = (self.gui.sub_times >= self.gui.time_range(1) & self.gui.sub_times <= self.gui.time_range(2));
            
            classes = unique(self.gui.sub_class(time_idxs));
            for i = 1:length(classes)
                disp(classes(i));
                idxs = time_idxs;
                plot3(self.scores(:, self.gui.x_pc), ...
                      self.scores(:, self.gui.y_pc), ... 
                      self.scores(:, self.gui.z_pc), ...
                      '.', 'Parent', self.h.pc_axes,...
                      'Color', self.gui.class_colors(classes(i), :));
%                 plot3(self.scores(find(idxs, 1), self.gui.x_pc), ...
%                       self.scores(find(idxs, 1), self.gui.y_pc), ...
%                       self.scores(find(idxs, 1), self.gui.z_pc), ...
%                       'ks', 'Parent', self.h.pc_axes, ...
%                       'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
            end
                           
            xlabel(self.h.pc_axes, ['PC ' num2str(self.gui.x_pc)]);
            ylabel(self.h.pc_axes, ['PC ' num2str(self.gui.y_pc)]);
            zlabel(self.h.pc_axes, ['PC ' num2str(self.gui.z_pc)]);
            
            axis(self.h.pc_axes, 'vis3d');
            view(self.h.pc_axes, [az, el]);
        end
        
        function plot_xpc(self)
            % plot_xpc: plots the x pc on the xpc_axes.
            
            cla(self.h.xpc_axes);
            hold(self.h.xpc_axes, 'on');
            bar(self.h.xpc_axes, self.gui.ids, self.pcs(:, self.gui.x_pc), 'k');
            plot(self.h.xpc_axes, self.gui.missing, zeros(size(self.gui.missing)), 'r.');            
            set(self.h.xpc_axes, 'YTick', [], 'XTick', []);
            axis(self.h.xpc_axes, 'tight');
            title(self.h.xpc_axes, ['PC ' num2str(self.gui.x_pc)]);
        end
        
        function plot_eig(self)
            % plot_eig: plots the eigenvalues on the eig_axes.
            
            bar(self.h.eig_axes, self.lambda, 'k');
            set(self.h.eig_axes, 'YTick', [], 'XTick', []);
            axis(self.h.eig_axes, 'tight');
            title(self.h.eig_axes, 'Eigenvalues');
        end
        
        function times = default_times(self)
            % default_times: 
            
            times = 1:size(self.data, 1);
%             all_classes = unique(self.class);
%             times = zeros(size(self.class));
%             for i = all_classes
%                 isclass = (self.class == i);
%                 
%                 times(isclass) = 1:length(isclass);
%             end
        end
        
        function build_pc_popup(self)
            % build_pc_popup: builds the popup menus to select which pcs to
            % plot.
            
            if isempty(self.pcs)
                % Then there are no pcs.
                set(self.h.x_popup, 'String', {'None'});
                set(self.h.y_popup, 'String', {'None'});
                set(self.h.z_popup, 'String', {'None'});
                return;
            end
            
            % Build a list of strings.
            list = cell(size(self.scores, 2), 1);
            for i = 1:size(self.scores, 2)
                list{i} = [self.gui.prefix ' ' num2str(i)];
            end
            
            set(self.h.x_popup, 'String', list);
            set(self.h.y_popup, 'String', list);
            set(self.h.z_popup, 'String', list);    
        end
        
        function build_class_listbox(self)
            % build_class_listbox: builds the class listnames for the class
            % color listbox.
            
            all_classes = unique(self.class);
            
            if isempty(all_classes)
                % Then there are no classes, so just revert to none.
                set(self.h.class_listbox, 'String', {'None'});
                return;
            end
        
            class_strings = cell(length(all_classes), 1);
            for i = 1:length(all_classes)
                class_strings{i} = ['Class: ' num2str(all_classes(i))];
            end
            
            set(self.h.class_listbox, 'String', class_strings);
        end
        
        function build_time_scroll(self)
            % build_time_scroll: set the time scroll parameters.
            min_time = min(self.gui.sub_times);
            max_time = max(self.gui.sub_times);
            
            if min_time < max_time
                % Then we're good, set the double scroll values.
                detail = min(length(self.gui.sub_times), 100);
                set(self.h.time_scroll, 'Min', min_time, 'Max', max_time, 'MinStep', (max_time-min_time)./detail);
            else
                % Then there's probably no data or bad data, so just set
                % default.
                set(self.h.time_scroll, 'Min', 0, 'Max', 1, 'MinStep', 0.01);
            end
        end
    end

end