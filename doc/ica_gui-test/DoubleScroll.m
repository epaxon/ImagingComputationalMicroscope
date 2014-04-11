classdef DoubleScroll < hgsetget
    % class DoubleScroll: gui object that makes a double scroll bar.
    %    A double scroll bar is a gui tool for selecting a range between a
    %    minimum and a maximum - for instance it can be used to set the
    %    minimum and maximum color limits for an image.
    %
    % @file: DoubleScroll.m
    % @brief: gui object that creates a double scroll bar.
    % @author: Paxon Frady
    % @created: 6/14/11
    
    properties (AbortSet)
        h; % graphic object handles.
        gui; % settings for the gui.
        
        BgColor; % Background color.
        Color; % Color of the rectangle.
        Position; % Position of the axes.
        
        MinStep; % Minimum amount difference between
        Value; % The low (Value(1)) and high (Value(2)) values.
        Min = 0; % The minimum
        Max = 1; % The maximum
        
        fen; % The figure event notifier.
    end
    
    events
        SelectionChanged; % Whenever the range selected changes.
    end
    
    methods
        %%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = DoubleScroll(parent)
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
            self.Position = [50 100 300 40];
            
            self.MinStep = 0.01;
            
            self.Value(1) = self.Min;
            self.Value(2) = self.Max;
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
            
            self.fen = FigureEventNotifier(self.h.fh);
            
            self.h.panel = uipanel(self.h.parent, 'Units', 'pixels', ...
                'Position', self.Position, 'BorderType', 'none', ...
                'BackgroundColor', self.BgColor);
            
            self.h.ds_axes = axes('Parent', self.h.panel);
            set(self.h.ds_axes, 'Box', 'off', 'XTick', [], 'YTick', [], ...
                'Color', self.BgColor, 'XColor', self.BgColor, ...
                'YColor', self.BgColor, 'Units', 'pixels', ...
                'Position', [40 5 self.Position(3) - 80 self.Position(4) - 5]);
            xlim(self.h.ds_axes, [self.Min self.Max]);
            ylim(self.h.ds_axes, [0 1]);
            
            self.h.rect = rectangle('Parent', self.h.ds_axes, ...
                'EdgeColor', self.Color, 'FaceColor', self.Color, ...
                'Position', [self.Min 0 self.Max 1]);
            set(self.h.rect, 'ButtonDownFcn', @self.rect_button_down_cb);
            
            self.h.left_dec_h = uicontrol(self.h.panel, 'Units', 'pixels', ...
                'Position', [0 0 20 self.Position(4)], 'String', '<', 'Callback', @self.left_dec_cb);
            self.h.left_inc_h = uicontrol(self.h.panel, 'Units', 'pixels', ...
                'Position', [20 0 20 self.Position(4)], 'String', '>', 'Callback', @self.left_inc_cb);
            self.h.right_dec_h = uicontrol(self.h.panel, 'Units', 'pixels', ...
                'Position', [self.Position(3) - 40 0 20 self.Position(4)], 'String', '<', 'Callback', @self.right_dec_cb);
            self.h.right_inc_h = uicontrol(self.h.panel, 'Units', 'pixels', ...
                'Position', [self.Position(3) - 20 0 20 self.Position(4)], 'String', '>', 'Callback', @self.right_inc_cb);
            
            self.update();
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function rect_button_down_cb(self, source_h, eventdata)
            % rect_button_down_cb: handles when the mouse is pressed on the
            % rectangle.
            
            if self.fen.button_down == 4
                % Then the rectangle was double clicked. Make it maximum.
                set(self.h.rect, 'Position', [self.Min 0 self.Max 1]);
            end
            
            point1 = get(self.h.ds_axes, 'CurrentPoint');
            
            px1 = point1(1);
            rpos = get(self.h.rect, 'Position');
            
            if (px1 - rpos(1)) < 0.2 * rpos(3)
                % Then we are doing a left drag
                set(self.h.fh, 'Pointer', 'left');
                pos_change = 1; % 1 for left
            elseif (px1 - rpos(1)) > 0.8 * rpos(3)
                % Then we are doing a right drag
                set(self.h.fh, 'Pointer', 'right');
                pos_change = -1; % -1 for right
            else
                % Then we are doing a shift
                set(self.h.fh, 'Pointer', 'hand');
                pos_change = 0; % 0 for shift
            end
            
            new_pos = rpos;
            while self.fen.button_down
                point2 = get(self.h.ds_axes, 'CurrentPoint');
                px2 = point2(1);
                dx1 = (px2 - px1);
                if pos_change == 1
                    % then we are moving left.
                    new_pos(1) = min(max(rpos(1) + dx1, self.Min), self.Value(2) - self.MinStep);
                    dx2 = rpos(1) - new_pos(1);
                    new_pos(3) = max(min(rpos(3) + dx2, self.Max - new_pos(1)), self.MinStep);
                end
                if pos_change == -1
                    % then we are moving right.
                    new_pos(3) = max(min(rpos(3) + dx1, self.Max), rpos(1) + self.MinStep);
                end
                if pos_change == 0
                    % then shift.
                    new_pos(1) = min(max(rpos(1) + dx1, self.Min), self.Max - rpos(3));
                end
                
                set(self.h.rect, 'Position', new_pos);
                drawnow;
            end
            
            self.Value = [new_pos(1), new_pos(1) + new_pos(3)];            
            set(self.h.fh, 'Pointer', 'arrow');
        end
        
        function left_dec_cb(self, source_h, eventdata)
            self.Value(1) = self.Value(1) - self.MinStep;
        end
        
        function left_inc_cb(self, source_h, eventdata)
            self.Value(1) = self.Value(1) + self.MinStep;
        end
        
        function right_dec_cb(self, source_h, eventdata)
            self.Value(2) = self.Value(2) - self.MinStep;
        end
        
        function right_inc_cb(self, source_h, eventdata)
            self.Value(2) = self.Value(2) + self.MinStep;  
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
            
            set(self.h.rect, 'Position', [v(1), 0, v(2) - v(1), 1]);
        end
        
        function set.Min(self, value)
            if value >= self.Max
                self.Max = value + self.MinStep;
            end
            %self.Value = (self.Max - value) .* (self.Value - self.Min) ./ (self.Max - self.Min) + value;
            
            self.Min = value;
            if ~isempty(self.h)
                xlim(self.h.ds_axes, [self.Min self.Max]);
                self.update();
            end
        end
        
        function set.Max(self, value)
            if value <= self.Min
                self.Min = value - self.MinStep;
            end
            
            %self.Value = value - (value - self.Min).*(self.Max - self.Value) ./ (self.Max - self.Min);
            self.Max = value;
            if ~isempty(self.h)
                xlim(self.h.ds_axes, [self.Min self.Max]);
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
            self.Color = value;
            if isfield(self.h, 'rect')
                set(self.h.rect, 'Color', self.Color);
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
            if isequal(self.Value, value)
                % Then there's nothing to change
                return;
            end
            v = min(max(value, self.Min), self.Max);
            
            self.Value = v;
            
            if ~isempty(self.h)
                self.update();
            end
            
            notify(self, 'SelectionChanged');
        end
    end
end