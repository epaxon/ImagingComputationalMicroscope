classdef VDoubleScroll < hgsetget
    % class VDoubleScroll: gui object that makes a vertical double scroll bar.
    %    A double scroll bar is a gui tool for selecting a range between a
    %    minimum and a maximum - for instance it can be used to set the
    %    minimum and maximum color limits for an image.
    %
    % @file: VDoubleScroll.m
    % @brief: gui object that creates a double scroll bar.
    % @author: Paxon Frady
    % @created: 6/14/11
    
    properties (AbortSet)
        h; % graphic object handles.
        gui; % settings for the gui.
        
        BgColor; % Background color.
        Color; % Color of the rectangle.
        Position; % Position of the axes.
        Parent;
        Visible; 
        
        MinStep; % Minimum amount difference between
        Value; % The low (Value(1)) and high (Value(2)) values.
        Min = 0; % The minimum
        Max = 1; % The maximum
    end
    
    events
        SelectionChanged; % Whenever the range selected changes.
    end
    
    methods
        %%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = VDoubleScroll(parent)
            % constructor: creates a new DoubleScroll object.
            %
            % @param: parent the handle of the parent of this object. If no
            % parent is given, gcf will be used.
            % @return: self handle to the gui object.
            
            if nargin < 1
                parent = [];
            end
            
            self = self.init_state();
            self = self.init_gui(parent);
            
            self.update();
        end
        
        function self = init_state(self)
            % init_state: initializes the state variables used. This sets
            % the defaults.
            
            self.BgColor = [0.95 0.95 0.95];
            self.Color = [0 0 0];
            self.Position = [50 100 20 300];
            
            self.MinStep = 0.01;
            
            self.Value(1) = self.Min;
            self.Value(2) = self.Max;
            
            self.gui.BUTTON_H = 40;
            self.gui.drag_size = 0.05;
        end
        
        function self = init_gui(self, parent)
            % init_gui: initializes the gui. Creates all of the gui
            % components.
            %
            % @param: parent the parent figure. If none is given, then gcf
            % will be used as the parent.
            
            if nargin < 2 || isempty(parent)
                % No parent given, use gcf.
                parent = gcf;
            end
            
            self.h.parent = parent;
            % Get the parent figure and set it as an event notifier.
            fh = parent;
            while ~strcmp(get(fh, 'Type'), 'figure')
                % The last object is not a figure go up.
                fh = get(fh, 'Parent');
            end
            self.h.fh = fh;
            
            self.h.fen = FigureEventNotifier(self.h.fh);
            
            self.h.panel = uipanel(self.h.parent, 'Units', 'pixels', ...
                'Position', self.Position, 'BorderType', 'none', ...
                'BackgroundColor', self.BgColor);
            
            self.h.ds_axes = axes('Box', 'off', 'XTick', [], 'YTick', [], ...
                'Color', self.BgColor, 'XColor', self.BgColor, 'NextPlot', 'add', ...
                'YColor', self.BgColor, 'Units', 'normalized', 'Position', [0 0 1 1]);
            ylim(self.h.ds_axes, [self.Min self.Max]);
            xlim(self.h.ds_axes, [0 1]);
            self.h.ds_ax_aen = AxesEventNotifier(self.h.ds_axes);
            addlistener(self.h.ds_ax_aen, 'ButtonDown', @self.rect_button_down_cb);
            
            self.h.rect = rectangle('Parent', self.h.ds_axes, ...
                'EdgeColor', self.Color, 'FaceColor', self.Color, ...
                'Position', [0 self.Min 1 self.Max]);
            set(self.h.rect, 'ButtonDownFcn', @self.rect_button_down_cb);
            
            self.h.min_drag_line = plot(self.h.ds_axes, [0 1], ...
                [self.gui.drag_size * (self.Max - self.Min), self.gui.drag_size * (self.Max - self.Min)], ...
                'Color', [0.5 0.5 0.5]);
            self.h.max_drag_line = plot(self.h.ds_axes, [0 1], ...
                [(1 - self.gui.drag_size) * (self.Max - self.Min), (1 - self.gui.drag_size) * (self.Max - self.Min)], ...
                'Color', [0.5 0.5 0.5]);
            
            self.h.min_dec_button = uicontrol('Style', 'pushbutton', 'String', '<', 'Callback', @self.min_dec_cb);
            self.h.min_inc_button = uicontrol('Style', 'pushbutton', 'String', '>', 'Callback', @self.min_inc_cb);
            self.h.max_dec_button = uicontrol('Style', 'pushbutton', 'String', '<', 'Callback', @self.max_dec_cb);
            self.h.max_inc_button = uicontrol('Style', 'pushbutton', 'String', '>', 'Callback', @self.max_inc_cb);
            
            self.h.min_edit = uicontrol('Style', 'edit', 'Callback', @self.min_edit_cb);
            self.h.max_edit = uicontrol('Style', 'edit', 'Callback', @self.max_edit_cb);
            
            self = self.uiextras_layout();
            self.update();
        end
        
        function self = uiextras_layout(self)
            
            self.h.main_vbox = uiextras.VBox();
            
            self.h.max_control_vbox = uiextras.VBox();
            self.h.max_button_hbox = uiextras.HBox();
            
            self.h.min_control_vbox = uiextras.VBox();
            self.h.min_button_hbox = uiextras.HBox();
            
            % Top hierarchy
            set(self.h.main_vbox, 'Parent', self.h.panel);
            set(self.h.max_control_vbox, 'Parent', self.h.main_vbox);
            set(self.h.ds_axes, 'Parent', self.h.main_vbox.double());
            set(self.h.min_control_vbox, 'Parent', self.h.main_vbox);
            
            % Max controls
            set(self.h.max_edit, 'Parent', self.h.max_control_vbox.double());
            set(self.h.max_button_hbox, 'Parent', self.h.max_control_vbox);
            set(self.h.max_dec_button, 'Parent', self.h.max_button_hbox.double());
            set(self.h.max_inc_button, 'Parent', self.h.max_button_hbox.double());
            
            % Min Controls
            set(self.h.min_button_hbox, 'Parent', self.h.min_control_vbox);
            set(self.h.min_dec_button, 'Parent', self.h.min_button_hbox.double());
            set(self.h.min_inc_button, 'Parent', self.h.min_button_hbox.double());
            set(self.h.min_edit, 'Parent', self.h.min_control_vbox.double());
            
            set(self.h.main_vbox, 'Sizes', [self.gui.BUTTON_H, -1, self.gui.BUTTON_H]);
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function rect_button_down_cb(self, source_h, eventdata)
            % rect_button_down_cb: handles when the mouse is pressed on the
            % rectangle.
            
            if self.h.fen.button_down == 4
                % Then the rectangle was double clicked. Make it maximum.
                self.set_max_range();
            else
                self.animate_scroll_drag();
            end
        end
        
        function min_dec_cb(self, source_h, eventdata)
            self.Value(1) = self.Value(1) - self.MinStep;
        end
        
        function min_inc_cb(self, source_h, eventdata)
            self.Value(1) = self.Value(1) + self.MinStep;
        end
        
        function max_dec_cb(self, source_h, eventdata)
            self.Value(2) = self.Value(2) - self.MinStep;
        end
        
        function max_inc_cb(self, source_h, eventdata)
            self.Value(2) = self.Value(2) + self.MinStep;  
        end
        
        function min_edit_cb(self, source_h, eventdata)
            cf = str2num(get(self.h.min_edit, 'String'));
            if ~isempty(cf) && length(cf) == 1
                % Otherwise the input is invalid
                self.Value(1) = cf;
            else
                self.update();
            end
        end
        
        function max_edit_cb(self, source_h, eventdata)
            cf = str2num(get(self.h.max_edit, 'String'));
            if ~isempty(cf) && length(cf) == 1
                % Otherwise the input is invalid
                self.Value(2) = cf;
            else
                self.update();
            end
        end
        
        %%%%%%%%%% Main Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function update(self)
            % Updates the gui to make sure it matches with the internal
            % state.
            % First round to the nearest MinStep value
            v = self.Value;
            %v = round(v ./ self.MinStep) .* self.MinStep;
            
            % Make sure the limits are correct
            v(1) = min(max(v(1), self.Min), self.Max - self.MinStep);
            v(2) = min(max(v(2), v(1) + self.MinStep), self.Max);
            
            %self.Value = v;
            pos = [0, v(1), 1, v(2) - v(1)];
            set(self.h.rect, 'Position', pos); 
            
            min_drag_line_y = pos(2) + self.gui.drag_size * (self.Max - self.Min);
            max_drag_line_y = pos(2) + pos(4) - self.gui.drag_size * (self.Max - self.Min);
            
            if min_drag_line_y > max_drag_line_y
                % Then just do something
                mean_drag_line_y = mean([min_drag_line_y, max_drag_line_y]);
                min_drag_line_y = mean_drag_line_y;
                max_drag_line_y = mean_drag_line_y;
            end
            
            set(self.h.min_drag_line, 'YData', [min_drag_line_y, min_drag_line_y]);
            set(self.h.max_drag_line, 'YData', [max_drag_line_y, max_drag_line_y]);
            
            set(self.h.min_edit, 'String', num2str(self.Value(1), 2));
            set(self.h.max_edit, 'String', num2str(self.Value(2), 2));
            drawnow;
        end
        
        function set_max_range(self)
            self.Value = [self.Min, self.Max];
            %self.update();
        end
        
        function set.Min(self, value)
            if value >= self.Max
                self.Max = value + self.MinStep;
            end
            %self.Value = (self.Max - value) .* (self.Value - self.Min) ./ (self.Max - self.Min) + value;
            
            self.Min = double(value);
            %self.Value(1) = self.Min;
            if ~isempty(self.h)
                ylim(self.h.ds_axes, [self.Min self.Max]);
                self.update();
            end
        end
        
        function set.Max(self, value)
            if value <= self.Min
                self.Min = value - self.MinStep;
            end
            
            %self.Value = value - (value - self.Min).*(self.Max - self.Value) ./ (self.Max - self.Min);
            self.Max = double(value);
            %self.Value(2) = self.Max;
            if ~isempty(self.h)
                ylim(self.h.ds_axes, [self.Min self.Max]);
                self.update();
            end
        end
        
        function set.BgColor(self, value)
            self.BgColor = value;
            
            if isfield(self.h, 'ds_axes')
                set(self.h.ds_axes, 'Color', self.BgColor, ...
                    'XColor', self.BgColor, 'YColor', self.BgColor);
            end
            if isfield(self.h, 'panel')
                set(self.h.panel, 'BackgroundColor', self.BgColor);
            end
        end
        
        function set.Color(self, value)
            if isfield(self.h, 'rect')
                set(self.h.rect, 'FaceColor', value);
                set(self.h.rect, 'EdgeColor', value);
                self.Color = get(self.h.rect, 'FaceColor');
            else
                % hmm... I guess do this.
                self.Color = value;
            end
        end
        
        function set.Position(self, value)
            self.Position = value;
            if isfield(self.h, 'panel')
                set(self.h.panel, 'Position', self.Position);
                
                set(self.h.ds_axes, 'Position', [40 5 self.Position(3) - 80 self.Position(4) - 5])                
                set(self.h.left_dec_h, 'Position', [0 0 20 self.Position(4)]);
                set(self.h.left_inc_h, 'Position', [20 0 20 self.Position(4)]);
                set(self.h.right_dec_h, 'Position', [self.Position(3) - 40 0 20 self.Position(4)]);
                set(self.h.right_inc_h, 'Position', [self.Position(3) - 20 0 20 self.Position(4)]);
            end
        end
        
        function set.Value(self, value)
            %disp(value);
            if isequal(self.Value, value)
                % Then there's nothing to change
                return;
            end
            
            v = min(max(double(value), self.Min), self.Max);
            
            if length(v) == 2
                v(2) = max(v(2), v(1) + self.MinStep);
            end
            
            self.Value = v;
            
            if ~isempty(self.h)
                self.update();
            end
            
            notify(self, 'SelectionChanged');
        end
        
        function self = set.Parent(self, val)
            set(self.h.panel, 'Parent', double(val));
        end
        
        function val = get.Parent(self)
            val = get(self.h.panel, 'Parent');
        end
        
        function set.Visible(self, value)
            if isfield(self.h, 'panel')
                set(self.h.panel, 'Visible', value);
                self.Visible = get(self.h.panel, 'Visible');
            end
        end
        
        %%%%%%%%%% Utility functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function animate_scroll_drag(self)
            point1 = get(self.h.ds_axes, 'CurrentPoint');
            
            py1 = point1(1,2);
            rpos = get(self.h.rect, 'Position');
            
            if (py1 - rpos(2)) < self.gui.drag_size * (self.Max - self.Min)
                % Then we are doing a minimum drag
                set(self.h.fh, 'Pointer', 'bottom');
                pos_change = 1; % 1 for minimum
            elseif (py1 - rpos(2)) > rpos(4) - self.gui.drag_size * (self.Max - self.Min)
                % Then we are doing a maximum drag
                set(self.h.fh, 'Pointer', 'top');
                pos_change = -1; % -1 for maximum
            else
                % Then we are doing a shift
                set(self.h.fh, 'Pointer', 'hand');
                pos_change = 0; % 0 for shift
            end
                        
            new_pos = rpos;
            while self.h.fen.button_down
                point2 = get(self.h.ds_axes, 'CurrentPoint');
                py2 = point2(1,2);
                dy1 = (py2 - py1);
                if pos_change == 1
                    % then we are moving the min
                    new_pos(2) = min(max(rpos(2) + dy1, self.Min), self.Value(2) - self.MinStep);
                    dy2 = rpos(2) - new_pos(2);
                    new_pos(4) = max(min(rpos(4) + dy2, self.Max - new_pos(2)), self.MinStep);
                end
                if pos_change == -1
                    % then we are moving the max.
                    new_pos(4) = max(min(rpos(4) + dy1, self.Max - rpos(2)), self.MinStep);
                end
                if pos_change == 0
                    % then shift.
                    new_pos(2) = min(max(rpos(2) + dy1, self.Min), self.Max - rpos(4));
                end
                
                set(self.h.rect, 'Position', new_pos);
                min_drag_line_y = new_pos(2) + self.gui.drag_size * (self.Max - self.Min);
                max_drag_line_y = new_pos(2) + new_pos(4) - self.gui.drag_size * (self.Max - self.Min);
                
                if min_drag_line_y > max_drag_line_y
                    % Then just do something
                    mean_drag_line_y = mean([min_drag_line_y, max_drag_line_y]);
                    min_drag_line_y = mean_drag_line_y;
                    max_drag_line_y = mean_drag_line_y;
                end
                
                set(self.h.min_drag_line, 'YData', [min_drag_line_y, min_drag_line_y]);
                set(self.h.max_drag_line, 'YData', [max_drag_line_y, max_drag_line_y]);
                
                set(self.h.min_edit, 'String', num2str(new_pos(2), 2));
                set(self.h.max_edit, 'String', num2str(new_pos(2) + new_pos(4), 2));
                drawnow;
            end
            
            self.Value = [new_pos(2), new_pos(2) + new_pos(4)];            
            set(self.h.fh, 'Pointer', 'arrow');
            self.update();
        end
    end
end