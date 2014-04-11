classdef RoiEditor < hgsetget
    % class RoiEditor: interactive gui to edit rois for image processing
    % data.
    %
    % @file: RoiEditor.m
    % @brief: interactive gui to edit rois for image processing
    % @author: Paxon Frady
    % @created: 9/27/2011
    
    properties
        % gui properties
        h; % graphic object handles.
        gui; % settings for the gui.
        
        % hgsetget properties
        Position; % The size and position of the object
        Parent; % The parent of the object
        
        % object properties
        im_data; % The image data.
        im_x; % The x image values.
        im_y; % The y image values.
        rois; % The roi data.
        selected_rois; % The currently selected rois.
        current_frame; % The currently selected frame.
        is_editing_enabled; % Flag for enabling/disabling roi editing.
        color_rois; % Flag for enabling/disabling roi coloring. Disable if you want an outside function to set the colors.
        
        roi_mode; % xyrra rois or blob rois.
        move_mode; % move all frames, all frames after current, or current frame only.
        show_inactive_rois; % whether or not to show the inactive rois.
    end %properties
       
    properties (Constant)
        ShiftAfter = 1;
        ShiftAll = 2;        
        Each = 3;
        MoveAfter = 4;
        MoveAll = 5;
    end
    
    events
        NewRois; % Triggered when new rois are created.
        DeletedRois; % Triggered when rois are deleted.
        AlteredRois; % Triggered when rois are altered.
        SelectionChanged; % Triggered when selected rois change.
        FrameChanged; % Triggered when the current frame is changed.
        LevelsChanged;
    end %events
    
    methods
        %%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = RoiEditor(parent, im_data)
            % constructor: creates a new RoiEditor object.
            %
            % @param: parent the parent handle of this object. If no parent
            % is given, a new figure will be created and used as the
            % parent.
            % @param: im_data an MxNxt or MxNx3xt matrix of image data.
            % @return: self handle to the RoiEditor object.
            
            if nargin < 1
                parent = [];
            end
            if nargin < 2
                im_data = rand(128, 128, 10);
            end
            
            self.im_data = im_data;
            
            self = self.init_state();
            self = self.init_gui(parent);
        end
        
        function self = init_state(self)
            % init_state: initializes the state variables of the gui. 
            
            self.gui.inited = 0;
            
            self.selected_rois = [];
            self.current_frame = 1;
            self.is_editing_enabled = true;
            self.color_rois = true;
            
            self.rois.xyrra = [];
            self.rois.blob = [];
            
            self.Position = [0 0 512 547];
            self.gui.SLIDER_H = 30;
            self.gui.MARGIN = 5;
            self.gui.BUTTON_W = 60;
            self.gui.BUTTON_H = 40;
            self.gui.SCROLL_W = 20;
            
            self.gui.play_button_im = imread('Resources/play_button.png');
            self.gui.pause_button_im = imread('Resources/pause_button.png');
            
            self.gui.play_rate = 0.01;
            self.gui.frame_step = 1;
            self.gui.play_timer = timer('TimerFcn', @self.play_timer_cb, ...
                'ExecutionMode', 'fixedRate', 'Period', self.gui.play_rate);
            
            self.im_x = 1:size(self.im_data, 2);
            self.im_y = 1:size(self.im_data, 1);
            
            self.move_mode = RoiEditor.MoveAll; % all, after, current
            self.show_inactive_rois = 1;
        end
        
        function self = init_gui(self, parent)
            % init_gui: initializes the gui objects.
            %
            % @param: parent the parent handle of this object. Default is
            % to create a new figure. Use [] for default.
            
            if nargin < 2 || isempty(parent)
                % No parent given, then make a new figure as the parent.
                parent = gcf;
                set(parent, 'Position', [100, 100, self.Position(3), self.Position(4)]);
            end
            
            self.h.Parent = parent;
            
            % We must use a figure event notifier, which is attached to the
            % top-most figure. Go up until we get the figure.
            self.h.fh = self.h.Parent;
            while ~strcmp(get(self.h.fh, 'Type'), 'figure')
                % Then the fh object is not a figure, so go up.
                self.h.fh = get(self.h.fh, 'Parent');
            end
            
            % Now fh is the parent figure. Set its event notifier.
            self.gui.fen = FigureEventNotifier(self.h.fh);
            addlistener(self.gui.fen, 'WindowKeyPress', @self.window_key_press_cb);
            
            % Create the main panel.
            %self.h.panel = uipanel('Parent', self.h.Parent, 'Units', 'pixels');
            %set(self.h.panel, 'BorderType', 'none');
            self.h.panel = uiextras.BoxPanel('Parent', self.h.Parent, 'Title', 'ROI Editor');
            
            % Image
            self.h.im_axes = axes('Units', 'normalized', 'Position', [0 0 1 1]);
            set(self.h.im_axes, 'XTick', [], 'YTick', [], 'NextPlot', 'add', 'Box', 'off');       
            self.gui.im_ax_aen = AxesEventNotifier(self.h.im_axes);
            addlistener(self.gui.im_ax_aen, 'ButtonDown', @self.image_button_down_cb);
            %set(self.h.im_axes, 'ButtonDownFcn', @self.image_button_down_cb);
            self.h.im = imagesc(self.get_frame(1), 'Parent', self.h.im_axes);
            set(self.h.im, 'HitTest', 'off'); % Turns off mouse interaction with the image.
            colormap(self.h.im_axes, 'gray');
            axis(self.h.im_axes, 'tight');
            
            % handle for roi lines.
            self.h.rois = [];
            
            % Frame slider.
            self.h.frame_slider = uicontrol('Style', 'slider');
            set(self.h.frame_slider, 'Callback', @self.frame_slider_cb);
            set(self.h.frame_slider, 'Value', 1);
            self.update_frame_slider();
            
            self.h.level_scroll = VDoubleScroll();
            self.h.level_scroll2 = VDoubleScroll();
            self.h.level_scroll3 = VDoubleScroll();
            set(self.h.level_scroll, 'Color', 'r');
            set(self.h.level_scroll2, 'Color', 'g');
            set(self.h.level_scroll3, 'Color', 'b');
            addlistener(self.h.level_scroll, 'SelectionChanged', @self.level_scroll_cb);
            addlistener(self.h.level_scroll2, 'SelectionChanged', @self.level_scroll_cb);
            addlistener(self.h.level_scroll3, 'SelectionChanged', @self.level_scroll_cb);
            
            % Play/pause button
            self.h.play_toggle = uicontrol('Style', 'togglebutton', 'Callback', @self.play_toggle_cb, ...
                'CData', self.gui.play_button_im, 'BackgroundColor', 'w');
            
            % Frame display
            self.h.frame_edit = uicontrol('Style', 'edit', 'Callback', @self.frame_edit_cb);
            set(self.h.frame_edit, 'String', 'none');
            
            % Blob mode check box
            %self.h.blob_mode_checkbox = uicontrol('Style', 'checkbox');
            %set(self.h.blob_mode_checkbox, 'Callback', @self.blob_mode_checkbox_cb);
            %set(self.h.blob_mode_checkbox, 'String', 'Blob Roi Mode');
            %set(self.h.blob_mode_checkbox, 'Value', 0);
            
            % Move mode Push button
            self.h.move_mode_push = uicontrol('Style', 'pushbutton');
            set(self.h.move_mode_push, 'Callback', @self.move_mode_push_cb);
            set(self.h.move_mode_push, 'String', 'ShiftAfter');
            
            % Markers for rotation and resize.
            self.h.rotation_marker = plot(self.h.im_axes, 0, 0, 's', 'Visible', 'off', ...
                'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 10, ...
                'ButtonDownFcn', @self.rotation_marker_cb); 
            self.h.xresize_marker = plot(self.h.im_axes, 0, 0, 's', 'Visible', 'off', ...
                'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 10, ...
                'ButtonDownFcn', @self.xresize_marker_cb);
            self.h.yresize_marker = plot(self.h.im_axes, 0, 0, 's', 'Visible', 'off', ...
                'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 10, ...
                'ButtonDownFcn', @self.yresize_marker_cb);
            
            self = self.uiextras_layout();
            
            self.gui.inited = 1;
            
            self.update();
        end
        
        function self = uiextras_layout(self)
            % self = uiextras_layout(self): Sets the layout of the gui components
            
            self.h.main_vbox = uiextras.VBoxFlex();
            
            self.h.control_hbox = uiextras.HBox();
            self.h.axes_level_hbox = uiextras.HBoxFlex();
            
            % Top-level hierarchy
            set(self.h.main_vbox, 'Parent', self.h.panel);
            set(self.h.axes_level_hbox, 'Parent', self.h.main_vbox);
            set(self.h.control_hbox, 'Parent', self.h.main_vbox);
            
            % axes level
            set(self.h.im_axes, 'Parent', self.h.axes_level_hbox.double());
            set(self.h.level_scroll, 'Parent', self.h.axes_level_hbox.double());
            set(self.h.level_scroll2, 'Parent', self.h.axes_level_hbox.double());
            set(self.h.level_scroll3, 'Parent', self.h.axes_level_hbox.double());
            
            % Control
            set(self.h.play_toggle, 'Parent', self.h.control_hbox.double());
            set(self.h.frame_slider, 'Parent', self.h.control_hbox.double());
            set(self.h.frame_edit, 'Parent', self.h.control_hbox.double());
            set(self.h.move_mode_push, 'Parent', self.h.control_hbox.double());
            
            set(self.h.control_hbox, 'Sizes', [self.gui.BUTTON_W, -1, self.gui.BUTTON_W, self.gui.BUTTON_W]);
            set(self.h.axes_level_hbox, 'Sizes', [-1, self.gui.SCROLL_W, self.gui.SCROLL_W, self.gui.SCROLL_W]);
            set(self.h.main_vbox, 'Sizes', [-1, self.gui.BUTTON_H]);
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function window_key_press_cb(self, source_h, eventdata)
            % Callback for when a keyboard key is pressed.
            
            eventdata = self.gui.fen.last_eventdata;
            
            if self.is_editing_enabled
                % Only allow these keys to work if editing is enabled.
                
                % Control+[ijkl] moves the rois
                if ~isempty(self.selected_rois) && self.gui.fen.is_key_down('control')
                    if strcmp(eventdata.Key, 'j')
                        self.make_roi_move([-1 0]);
                    elseif strcmp(eventdata.Key, 'l')
                        self.make_roi_move([1 0]);
                    elseif strcmp(eventdata.Key, 'i')
                        self.make_roi_move([0 1]);
                    elseif strcmp(eventdata.Key, 'k')
                        self.make_roi_move([0 -1]);
                    end
                end
                
                % Control+[delete backspace] deletes the currently selected
                % rois.
                if self.gui.fen.is_key_down('control') ...
                        && (strcmp(eventdata.Key, 'delete') || strcmp(eventdata.Key, 'backspace'))
                    self.delete_rois(self.selected_rois);
                end
            end
            
            % Control+a selects all rois.
            if self.gui.fen.is_key_down('control') && strcmp(eventdata.Key, 'a')
                self.set_selected_rois(1:self.get_num_rois());
            end
            
            % h toggles show_inactive_rois
            if strcmp(eventdata.Key, 'h')
                self.toggle_show_inactive_rois();
            end
            
            % space moves to the next roi
            if strcmp(eventdata.Key, 'space')
                self.cycle_rois();
            end
            
            % Enable/disable editing
            if self.gui.fen.is_key_down('control') && strcmp(eventdata.Key, 'e')
                if self.is_editing_enabled
                    self.disable_roi_editing();
                else
                    self.enable_roi_editing();
                end
            end
        end
        
        function image_button_down_cb(self, source_h, eventdata)
            
            % First get the mouse position
            point1 = get(self.h.im_axes, 'CurrentPoint');
            fig_point = get(self.h.fh, 'CurrentPoint');
            
            px1 = point1(1);
            py1 = point1(3);
            
            s = []; % the selected rois.
            
            s = self.rois_at_pos([px1 py1]);            
            
            if self.gui.fen.is_key_down('shift')
                % If the shift key is down, then we are adding/removing an
                % roi to/from the selection list. If click was not in an
                % roi and the shift key was down, nothing will happen.
                self.toggle_selected_rois(s); 
            elseif ~isempty(s)
                % The mouse is inside an roi, the shift key is not down.
                % This means we are moving an roi, or clicking for
                % selection.
                self.animate_roi_move([px1, py1], s);                
            else
                % The mouse is not inside an roi, so we are dragging to
                % create one.
                self.animate_roi_creation([px1, py1]);
            end
            
        end
        
        function frame_slider_cb(self, source_h, eventdata)
            % frame_slider_cb: callback of the slider. Gets the slider
            % value and updates the gui.

            cf = round(get(self.h.frame_slider, 'Value'));
            
            self.set_current_frame(cf);
        end
        
        function level_scroll_cb(self, source_h, eventdata)
            %disp('level_scroll_cb');
            self.update();
            notify(self, 'LevelsChanged');
        end
        
        function frame_edit_cb(self, source_h, eventdata)
            cf = str2num(get(self.h.frame_edit, 'String'));
            
            self.set_current_frame(cf);
        end
        
        function blob_mode_checkbox_cb(self, source_h, eventdata)
            
        end
        
        function move_mode_push_cb(self, source_h, eventdata)
            % move_mode_push_cb: Callback of move_mode_push push button.
            % This will cycle through move_modes.
            
            self.cycle_move_mode();
        end   
        
        function rotation_marker_cb(self, source_h, eventdata)
            point1 = get(self.h.im_axes, 'CurrentPoint');
            
            self.animate_roi_rotation([point1(1) point1(3)]);
        end
        
        function xresize_marker_cb(self, source_h, eventdata)
            point1 = get(self.h.im_axes, 'CurrentPoint');

            px1 = point1(1);
            py1 = point1(3);

            self.animate_roi_xresize([px1, py1]);            
        end
        
        function yresize_marker_cb(self, source_h, eventdata)
            point1 = get(self.h.im_axes, 'CurrentPoint');

            px1 = point1(1);
            py1 = point1(3);

            self.animate_roi_yresize([px1, py1]);     
        end
        
        function link_new_rois_cb(self, source_h, eventdata)
            % Add the rois, but don't trigger the event.
            self.add_rois(eventdata.data.rois, false);
        end
        
        function link_selection_changed_cb(self, source_h, eventdata)
            self.set_selected_rois(source_h.selected_rois);
        end
        
        function link_frame_changed_cb(self, source_h, eventdata)       
            % What if the frames are different?
            self.current_frame = source_h.current_frame;
            
            if self.current_frame < 1 || self.current_frame > self.get_num_frames()
                % Something is wrong.
                disp('frame mismatch!');
            end
        end
        
        function link_deleted_rois_cb(self, source_h, eventdata)
            % Remove the rois, but don't trigger the event.
            self.delete_rois(eventdata.data.roi_idxs, false);
        end
        
        function play_toggle_cb(self, source_h, eventdata)
            v = get(self.h.play_toggle, 'Value');
            
            if v
                set(self.h.play_toggle, 'CData', self.gui.pause_button_im)
                start(self.gui.play_timer);
            else
                set(self.h.play_toggle, 'CData', self.gui.play_button_im)
                stop(self.gui.play_timer);
            end
        end
        
        function play_timer_cb(self, source_h, eventdata)
            self.set_current_frame(self.current_frame + self.gui.frame_step);
%             self.current_frame = self.current_frame + self.gui.frame_step;
%             if self.current_frame > size(self.im_data, 3)
%                 % Then start back at the beginning
%                 self.current_frame = 1;
%             end
%             self.update();
%             notify(self, 'FrameChanged');
        end
        
        %%%%%%%%%% Main Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
        function update(self)
            % update: main update function. Matches gui with internal
            % state.
            
            % @todo: checks on the state. Make sure there aren't errors.
                                    
            %set(self.h.im, 'CData', repmat(norm_range(double(self.get_frame(self.current_frame))), [1 1 3]));        
            frame = self.get_nframe(self.current_frame);
            
            if size(frame, 3) == 1
                frame = repmat(frame, [1 1 3]);
            end
            
            set(self.h.im, 'CData', frame, 'XData', [self.im_x(1), self.im_x(end)], 'YData', [self.im_y(1), self.im_y(end)]);               
            
            set(self.h.frame_slider, 'Value', self.current_frame);
            set(self.h.frame_edit, 'String', num2str(self.current_frame));
            
            if ~isempty(self.rois.xyrra)
                [rx, ry] = oval2xy(self.rois.xyrra(:, :, self.current_frame), [], 0);
                set(self.h.rois, 'Visible', 'off');
                set(self.h.rois, 'HitTest', 'off');
                for i = 1:self.get_num_rois()
                    if i > length(self.h.rois)
                        % The handle does not exist so create it.
                        self.h.rois(i, 1) = plot(self.h.im_axes, rx(i,:), ry(i,:), 'LineWidth', 2);
                    else
                        set(self.h.rois(i), 'XData', rx(i, :), 'YData', ry(i, :), 'LineWidth', 2);
                    end
                end                
                set(self.h.rois(self.selected_rois), 'Visible', 'on', 'LineWidth', 4);
                
                if self.show_inactive_rois
                    set(self.h.rois(1:self.get_num_rois()), 'Visible', 'on');
                end
                
                if self.color_rois
                    set(self.h.rois, 'Color', 'b');
                    set(self.h.rois(self.selected_rois), 'Color', 'w');
                end
            else
                set(self.h.rois, 'Visible', 'off', 'HitTest', 'off');
            end
            
            if length(self.selected_rois) == 1 && self.is_editing_enabled
                % Make sure the markers are on top of the other lines.
                ax_children = get(self.h.im_axes, 'Children');
                ax_markers = ismember(ax_children, [self.h.rotation_marker, self.h.xresize_marker, self.h.yresize_marker]);
                ax_sorted = [ax_children(ax_markers); ax_children(~ax_markers)];
                set(self.h.im_axes, 'Children', ax_sorted);
                
                % If there is only a single selected roi, then show the
                % rotation and resize markers.
                set(self.h.rotation_marker, 'Visible', 'on');
                set(self.h.xresize_marker, 'Visible', 'on');
                set(self.h.yresize_marker, 'Visible', 'on');
                
                self.set_edit_marker_positions(self.rois.xyrra(self.selected_rois, :, self.current_frame));
            else
                set(self.h.rotation_marker, 'Visible', 'off');
                set(self.h.xresize_marker, 'Visible', 'off');
                set(self.h.yresize_marker, 'Visible', 'off');
            end
            
            self.update_move_mode_push();
            drawnow;
        end
        
        function set_selected_rois(self, val)
            if ~isempty(self.selected_rois) && isequal(self.selected_rois, val)
                % The selected_rois haven't change, so don't do anything
                disp('selection is the same');
                return;
            end
            
            self.selected_rois = val;
            
            self.update();
            notify(self, 'SelectionChanged');
        end
        
        function val = set_current_frame(self, val, trigEvent)
            % set_current_frame: sets the current frame. If the frame given
            % is out of range, will set the frame to 1. Returns the frame.
            
            % Make sure val is an int
            val = round(val);
            
            if val < 1 || val > self.get_num_frames()
                % Then val is out of range.
                %disp('val is out of range setting to 1.');
                val = 1;
                self.current_frame = val;
                %val = self.current_frame;
                return;
            end
            
            if ~isempty(self.current_frame) && all(self.current_frame == val)
                % The current frame hasn't changed, so don't do anything
                return;
            end
            
            if nargin < 3 || isempty(trigEvent)
                trigEvent = 1;
            end
            
            self.current_frame = val;
            if trigEvent
                notify(self, 'FrameChanged');
            end
            
            self.update();
        end        
        
        function roi_idxs = rois_at_pos(self, xy)
            % rois_at_pos: takes an xy coordinate and detects if the point
            % falls within any ROIs. Returns all ROIs that overlap the
            % point.
            %
            % @param: xy [x y] the coordinates
            % @return: roi_idxs the indices of the rois that overlap xy.
            
            % if self.mode == 'xyrra'
            if isempty(self.rois.xyrra)
                roi_idxs = [];
                return;
            end
            
            xc = self.rois.xyrra(:, 1, self.current_frame) - xy(1);
            yc = self.rois.xyrra(:, 2, self.current_frame) - xy(2);
            
            xr = cos(-self.rois.xyrra(:, 5, self.current_frame)) .* xc - sin(-self.rois.xyrra(:, 5, self.current_frame)) .* yc;
            yr = sin(-self.rois.xyrra(:, 5, self.current_frame)) .* xc + cos(-self.rois.xyrra(:, 5, self.current_frame)) .* yc;
            
            % The 0.5 is to get the radii, rois are the circle that
            % inscribes the rectangle defined.
            d = 0.5 * ((xr ./ self.rois.xyrra(:, 3, self.current_frame)) .^ 2 + (yr ./ self.rois.xyrra(:, 4, self.current_frame)) .^ 2);
            
            roi_idxs = find(d <= 1);
        end
        
        function toggle_selected_rois(self, roi_idxs)
            % toggle_selected_rois: changes the selected state of the rois given.
            %
            % @param: roi_idxs the rois to toggle. Default is all rois.
            
            if nargin < 2
                roi_idxs = 1:self.get_num_rois();
            end
            
            turn_off = ismember(roi_idxs, self.selected_rois);
            members = ismember(self.selected_rois, roi_idxs);
            
            sr = self.selected_rois;
            sr(members) = [];
            self.set_selected_rois([sr, roi_idxs(~turn_off)]);
            
            self.update();
        end
        
        function add_rois(self, rois, trigEvent)
            % add_rois: adds an roi to the set of rois.
            %
            % @param: rois an xyrra (Mx5) or blob roi. The roi can have a
            % single frame, in which case it will be added to all frames.
            % @param: trigEvent flag indicating whether or not to trigger
            % the NewRois event. Default is 1.
            disp('add_rois');
            if ~self.is_editing_enabled
                % Editing is disabled, so cannot add rois.
                disp('Editing is disabled. Enable before adding new rois.');
                return;
            end
            
            if nargin < 3
                trigEvent = true;
            end
            
            if size(rois, 1) == size(self.im_data, 1) && size(rois, 2) == size(self.im_data, 2)
                % Then the rois is a blob.
                % @todo
            else
                if isempty(self.rois.xyrra)
                    % This is giving me problems. This should fix most
                    % empty issues.
                    self.rois.xyrra = nan(1,5,self.get_num_frames());
                end
                
                % Then the rois is xyrra
                nidx = self.get_num_rois() + 1;
                nidx = nidx:(nidx+size(rois, 1) - 1);
                
                if ndims(rois) == 3
                    % Then we have an rois for each frames.
                    self.rois.xyrra(nidx, :, :) = rois;
                else
                    % Then copy the rois to all frames.
                    self.rois.xyrra(nidx, :, :) = repmat(rois, [1 1 size(self.rois.xyrra, 3)]);
                end
            end
            
            if trigEvent
                d = struct('rois', rois);
                notify(self, 'NewRois', DataEvent(d));
            end
            % We must notify the add before changing the selection, in case
            % there is a linked RoiEditor.
            self.set_selected_rois(nidx);
            
            self.update();
            disp('end add');
        end
        
        function set_rois(self, rois, trigEvent)
            % set_rois(self, rois, trigEvent): sets all of the rois.
            disp('RoiEditor.set_rois');
            if nargin < 3
                trigEvent = true;
            end
            
            if size(rois, 1) == size(self.im_data, 1) && size(rois, 2) == size(self.im_data, 2)
                % Then the rois is a blob.
                % @todo
            else     
                % Then the rois is xyrra
                if size(rois, 3) == 1
                    % Then we will copy the rois to all frames.
                    self.rois.xyrra = repmat(rois, [1 1 self.get_num_frames()]);
                elseif size(rois, 3) == self.get_num_frames()
                    % Then there is an roi for all frames.
                    self.rois.xyrra = rois;
                else
                    error('rois dimensions mismatch image dimensions');
                end
            end
            
            self.selected_rois = [];
            
            if trigEvent
                d = struct('roi_idxs', 1:self.get_num_rois());
                notify(self, 'AlteredRois', DataEvent(d));
            end

            self.update();
            disp('end RoiEditor.set_rois');
        end
        
        function shift_rois(self, roi_idxs, delta, frames, trigEvent)
            % shift_rois: moves the rois specified in roi_idxs the amount
            % specified in delta. This is a relative amount.
            %
            % @param: roi_idxs the index positions of the rois to move.
            % @param: delta [x y] amount to move the rois.
            % @param: frames the frames which to move the rois. Default is
            % all frames.
            % @param: trigEvent flag indicating whether or not to trigger
            % AlteredRois event. Default true.
            
            if ~self.is_editing_enabled
                % Editing is disabled, so cannot shift rois.
                disp('Editing is disabled. Enable before moving rois.');
                return;
            end
            
            if nargin < 4
                frames = 1:self.get_num_frames();
            end
            
            if nargin < 5
                trigEvent = true;
            end
            
            % if xyrra
            self.rois.xyrra(roi_idxs, 1, frames) = self.rois.xyrra(roi_idxs, 1, frames) + delta(1);
            self.rois.xyrra(roi_idxs, 2, frames) = self.rois.xyrra(roi_idxs, 2, frames) + delta(2);
            
            if trigEvent
                a.roi_idxs = roi_idxs;
                notify(self, 'AlteredRois', DataEvent(a));
            end
            
            self.update();
        end
        
        function move_rois(self, roi_idxs, locs, frames, trigEvent)
            % move_rois: moves the rois specified in roi_idxs to the
            % locations given.
            %
            % @param: roi_idxs the index positions of the rois to move.
            % @param: locs [x y] the locations to put the new rois. This
            % can be several forms: 
            %   [x y]: all rois are moved to the location given
            %   N x 2: where N is the length of roi_idxs - each roi will
            %   be moved to the location specified by row. This will effect
            %   all frames given by frames.
            %   N x 2 x M: where M is the length of frames - the rois for
            %   each roi and each frame will be moved to the corresponding
            %   location.
            % @param: frames the frames which to move the rois. Default is
            % all frames.
            % @param: trigEvent flag indicating whether or not to trigger
            % AlteredRois event. Default true.
            
            if ~self.is_editing_enabled
                % Editing is disabled, so cannot move rois.
                disp('Editing is disabled. Enable before moving rois.');
                return;
            end
            
            if nargin < 4
                % Default for frames is all frames
                frames = 1:self.get_num_frames();
            end
            if nargin < 5
                % Default for trigEvent is true.
                trigEvent = true;
            end
            
            % if xyrra
            if numel(locs) == 2
                % Then we have just x, y coordinates.
                self.rois.xyrra(roi_idxs, 1, frames) = locs(1);
                self.rois.xyrra(roi_idxs, 2, frames) = locs(2);
            elseif size(locs, 1) == length(roi_idxs)
                if size(locs, 3) == length(frames)
                    % Then we have locations for every roi for every frame
                    self.rois.xyrra(roi_idxs, 1, frames) = locs(:, 1, :);
                    self.rois.xyrra(roi_idxs, 2, frames) = locs(:, 2, :);
                elseif size(locs, 3) == 1
                    % Then we have locs for every roi, so change over all
                    % frames.
                    self.rois.xyrra(roi_idxs, 1, frames) = repmat(locs(:, 1), [1 1 length(frames)]);
                    self.rois.xyrra(roi_idxs, 2, frames) = repmat(locs(:, 2), [1 1 length(frames)]);
                else
                    error('locs is not shaped correctly');
                end
            else
                error('locs is not shaped correctly.');
            end
            
            if trigEvent
                a.roi_idxs = roi_idxs;
                notify(self, 'AlteredRois', DataEvent(a));
            end
            
            self.update();
        end
        
        function delete_rois(self, roi_idxs, trigEvent)
            % delte_rois: deletes the rois given.
            %
            % @param: roi_idxs the indices of the rois to delete.
            % @param: trigEvent flag indicating whether or not to trigger
            % AlteredRois event. Default true.
            disp('RoiEditor.delete_rois');
            if ~self.is_editing_enabled
                % Editing is disabled, so cannot dekete rois.
                disp('Editing is disabled. Enable before deleting rois.');
                return;
            end
            
            if isempty(roi_idxs)
                % Nothing to delete
                return;
            end
            
            if nargin < 3
                % Default for trigEvent is true.
                trigEvent = true;
            end
            
            % Keep the selected rois selected
            is_selected = false(self.get_num_rois(), 1);
            is_selected(self.selected_rois) = 1;
            is_selected(roi_idxs) = [];
            
            disp('before delete');
            % Delete the rois
            self.rois.xyrra(roi_idxs, :, :) = [];
            % Delete the roi handles
            delete(self.h.rois(roi_idxs));
            disp('after delete');
            self.h.rois(roi_idxs) = [];
            
            if trigEvent
                a.roi_idxs = roi_idxs;
                notify(self, 'DeletedRois', DataEvent(a));
            end
            
            self.set_selected_rois = find(is_selected);
            self.update();
            disp('end RoiEditor.delete_rois');
        end
        
        function resize_rois(self, roi_idxs, new_rr, trigEvent)
            % resize_rois: resizes the rois to the given size.
            %
            % @param: roi_idxs the rois to resize.
            % @param: new_rr [xr, yr] the new size of the rois.
            % @param: trigEvent flag indicating whether or not to trigger
            % AlteredRois event. Default true.
            
            if ~self.is_editing_enabled
                % Editing is disabled, so cannot resize rois.
                disp('Editing is disabled. Enable before resizing rois.');
                return;
            end
            
            % @todo: input checks
            if nargin < 5
                % Default for trigEvent is true.
                trigEvent = true;
            end
            
            if numel(new_rr, 2) == 2
                self.rois.xyrra(roi_idxs, 3, :) = abs(new_rr(1));
                self.rois.xyrra(roi_idxs, 4, :) = abs(new_rr(2));
            elseif ndims(new_rr) == 3
                self.rois.xyrra(roi_idxs, 3, :) = abs(new_rr(:, 1, :));
                self.rois.xyrra(roi_idxs, 4, :) = abs(new_rr(:, 2, :));
            elseif ndims(new_rr) == 2
                self.rois.xyrra(roi_idxs, 3, :) = repmat(abs(new_rr(:, 1)), [1 1 size(self.rois.xyrra, 3)]);
                self.rois.xyrra(roi_idxs, 4, :) = repmat(abs(new_rr(:, 2)), [1 1 size(self.rois.xyrra, 3)]);
            else
                error('new_rr shape not recognized');
            end
            
            if trigEvent
                a.roi_idxs = roi_idxs;
                notify(self, 'AlteredRois', DataEvent(a));
            end
            self.update();
        end
        
        function rotate_rois(self, roi_idxs, angle)
            % rotate_rois: rotates the rois by the amount angle in radians.
            %
            % @param: roi_idxs the rois to rotate.
            % @param: angle the amount to rotate the rois.
            % @param: trigEvent flag indicating whether or not to trigger
            % AlteredRois event. Default true.
            
            if ~self.is_editing_enabled
                % Editing is disabled, so cannot rotate rois.
                disp('Editing is disabled. Enable before rotating rois.');
                return;
            end
            
            if nargin < 5
                % Default for trigEvent is true.
                trigEvent = true;
            end
            
            self.rois.xyrra(roi_idxs, 5, :) = self.rois.xyrra(roi_idxs, 5, :) + angle;
            
            if trigEvent
                a.roi_idxs = roi_idxs;
                notify(self, 'AlteredRois', DataEvent(a));
            end
            self.update();
        end
        
        function cycle_move_mode(self)
            % cycle_move_mode: changes the move_mode to the next mode in
            % the cycle.
            
            if self.move_mode == RoiEditor.ShiftAfter
                self.move_mode = RoiEditor.ShiftAll;
            elseif self.move_mode == RoiEditor.ShiftAll
                self.move_mode = RoiEditor.Each;
            elseif self.move_mode == RoiEditor.Each
                self.move_mode = RoiEditor.MoveAfter;
            elseif self.move_mode == RoiEditor.MoveAfter
                self.move_mode = RoiEditor.MoveAll;
            elseif self.move_mode == RoiEditor.MoveAll;
                self.move_mode = RoiEditor.ShiftAfter;
            end   
            
            self.update();
        end
        
        function toggle_show_inactive_rois(self)
            % toggle_show_inactive_rois: flips the state of the
            % show_inactive_rois flag.
            self.show_inactive_rois = ~self.show_inactive_rois;
            self.update();
        end
        
        function cycle_rois(self)
            % cycle_rois: selects the next roi.
            if self.get_num_rois() == 0
                % Then there are no rois to cycle through.
                return;
            end
                
            if isempty(self.selected_rois)
                s = 1;
            else
                s = max(self.selected_rois);
                s = s+1;
            end
            
            if s > self.get_num_rois()
                s = 1;
            end
            
            self.set_selected_rois(s);
            self.update();            
        end
        
        function link_roi_editors(self, roi_editor)
            % link_roi_editors: links this roi_editor to another one, so
            % that rois are created/modified/deleted together. Only the roi
            % moves are seperate. This is useful for analyzing
            % ratio-imaging data.
            
            if self == roi_editor
                error('Cannot link to self');
            end
            
            if ~isfield(self.gui, 'linked_roi_editors')
                self.gui.linked_roi_editors = [];
            end
            
            if any(ismember(self.gui.linked_roi_editors, roi_editor))
                % self is already linked to the other roi_editor.
                return;
            end
            
            % Add the roi_editor to the list of linked roi_editors.
            self.gui.linked_roi_editors = [self.gui.linked_roi_editors roi_editor];
            
            addlistener(roi_editor, 'NewRois', @self.link_new_rois_cb);
            addlistener(roi_editor, 'SelectionChanged', @self.link_selection_changed_cb);
            addlistener(roi_editor, 'FrameChanged', @self.link_frame_changed_cb);
            addlistener(roi_editor, 'DeletedRois', @self.link_deleted_rois_cb);
            
            % Link the other editor to this one.
            roi_editor.link_roi_editors(self);
        end
        
        function disable_roi_editing(self)
            % disable_roi_editing: disables any changes to rois (no
            % add, delete or alter). Rois can still be selected.
            self.is_editing_enabled = false;
            self.update();
        end
        
        function enable_roi_editing(self)
            % enable_roi_editing: enables roi changes.
            self.is_editing_enabled = true;
            self.update();
        end
        
        function set_im_data(self, im, trigEvent, imx, imy)
            % set_im_data: sets the image data. This will delete all of the
            % current rois.
            %
            % @param: im the image data.
            
            disp('RoiEditor.set_im_data');
            if nargin < 3 || isempty(trigEvent)
                trigEvent = true;
            end
            
            % The defaults for imx, imy are based on size(im)
            if nargin < 4
                imx = [];
            end
            if nargin < 5
                imy = [];
            end
            
            self.im_data = im;
            
            if isempty(imx)
                self.im_x = 1:size(self.im_data, 2);
            else
                self.im_x = imx;
            end
            if isempty(imy)
                self.im_y = 1:size(self.im_data, 1);
            else
                self.im_y = imy;
            end
            
            %self.current_frame = 1;
            
            if ndims(self.im_data) == 3
                % then set all the level scrolls to the fulll range
                self.h.level_scroll.Min = double(min(self.im_data(:)));
                self.h.level_scroll.Max = double(max(self.im_data(:)));
               
                self.h.level_scroll2.Min = double(min(self.im_data(:)));
                self.h.level_scroll2.Max = double(max(self.im_data(:)));
                
                self.h.level_scroll3.Min = double(min(self.im_data(:)));
                self.h.level_scroll3.Max = double(max(self.im_data(:)));
                
            else
                % Ok if everything is between 0 and 1, then treat this like
                % a true RGB image.
                if min(self.im_data(:)) >= 0 && max(self.im_data(:)) <= 1
                    self.h.level_scroll.Min = 0;
                    self.h.level_scroll.Max = 1;
                    self.h.level_scroll2.Min = 0;
                    self.h.level_scroll2.Max = 1;
                    self.h.level_scroll3.Min = 0;
                    self.h.level_scroll3.Max = 1;
                else
                    % Then set them each to their channels
                    self.h.level_scroll.Min = double(min(reshape(self.im_data(:,:,1,:), 1, [])));
                    self.h.level_scroll.Max = double(max(reshape(self.im_data(:,:,1,:), 1, [])));
                    self.h.level_scroll2.Min = double(min(reshape(self.im_data(:,:,2,:), 1, [])));
                    self.h.level_scroll2.Max = double(max(reshape(self.im_data(:,:,2,:), 1, [])));
                    self.h.level_scroll3.Min = double(min(reshape(self.im_data(:,:,3,:), 1, [])));
                    self.h.level_scroll3.Max = double(max(reshape(self.im_data(:,:,3,:), 1, [])));
                    % @todo: alternatively, could set to min/max of all
                    % channels.
                end
            end
            
            self.h.level_scroll.MinStep = 0.01 * (self.h.level_scroll.Max - self.h.level_scroll.Min);
            self.h.level_scroll.set_max_range();
            self.h.level_scroll2.MinStep = 0.01 * (self.h.level_scroll2.Max - self.h.level_scroll2.Min);
            self.h.level_scroll2.set_max_range();
            self.h.level_scroll3.MinStep = 0.01 * (self.h.level_scroll3.Max - self.h.level_scroll3.Min);
            self.h.level_scroll3.set_max_range();
            
            
            if self.current_frame > self.get_num_frames()
                self.current_frame = self.get_num_frames();
            end

            % Check to make sure the ROIs are the right size.
            if size(self.rois.xyrra, 3) < size(self.im_data, 3)
                % Then just copy the rest of the rois.
                last_rois = self.rois.xyrra(:, :, end);
                
                num_extra_frames = size(self.im_data, 3) - size(self.rois.xyrra, 3);
                
                self.rois.xyrra(:,:,(end+1):(end+num_extra_frames)) = repmat(last_rois, [1,1,num_extra_frames]);
            end
            
            axis(self.h.im_axes, [self.im_x(1), self.im_x(end), self.im_y(1), self.im_y(end)]);
            %self.delete_rois(1:self.get_num_rois(), trigEvent);
            
            self.update_frame_slider();
            self.update();
            disp('end RoiEditor.set_im_data');
        end
        
        function set.Parent(self, val)
            disp('Setting RoiEditor Parent');
            set(self.h.panel, 'Parent', double(val))
        end
        
        function set_levels(self, levels, range, trigEvent)
            % set_levels(self, levels): set the color level values.
            %
            % @param: levels 2x1 or 2x3 matrix of levels values
            % @param: range 2x1 or 2x3 matrix of full level range. Default
            % is min/max of im data.
            
            if nargin < 4 || isempty(trigEvent)
                % Trigger Event by default
                trigEvent = true;
            end
            
            if nargin < 3 || isempty(range)
                if ndims(self.im_data) == 3
                    range(1, 1) = double(min(self.im_data(:)));
                    range(2, 1) = double(max(self.im_data(:)));
                else
                    % Ok if everything is between 0 and 1, then treat this like
                    % a true RGB image.
                    if min(self.im_data(:)) >= 0 && max(self.im_data(:)) <= 1
                        range(1, 1) = 0;
                        range(2, 1) = 1;
                        range(1, 2) = 0;
                        range(2, 2) = 1;
                        range(1, 3) = 0;
                        range(2, 3) = 1;
                    else
                        % Then set them each to their channels
                        range(1, 1) = double(min(reshape(self.im_data(:,:,1,:), 1, [])));
                        range(2, 1) = double(max(reshape(self.im_data(:,:,1,:), 1, [])));
                        range(1, 2) = double(min(reshape(self.im_data(:,:,2,:), 1, [])));
                        range(2, 2) = double(max(reshape(self.im_data(:,:,2,:), 1, [])));
                        range(1, 3) = double(min(reshape(self.im_data(:,:,3,:), 1, [])));
                        range(2, 3) = double(max(reshape(self.im_data(:,:,3,:), 1, [])));
                        % @todo: alternatively, could set to min/max of all
                        % channels.
                    end
                end
            end
            
            if numel(range) == 2
                % Then we will set all 3 ranges to the same
                range = repmat(range(:), 1, 3);
            end
            
            % This should always be true by this point
            assert(isequal(size(range), [2, 3]));
            
            % @todo: check to make sure that the im data has nothing beyond
            % the range
            
            self.h.level_scroll.Min = range(1, 1);
            self.h.level_scroll.Max = range(2, 1);
            
            self.h.level_scroll2.Min = range(1, 2);
            self.h.level_scroll2.Max = range(2, 2);
            
            self.h.level_scroll3.Min = range(1, 3);
            self.h.level_scroll3.Max = range(2, 3);
            
            if numel(levels) == 2
                % Then again just set all the levels to the same
                levels = repmat(levels(:), 1, 3);
            end
            
            % THis should also be true now
            assert(isequal(size(levels), [2, 3]));
            
            % These will all call update...
            self.h.level_scroll.Value = levels(:, 1);
            self.h.level_scroll2.Value = levels(:, 2);
            self.h.level_scroll3.Value = levels(:, 3);
            
            if trigEvent
                notify(self, 'LevelsChanged');
            end
        end
        
        function levels = get_levels(self)
            % levels = get_levels(self): returns the color level values.
            
            levels = zeros(2,3);
            
            levels(:, 1) = self.h.level_scroll.Value;
            levels(:, 2) = self.h.level_scroll2.Value;
            levels(:, 3) = self.h.level_scroll3.Value;
        end
        
        function play_settings(self, play_rate, frame_step)
            % Sets the play timing settings 
            
            if nargin < 2 || isempty(play_rate)
                play_rate = 0.01;
            end
            
            if nargin < 3 || isempty(frame_step)
                frame_step = 1;
            end
            
            self.gui.play_rate = play_rate;
            self.gui.frame_step = frame_step;
            
            set(self.gui.play_timer, 'Period', self.gui.play_rate);
        end
        
        %%%%%%%%%% Utility Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function frame = get_frame(self, frame_num)
            % get_frame: returns the desired frame.
            %
            % @param: frame_num the desired frame number.
            % @return: frame MxN or MxNx3 image.
            
            if frame_num > self.get_num_frames()
                % Then we are out of range.
                frame = zeros(1,1);
                return;
            end
            
            if ndims(self.im_data) <= 3
                % Then we have MxNxt or MxNx1 (if its only 2 dimensional)                
                frame = self.im_data(:,:, frame_num);
            else
                % Then we have MxNx3xt
                frame = self.im_data(:,:,:, frame_num);
            end
        end
        
        function nframe = get_nframe(self, frame_num)
            % get_nframe: returns the globally normalized version of
            % desired frame.
            %
            % @param: frame_num the desired frame number.
            % @return: nframe MxN or MxNx3 image.
            
            if frame_num > self.get_num_frames()
                % Then we are out of range.
                nframe = zeros(1,1);
                return;
            end
            
             if ndims(self.im_data) <= 3
                % Then we have MxNxt or MxNx1 (if its only 2 dimensional) 
                frame = double(self.im_data(:,:, frame_num));
                
                % Ok so now lets get the level_scroll and rescale the frame
                levels = self.h.level_scroll.Value;
                frame(frame < levels(1)) = levels(1);
                frame(frame > levels(2)) = levels(2);

                nframe = (frame - levels(1))./(levels(2) - levels(1)) ; % now stretch to full range
            else
                % Then we have MxNx3xt
                frame = self.im_data(:,:,:, frame_num);
                
                rlevels = self.h.level_scroll.Value;
                glevels = self.h.level_scroll2.Value;
                blevels = self.h.level_scroll3.Value;
                
                nframe(:,:,1) = (max(min(frame(:,:,1), rlevels(2)), rlevels(1)) - rlevels(1)) ./ (rlevels(2) - rlevels(1));
                nframe(:,:,2) = (max(min(frame(:,:,2), glevels(2)), glevels(1)) - glevels(1)) ./ (glevels(2) - glevels(1));
                nframe(:,:,3) = (max(min(frame(:,:,3), blevels(2)), blevels(1)) - blevels(1)) ./ (blevels(2) - blevels(1));
            end
        end        
        
        function nframes = get_num_frames(self)
            % get_num_frames: returns the total number of frames.
            
            if ndims(self.im_data) <= 3
                nframes = size(self.im_data, 3);
            else
                nframes = size(self.im_data, 4);
            end            
        end
        
        function nrois = get_num_rois(self)
            % get_num_rois: returns the number of rois.
            if isempty(self.rois.xyrra)
                nrois = 0;
            else
                nrois = size(self.rois.xyrra, 1);
            end
        end
        
        function update_frame_slider(self)
            % update_frame_slider: sets the frame_slider settings to match
            % the current im_data.
            
            set(self.h.frame_slider, 'Min', 1);
            nf = self.get_num_frames();
            if nf < 1
                % Then we have no frames
                set(self.h.frame_slider, 'Max', 2, 'SliderStep', [0 Inf]);
            elseif nf < 2
                % Then we have 1 frame
                set(self.h.frame_slider, 'Max', 2, 'SliderStep', [0 Inf]);
            else
                set(self.h.frame_slider, 'Max', nf, 'SliderStep', [1./(nf-1), 10./(nf-1)]);
            end            
        end
        
        function update_move_mode_push(self)
            % update_move_mode_push: sets the move_mode_push settings to
            % match the current state.
            
            if self.move_mode == RoiEditor.ShiftAfter
                set(self.h.move_mode_push, 'String', 'Shift After');
            elseif self.move_mode == RoiEditor.ShiftAll
                set(self.h.move_mode_push, 'String', 'Shift All');
            elseif self.move_mode == RoiEditor.Each
                set(self.h.move_mode_push, 'String', 'Each');
            elseif self.move_mode == RoiEditor.MoveAfter
                set(self.h.move_mode_push, 'String', 'Move After');
            elseif self.move_mode == RoiEditor.MoveAll
                set(self.h.move_mode_push, 'String', 'Move All');
            else
                error('Unrecognized move mode');
            end
        end
        
        function animate_roi_move(self, xy, roi_idxs)
            % animate_roi_move: makes the animation of roi moves and
            % updates the selected_rois and their positions.
            %
            % @param: xy the start xy point of the move.
            % @param: roi_idxs the set of rois that fall in the start point.
            
            if ~self.is_editing_enabled
                % Then pretend its just a click.
                self.handle_click_in_roi(roi_idxs);
                return;
            end
            
            % If there are any selected rois already, give them top
            % priority. We only want 1 roi to be the base of the move.
            % If our roi is already selected then we are moving all 
            % selected rois as a group, if it is not selected, then we are 
            % selecting only the one that the mouse is in and moving that one.
            selected = ismember(roi_idxs, self.selected_rois);
            if ~any(selected)
                self.set_selected_rois(roi_idxs(1));
            end
            
            % First get the handles of the roi
            current_roi_h = self.h.rois(self.selected_rois);
            % Now get all of the current roi values, we need to alter them
            % relatively, since we are moving many rois at once potentially
            rois = self.rois.xyrra(self.selected_rois, :, self.current_frame);
            % Keep track of the maximum amount moved to check for whether
            % the action was a click or drag.
            maxdist = 0;
            
            while self.gui.fen.button_down()
                % now to get the move, we just need to add the difference
                % in the start and end mouse positions to the center of the
                % rois.
                point2 = get(self.h.im_axes, 'CurrentPoint');
                
                px2 = point2(1);
                py2 = point2(3);
                
                d = sum((xy - [px2 py2]) .^ 2);
                if d > maxdist
                    maxdist = d;
                end
                
                rois(:, 1) = self.rois.xyrra(self.selected_rois, 1, self.current_frame) + px2 - xy(1);
                rois(:, 2) = self.rois.xyrra(self.selected_rois, 2, self.current_frame) + py2 - xy(2);
                
                % Update the graphics.
                [xs, ys] = oval2xy(rois, [], 0);
                for i = 1:length(current_roi_h)
                    set(current_roi_h(i), 'XData', xs(i, :), 'YData', ys(i, :));
                end
                self.set_edit_marker_positions(rois(1,:));
                drawnow;
            end
              
            if maxdist < 2
                % Then we didn't drag much, so probably just a click.
                self.handle_click_in_roi(roi_idxs);
                return;
            end
            
            self.make_roi_move([px2 py2] - xy);
        end
        
        function handle_click_in_roi(self, roi_idxs)
            % handle_click_in_roi: changes the selected_rois when there is
            % a click inside an roi.
            %
            % @param: roi_idxs the rois that the click falls in.
            
            if length(roi_idxs) > 1 && any(ismember(roi_idxs, self.selected_rois))
                sel = ismember(roi_idxs, self.selected_rois);
                idx = find(sel, 1, 'last');
                if idx == length(sel)
                    idx = 0;
                end
                s_after_sel = roi_idxs((idx+1):end);
                first_not_selected = find(~ismember(s_after_sel, self.selected_rois), 1, 'first');
                
                if isempty(first_not_selected)
                    % Then all of the rois were already selected, so just
                    % select the first one.
                    self.set_selected_rois(roi_idxs(1));
                else
                    % Go to the next roi that is not selected.
                    self.set_selected_rois(s_after_sel(first_not_selected));
                end
            else
                self.set_selected_rois(roi_idxs(1));
            end
            
            self.update();
        end
        
        function make_roi_move(self, delta)
            % make_roi_move: decides how to move the rois based on the
            % current move_mode.
            
            new_locs = zeros(length(self.selected_rois), 2);
            new_locs(:, 1) = self.rois.xyrra(self.selected_rois, 1, self.current_frame) + delta(1);
            new_locs(:, 2) = self.rois.xyrra(self.selected_rois, 2, self.current_frame) + delta(2);
            if self.move_mode == RoiEditor.ShiftAll
                % ShiftAll moves all rois relatively for all frames
                self.shift_rois(self.selected_rois, delta); % Default moves all;
            elseif self.move_mode == RoiEditor.ShiftAfter
                % ShiftAfter moves rois relatively for only the current
                % frame and the following frames
                self.shift_rois(self.selected_rois, delta, self.current_frame:self.get_num_frames());
            elseif self.move_mode == RoiEditor.Each
                % Each moves only the rois in the current frame.
                self.move_rois(self.selected_rois, new_locs, self.current_frame);
            elseif self.move_mode == RoiEditor.MoveAfter
                % MoveAfter moves all rois after the current frame to the
                % their locations for the current frame.
                self.move_rois(self.selected_rois, new_locs, self.current_frame:self.get_num_frames());
            elseif self.move_mode == RoiEditor.MoveAll
                % MoveAll moves all rois to the location of the rois in the
                % current frame.
                self.move_rois(self.selected_rois, new_locs);
            else
                error('Move mode not recognized.');
            end
        end
        
        function animate_roi_creation(self, xy)
            % animate_roi_creation: makes an animation of roi creation and
            % adds the new roi.
            % 
            % @param: xy the start point of the roi creation.
            
            if ~self.is_editing_enabled
                % Then no editing allowed, this is just a click on nothing.
                self.set_selected_rois([]);
                self.update();
                return;
            end
            
            % First get the handle of the rois, we may need to create them
            if self.get_num_rois() < length(self.h.rois)
                % Then the handle already exists, usually this doesn't
                % happen.
                current_roi_h = self.h.rois(self.get_num_rois() + 1);                
                set(current_roi_h, 'Visible', 'on');
            else
                % We need to create a new handle
                current_roi_h = plot_oval([xy(1), xy(2), 0, 0, 0], 'Parent', self.h.im_axes, 'LineWidth', 2);
                
                idx = size(self.h.rois, 1) + 1;
                self.h.rois(idx, 1) = current_roi_h;                
            end
            
            roi = zeros(1, 5);
            maxdist = 0;
            while self.gui.fen.button_down()
                % Now while the mouse is getting dragged recalculate the
                % roi and redraw it.
                point2 = get(self.h.im_axes, 'CurrentPoint');
                px2 = point2(1);
                py2 = point2(3);
                
                left = min(xy(1), px2);
                right = max(xy(1), px2);
                bottom = min(xy(2), py2);
                top = max(xy(2), py2);
                
                roi(1) = (left + right) / 2;
                roi(2) = (bottom + top) / 2;
                roi(3) = (right - left) / 2;
                roi(4) = (top - bottom) / 2;                

                [rx, ry] = oval2xy(roi, [], 0);
                
                set(current_roi_h, 'Color', 'w', 'XData', rx, 'YData', ry);
                
                d = sum((xy - [px2 py2]) .^ 2);
                if maxdist < d
                    maxdist = d;
                end
                
                drawnow;
            end
            
            % Now check to see if this was just a click by seeing if the
            % number of pixels moved to draw the ellipse is below threshold
            if maxdist < 10
                % Then this point was too small, so we wont actually add an
                % roi.
                self.set_selected_rois([]);
                self.update();
                return;
            end
            
            % Finally, make sure that the roi width and height is non-zero
            if roi(3) == 0 || roi(4) == 0
                % Then the roi has a zero dimension which isn't allowed.
                % Act like its just a click.
                self.set_selected_rois([]);
                self.update();
                return;
            end
            
            % Now add the roi
            self.add_rois(roi);
        end
        
        function animate_roi_rotation(self, xy)
            % animate_roi_rotation: makes the animation of roi rotation and
            % updates the selected_rois and their angles.
            %
            % @param: xy the start xy point of the rotation.
            
            if ~self.is_editing_enabled
                % Then this is not allowed, do nothing?
                return;
            end
            
            % Get the roi, the (1) is just to make sure we only have 1.
            roi = self.rois.xyrra(self.selected_rois(1), :, self.current_frame);
            roi_h = self.h.rois(self.selected_rois(1));
            
            % get the normalized start coordinates.
            x = xy(1) - roi(1);
            y = xy(2) - roi(2);
            xn = cos(-roi(5)) .* x - sin(-roi(5)) .* y;
            yn = sin(-roi(5)) .* x + cos(-roi(5)) .* y;
            
            % get the angle
            an = atan(yn ./ xn);
            
            roit = roi;
            while self.gui.fen.button_down()
                point2 = get(self.h.im_axes, 'CurrentPoint');
                
                px2 = point2(1) - roi(1);
                py2 = point2(3) - roi(2);
                
                % Now rotate the mouse point
                xr = cos(-roi(5)) .* px2 - sin(-roi(5)) .* py2;
                yr = sin(-roi(5)) .* px2 + cos(-roi(5)) .* py2;
                
                % Get the angle
                ar = atan(yr ./ xr);
                deltaa = ar - an;
                
                roit(5) = roi(5) + wrapToPi(deltaa);
                
                % Update the graphics
                [xs, ys] = oval2xy(roit, [], 0);
                
                set(roi_h, 'XData', xs, 'YData', ys);
                self.set_edit_marker_positions(roit);
                
                drawnow;
            end
            
            self.rotate_rois(self.selected_rois(1), wrapToPi(deltaa));
            %self.resize_rois(self.selected_rois(1), [roi(3) + deltax ./ sqrt(2), roi(4)]);
        end
        
        function animate_roi_xresize(self, xy)
            % animate_roi_xresize: makes the animation of resizing the roi
            % in the x direction.
            %
            % @param: xy the start mouse position.
            
            if ~self.is_editing_enabled
                % Then this is not allowed, do nothing?
                return;
            end
            
            % Get the roi, the (1) is just to make sure we only have 1.
            roi = self.rois.xyrra(self.selected_rois(1), :, self.current_frame);
            roi_h = self.h.rois(self.selected_rois(1));
            
            % get the normalized start coordinates.
            x = xy(1) - roi(1);
            y = xy(2) - roi(2);
            xn = cos(-roi(5)) .* x - sin(-roi(5)) .* y;
            
            roit = roi;
            while self.gui.fen.button_down
                point2 = get(self.h.im_axes, 'CurrentPoint');
                
                px2 = point2(1) - roi(1);
                py2 = point2(3) - roi(2);
                
                % Now rotate the mouse point
                xr = cos(-roi(5)) .* px2 - sin(-roi(5)) .* py2;
                
                % The resize will be based only in the x direction.
                deltax = xr - xn;
                
                roit(3) = roi(3) + deltax ./ sqrt(2);
                
                % Update the graphics
                [xs, ys] = oval2xy(roit, [], 0);
                set(roi_h, 'XData', xs, 'YData', ys);
                self.set_edit_marker_positions(roit);
                
                drawnow;
            end
            
            self.resize_rois(self.selected_rois(1), [roi(3) + deltax ./ sqrt(2), roi(4)]);
        end
        
        function animate_roi_yresize(self, xy)
            % animate_roi_yresize: makes the animation of resizing the roi
            % in the y direction.
            %
            % @param: xy the start mouse position.
            
            if ~self.is_editing_enabled
                % Then this is not allowed, do nothing?
                return;
            end
            
            % Get the roi, the (1) is just to make sure we only have 1.
            roi = self.rois.xyrra(self.selected_rois(1), :, self.current_frame);
            roi_h = self.h.rois(self.selected_rois(1));
            
            % get the normalized start coordinates.
            x = xy(1) - roi(1);
            y = xy(2) - roi(2);
            
            yn = sin(-roi(5)) .* x + cos(-roi(5)) .* y;
            
            roit = roi;
            while self.gui.fen.button_down()
                point2 = get(self.h.im_axes, 'CurrentPoint');
                
                px2 = point2(1) - roi(1);
                py2 = point2(3) - roi(2);
                
                % Now rotate the mouse point
                yr = sin(-roi(5)) .* px2 + cos(-roi(5)) .* py2;
                
                % The resize will be based only in the y direction.
                deltay = yr - yn;
                
                roit(4) = roi(4) + deltay ./ sqrt(2);
                
                % Update the graphics
                [xs, ys] = oval2xy(roit, [], 0);
                set(roi_h, 'XData', xs, 'YData', ys);
                self.set_edit_marker_positions(roit);
                
                drawnow;
            end
            
            self.resize_rois(self.selected_rois(1), [roi(3), roi(4) + deltay ./ sqrt(2)]);
        end
        
        function set_edit_marker_positions(self, roi)
            % set_edit_marker_positions: sets the edit markers to the
            % correct positions.
            
            % rotation marker
            x = roi(3);
            y = roi(4);            
            rx = cos(roi(5)) .* x - sin(roi(5)) .* y + roi(1);
            ry = sin(roi(5)) .* x + cos(roi(5)) .* y + roi(2);            
            set(self.h.rotation_marker, 'XData', rx, 'YData', ry);
            
            % xresize marker
            xx = sqrt(2) .* cos(roi(5)) .* x + roi(1);
            xy = sqrt(2) .* sin(roi(5)) .* x + roi(2);
            set(self.h.xresize_marker, 'XData', xx, 'YData', xy);
            
            % yresize marker
            
            yx = -sqrt(2) .* sin(roi(5)) .* y + roi(1);
            yy = sqrt(2) .* cos(roi(5)) .* y + roi(2);
            set(self.h.yresize_marker, 'XData', yx, 'YData', yy);
        end
    end %methods

end %classdef