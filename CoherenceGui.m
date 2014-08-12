classdef CoherenceGui < hgsetget
    properties
        % Gui properties.
        h; % graphic object handles.
        gui; % settings for the gui.
        
        % hgsetget properties
        Position; % The size and position of the object.
        Parent; % The parent of the object.
        Visible; 
        
        % object properties.
        data_t; % Vector of data timestamps.
        data; % Matrix of data.
        data_labels; % Cell array of data labels.
        base; % Scalar indicating the base data trace.
        freq_idx; % The current frequency being analyzed.
        significance_level; % The level that is considered significant.
        colors; % The colors of everything.
        zero_phase; % The phase offset.
        
        cmag; % The coherence magnitudes.
        cphase; % The coherence phases.
        freqs; % The frequencies returned by the coherence calculation.
        p1;
        p2;
    end
    
    events
        BaseChanged;
        SigLevelChanged;
        FreqChanged;
        DataClicked;
    end
    
    methods
        %%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = CoherenceGui(parent, data_t, data, data_labels)
            % constructor: creates a new CoherenceGui object.
            %
            % @param: parent the parent handle of this object. If no parent
            % is given, a new figure will be created and used as the
            % parent.
            % @param: data matrix of data values. Each row is a seperate
            % data trace.
            % @param: data_labels cell array of string labels for each data
            % row. Default will number the rows.
            % @return: self handle to CoherenceGui object.
            
            if nargin < 1
                parent = [];
            end
            if nargin < 2
                data_t =[];
            end
            if nargin < 3
                data = [];
            end
            if nargin < 4
                data_labels = {};
            end
            
            self.data_t = data_t;
            self.data = data;
            self.data_labels = data_labels;
            
            self = self.init_state();
            self = self.init_gui(parent);
            
            self.set_data(self.data_t, self.data, self.data_labels);
            self.update();
        end
        
        function self = init_state(self)
            % init_state: initializes the state vars and gui vars.
            self.base = 0; % The None option.
            self.freq_idx = 1;
            self.significance_level = 0.8;
            self.zero_phase = 0;
            
            self.h.Position = [0 0 400 300];
            
            self.gui.MENU_H = 20;
            self.gui.MARGIN = 2;
            
            self.gui.angle_cmap = hsv(360); % Color map for different phases.
            self.gui.angle_shift = 0; % Rotation value for phases.
            self.gui.default_color = [0 0 0]; %[0.5 0.5 0.5];
            
            self.gui.text_mode = 0;
            self.gui.fast_mode = 0;
        end
        
        function self = init_gui(self, parent)
            % init_gui: initializes the gui objects.
            %
            % @param: parent the parent handle of this object. Default is
            % to create a new figure. Use [] for default.
            
            if nargin < 2 || isempty(parent)
                parent = figure;
                set(parent, 'Position', [100 100 self.h.Position(3), self.h.Position(4)]);
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
            self.gui.fen = FigureEventNotifier(self.h.fh);
            
            % Create the main panel
            self.h.panel = uiextras.BoxPanel('Parent', self.h.parent, 'Title', 'Coherence');
            
            % The coherence axes
            self.h.coherence_ax = axes('Units', 'pixels');
            self.draw_coherence_axes();
            self.h.data = [];
            
            self.h.zero_phase_marker = plot(self.h.coherence_ax, 1.1, 0, 's', ...
                'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 10, ...
                'HandleVisibility', 'off');
            set(self.h.zero_phase_marker, 'ButtonDownFcn', @self.zero_phase_marker_cb);
            
            
            % Popup menu to choose the base.
            self.h.base_popup = uicontrol('Style', 'popupmenu', ...
                'Units', 'pixels', 'String', {'None'});
            set(self.h.base_popup, 'Callback', @self.base_popup_cb);
            
            % Slider to choose the frequency.
            self.h.frequency_slider = uicontrol('Style', 'slider');
            set(self.h.frequency_slider, 'Callback', @self.frequency_slider_cb);
            
            % Text box showing the frequency value.
            self.h.frequency_text = uicontrol('Style', 'text');
            
            % Line showing the significance level.
            ph = 0:pi/20:2*pi;
            self.h.sig_level_line = plot(self.h.coherence_ax, ...
                self.significance_level * cos(ph), self.significance_level * sin(ph), ...
                ':r', 'LineWidth', 2, 'HandleVisibility', 'off');
            set(self.h.sig_level_line, 'ButtonDownFcn', @self.sig_level_line_cb);
            
            self = self.uiextras_layout();
        end
        
        function self = uiextras_layout(self)
            
            self.h.main_vbox = uiextras.VBox();
            self.h.control_button_hbox = uiextras.HBox();
            
            set(self.h.main_vbox, 'Parent', self.h.panel);
            
            set(self.h.coherence_ax, 'Parent', self.h.main_vbox.double());
            set(self.h.control_button_hbox, 'Parent', self.h.main_vbox);
            
            set(self.h.base_popup, 'Parent', self.h.control_button_hbox.double());
            set(self.h.frequency_slider, 'Parent', self.h.control_button_hbox.double());
            set(self.h.frequency_text, 'Parent', self.h.control_button_hbox.double());
            
            set(self.h.main_vbox, 'Sizes', [-1 self.gui.MENU_H]);
            set(self.h.control_button_hbox, 'Sizes', [-1 -4 -1]);
        end
        
        function reset_layout(self)
            % reset_layout: positions all of the gui items according to the
            % current position of the object.
            
            set(self.h.panel, 'Position', self.Position);
            
            AX_S = min(self.Position(3), self.Position(4) - self.gui.MENU_H - self.gui.MARGIN);
            
            AX_B = self.gui.MENU_H + self.gui.MARGIN;
            AX_L = (self.Position(3) - AX_S) ./ 2;
            
            set(self.h.coherence_ax, 'Position', [AX_L, AX_B, AX_S, AX_S]);
            
            MENU_W = self.Position(3) ./ 3 - self.gui.MARGIN;
            
            set(self.h.base_popup, 'Position', [self.gui.MARGIN, self.gui.MARGIN,...
                MENU_W, self.gui.MENU_H]);
            set(self.h.frequency_slider, 'Position', [self.gui.MARGIN + MENU_W, self.gui.MARGIN, ...
                MENU_W, self.gui.MENU_H]);
            set(self.h.frequency_text, 'Position', [self.gui.MARGIN + 2 * MENU_W, self.gui.MARGIN, ...
                MENU_W, self.gui.MENU_H]);
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function base_popup_cb(self, sh, ed)
            disp('base_popup_cb');
            self.set_base(get(self.h.base_popup, 'Value') - 1);
        end
        
        function frequency_slider_cb(self, sh, ed)
            fv = round(get(self.h.frequency_slider, 'Value'));
            
            if isempty(self.freqs)
                % Then there are no frequency values.
                self.freq_idx = [];
            else
                self.freq_idx = fv;
            end
            self.update();
            self.notify('FreqChanged');
        end
        
        function sig_level_line_cb(self, sh, ed)
            self.animate_sig_level_change();
            
            self.update();
            
            self.notify('SigLevelChanged');
        end
        
        function zero_phase_marker_cb(self, sh, ed)
            self.animate_zero_phase_change();
            
            self.update();
        end
        
        function data_clicked_cb(self, sh, ed)
            disp('data_clicked_cb');
            
            idx = find(sh == self.h.data);
            disp(idx);
            
            notify(self, 'DataClicked', DataClickedEvent(idx));
        end
        
        %%%%%%%%%% Main Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function update(self)
            % Update the significance line
            disp('CoherenceGui.update');
            
            self.update_sig_level();
            self.update_zero_phase();
           
            % Update the popup
            base_string_list = self.build_base_list();
            set(self.h.base_popup, 'String', base_string_list, 'Value', self.base+1);
            
            % Set the slider vales.
            self.update_frequency_slider();
            
            % Plot the data.
            self.update_coherence_data();
        end
        
        function set_base(self, val)
            % set_base: sets the base value.
            
            % Make sure it is in range.
            val = max(min(val, size(self.data, 1)), 0);
            
            if isequal(self.base, val)
                % There is no change so don't do anythign
                return;
            end
            self.base = val;
            
            self.calculate_coherence();
            self.notify('BaseChanged');            
        end
        
        function self = set_data(self, data_t, data, data_labels)
            % set_data: sets the data that is being analyzed.
            %
            % @param: data_t timestamps of data.
            % @param: data matrix of data, where each row is a trace.
            % @param: data_labels cell array of strings indicating a label
            % for each data point.
            
            if nargin < 3 || isempty(data)
                % No data was given.
                self.data = [];
                self.data_t = [];
                self.data_labels = {};
                self.base = 0;
                self.update();
                return;                
            end
            disp('CoherenceGui.set_data');
            if nargin < 2 || isempty(data_t)
                data_t = 1:size(data, 2);
            end
            
            if nargin < 4 || isempty(data_labels)
                for i = 1:size(data, 1);
                    data_labels{i} = ['Data: ' num2str(i)];
                end
            end
            disp('setting data');
            self.data_t = data_t;
            self.data = data;
            self.data_labels = data_labels;
            % Reset the base
            self.base = max(min(self.base, size(self.data, 1)-1), 0);
            self.calculate_coherence();
            
            self.notify('BaseChanged');
        end
        
        function set_colors(self, colors)
            % set_colors(self, colors): sets the colors of the points.
            %
            % @param: colors Mx3 matrix of color values. M is the number of
            % data points.
            
            if size(colors, 1) ~= size(self.data, 1)
                % Then the colors don't match the data points.
                disp('Number of colors must match number of data points.');                
                return;
            end
            
            self.colors = colors;
            self.update();
        end
        
        function unset_colors(self)
            % unset_colors(self): turns the coloring back to default.
            self.colors = [];
        end
        
        function set_frequency(self, freq)
            % set_frequency(self, freq): sets the current frequency to the
            % nearest value to freq.
            
            if isempty(self.freqs)
                % Then we have not done any of the analysis...
                return;
            end
            
            [~, self.freq_idx] = min(abs(self.freqs - freq));
            
            self.update();
            self.notify('FreqChanged');
        end
        
        function set_frequency_idx(self, freq_idx)
            % set_frequency_idx(self, freq_idx): sets the current frequency
            % to teh given frequency index.
            
            if isempty(self.freqs)
                % Then we have not done any of the analysis...
                return;
            end
            
            % Make sure freq_idx is in range
            if freq_idx < 1 || freq_idx > length(self.freqs)
                % Then out of range.
                disp('freq_idx is out of range!');
                return;
            end
            
            self.freq_idx = freq_idx;
            
            self.update();
            self.notify('FreqChanged');
        end
        
        function set_sig_level_line(self, val)
            % set_sig_level_line(self, val): sets the singificance level to
            % the value given.
            
            % Make sure the level is in range.
            if val < 0 || val > 1
                % Then out of range.
                disp('Significance level is out of range!');
            end
            
            self.significance_level = val;
            
            self.update();
            self.notify('SigLevelChanged');
        end
        
        function [t, d] = get_base_data(self)
            % returns the base data.
            if self.base == 0
                t = [];
                d = [];
                return;
            end
            
            t = self.data_t;
            d = self.data(self.base, :);
        end
        
        function calculate_coherence(self, base)
            % calculate_coherence: calculates the coherence values for the
            % currently selected base data trace.
            %
            % @param: base the data trace to base the coherence. Default is
            % the currently selected base.
            
            if isempty(self.data)
                disp('No data to calculate coherence.');
                return;
            end
            
            self.unset_colors();
            if self.base == 0
                % Then the none option is selected. So do nothing.
                self.cmag = [];
                self.cphase = [];
                self.freqs = [];
                self.update();
                return;
            end
            
            p.Fs = 1 ./ mean(diff(self.data_t));
            try
               [cmag, cphase, cross, p1, p2, f] = coherencyc(...
                   repmat(self.data(self.base, :)', 1, size(self.data', 2)), ...
                   self.data', p);
               self.cmag = cmag .^ 2;
               self.cphase = cphase;
               self.freqs = f;
               self.p1 = p1;
               self.p2 = p2;
            catch error
                warning(['Error in calculating coherence: ' error.message]);
            end
            self.update();
        end
        
        function data_idx = get_sig_coherence(self)
            % get_sig_coherence: returns the indices of the data that has
            % significant coherence.
            
            data_idx = [];
            if isempty(self.cmag)
                self.calculate_coherence();
                if isempty(self.cmag)
                    disp('No Coherence Data');
                    return
                end
            end
            
            data_idx = find(self.cmag(self.freq_idx, :) > self.significance_level);
        end

        function phases = get_phases(self, freq_idx)
            % [phases] = get_phases(self, freq_idx): returns the phases of
            % the data. If freq_idx isn't given, then it defaults to the
            % current freq_idx.
            
            if nargin < 2 || isempty(freq_idx)
                % Then defualt for freq_idx is the current freq_idx.
                freq_idx = self.freq_idx;
            end
            
            phases = [];
            if isempty(self.cphase)
                self.calculate_coherence();
                if isempty(self.cphase)
                    disp('No Coherence Data');
                    return;
                end
            end
            
            phases = self.cphase(freq_idx, :) + self.zero_phase;
        end
        
        function colors = get_colors(self)
            % colors = get_colors(self): returns the currently used colors.
            if ~isempty(self.colors)
                colors = self.colors;
            elseif self.base == 0
                % Then there are no colors.
                colors = [];
            else
                colors = self.get_angle_colors();
            end
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
            set(self.h.panel, 'Visible');
        end
        
        function val = get.Visible(self)
            val = get(self.h.panel, 'Visible');
        end
        
        %%%%%%%%%% Utility Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function draw_coherence_axes(self)
            % draw_coherence_axes: creates the borders and markings for the
            % polar plot.
            
            cla(self.h.coherence_ax);
            hold(self.h.coherence_ax, 'on');
            
            set(self.h.coherence_ax, 'XTick', [], 'YTick', [], 'Box', 'off', ...
                'Color', 'w', 'XColor', 'w', 'YColor', 'w', 'Position', [0 0 1 1]);
            axis(self.h.coherence_ax, 'equal');
            
            ph = 0:pi/20:2*pi;
            
            % Draw a line for the boundary
            plot(self.h.coherence_ax, cos(ph), sin(ph), 'k', 'HitTest', 'off', 'HandleVisibility', 'off');
            
            % Draw border lines
            plot(self.h.coherence_ax, [0 0], [-1 1], 'k', 'HitTest', 'off', 'HandleVisibility', 'off');
            plot(self.h.coherence_ax, [-1 1], [0 0], 'k', 'HitTest', 'off', 'HandleVisibility', 'off');
            
            axis(self.h.coherence_ax, [-1.2, 1.2, -1.2, 1.2]);
        end
        
        function base_string_list = build_base_list(self)
            % build_base_list: makes the string list for the options for
            % base.
            base_string_list = ['None', self.data_labels];
        end
        
        function update_sig_level(self)
            ph = 0:pi/20:2*pi;
            set(self.h.sig_level_line, ...
                'XData', self.significance_level * cos(ph), ...
                'YData', self.significance_level * sin(ph));
        end
        
        function update_zero_phase(self)
             set(self.h.zero_phase_marker, ...
                'XData', 1.1 * cos(self.zero_phase), ...
                'YData', 1.1 * sin(self.zero_phase));
        end
        
        function update_frequency_slider(self)
            % update_frequency_slider: updates the slider values to match
            % the current state.
            
            set(self.h.frequency_slider, 'Min', 1);
            
            if isempty(self.freqs)
                % Then we have no coherence data to browse through.
                set(self.h.frequency_slider, 'Max', 2, 'SliderStep', [0 Inf]);
                set(self.h.frequency_slider, 'Value', 1);
            elseif length(self.freqs) == 1
                % Then we have 1 coherence frequency, this will prob never
                % happen, but if it did, we would get an error.
                set(self.h.frequency_slider, 'Max', 2, 'SliderStep', [0 Inf]);
                set(self.h.frequency_slider, 'Value', 1);
            else
                nf = length(self.freqs);
                
                if isempty(self.freq_idx)
                    % Then we need a good value
                    self.freq_idx = 1;
                end
                
                set(self.h.frequency_slider, 'Max', nf, 'SliderStep', [1./(nf-1), 10./(nf-1)]);
                set(self.h.frequency_slider, 'Value', self.freq_idx);
            end
            
            if ~isempty(self.freq_idx) && ~isempty(self.freqs)
                % Display the currently selected frequency.
                set(self.h.frequency_text, 'String', [num2str(self.freqs(self.freq_idx)), ' Hz']);
            else
                set(self.h.frequency_text', 'String', 'None');
            end
        end
        
        function update_coherence_data(self)
            cla(self.h.coherence_ax);
            if ~isempty(self.data) && ~isempty(self.cmag) && ~isempty(self.cphase)
                cmag = self.cmag(self.freq_idx, :);
                cphase = self.cphase(self.freq_idx, :) + self.zero_phase;
                xd = cmag .* cos(cphase);
                yd = cmag .* sin(cphase);
                
                cols = self.get_colors();
                
                delete(self.h.data(ishandle(self.h.data)));
                self.h.data = zeros(1, length(xd));
                
                if self.gui.fast_mode
                    self.h.data = plot(xd, yd, '.');
                else
                    for i = 1:length(xd)
                        if self.gui.text_mode
                            self.h.data(i) = text(xd(i), yd(i), num2str(i), ...
                                'Color', cols(i,:), 'Parent', self.h.coherence_ax, 'HorizontalAlignment', 'center');
                        else
                            self.h.data(i) = plot(self.h.coherence_ax, xd(i), yd(i),...
                                'o', 'MarkerFaceColor', cols(i,:), 'MarkerEdgeColor', cols(i,:));
                        end
                    end
                    set(self.h.data, 'ButtonDownFcn', @self.data_clicked_cb);
                end
                %self.h.data = scatter(self.h.coherence_ax, xd, yd, '.');
                
                %set(self.h.data, 'CData', self.get_colors());
            end
        end
        
        function animate_sig_level_change(self)
            % animate_sig_level_change: animates a change in the
            % significance level.
            while self.gui.fen.button_down
                point2 = get(self.h.coherence_ax, 'CurrentPoint');
                
                px2 = point2(1);
                py2 = point2(3);
                
                self.significance_level = min(sqrt(px2 .^ 2 + py2 .^ 2), 1);

                self.update_sig_level();
                drawnow;
            end
        end
        
        function animate_zero_phase_change(self)
            % animate_zero_phase_change: animates a change in the zero
            % phase angle.
            
            while self.gui.fen.button_down
                point = get(self.h.coherence_ax, 'CurrentPoint');
                
                px = point(1);
                py = point(3);

                self.zero_phase = atan(py / px);
                
                if px < 0
                    self.zero_phase = self.zero_phase + pi;
                end
                
                self.update_zero_phase();
                self.update_coherence_data();
                drawnow;
            end
            self.update();
        end
        
        function colors = get_angle_colors(self, phases)
            % colors = get_angle_colors(self): returns the colors based on
            % the angle and significance.
            
            if nargin < 2 || isempty(phases)
                sig_idxs = self.get_sig_coherence();
                phases = self.get_phases();
            else
                sig_idxs = 1:length(phases);
            end
            
            colors = repmat(self.gui.default_color, length(phases), 1);
            for i = 1:length(phases)
                if ismember(i, sig_idxs)
                    ph_idx = mod(wrapTo2Pi(phases(i) + self.gui.angle_shift), 2 * pi);
                    colors(i, :) = self.gui.angle_cmap(floor(size(self.gui.angle_cmap, 1) * ph_idx ./ 2 ./ pi) + 1, :);
                end
            end
        end
    end
end