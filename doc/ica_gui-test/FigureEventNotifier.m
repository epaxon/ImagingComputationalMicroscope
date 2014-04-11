classdef FigureEventNotifier < handle
    % class FigureEventNotifier: sends out event notifications during
    % figure events.
    
    properties
        fh; % the figure handle associated with this notifier.
        
        button_down; % Keeps track of which mouse button is down.
        key_down_map; % Keeps track of figure keys that are down.
        last_eventdata; % Keeps the data given by eventdata from the last event.
    end
    
    events
        WindowButtonDown;
        WindowButtonMotion;
        WindowButtonUp;
        
        WindowKeyPress;
        WindowKeyRelease;
        
        CloseRequest;
    end
    
    methods
        function self = FigureEventNotifier(fh)
            % Constructor: 
            
            % First check if there is already a figure event notifier for
            % this figure.
            user_data = get(fh, 'UserData');
            if ~isempty(user_data) 
                if isa(user_data, 'FigureEventNotifier')
                    % Then this figure already has a figure event notifier.
                    self = user_data;
                    return;
                else
                    % Then there is something else in the user_data. We
                    % should issue a warning (potentially this should be an
                    % error).
                    warning('FigureEventNotifier:deletingUserData', ...
                        'Figure UserData is not empty and will be replaced.');
                end
            end
            
            % Create a figure event notifier.
            self.fh = fh;
            set(fh, 'UserData', self);
            set(fh, 'WindowButtonDownFcn', @self.buttondown_cb);
            set(fh, 'WindowButtonMotionFcn', @self.buttonmotion_cb);
            set(fh, 'WindowButtonUpFcn', @self.buttonup_cb);
            set(fh, 'WindowKeyPressFcn', @self.keypress_cb);
            set(fh, 'WindowKeyReleaseFcn', @self.keyrelease_cb);
            set(fh, 'CloseRequestFcn', @self.close_request_cb);
            
            self.key_down_map = containers.Map;
        end
        
        %%%%%%%%%% Callback/Notification functions %%%%%%%%%%%%%%%%%%%%%%%%
        function buttondown_cb(self, source_h, eventdata)
            % Called when a button is pressed in a figure.
            if strcmp(get(source_h, 'SelectionType'), 'normal')
                % Left button is down.
                self.button_down = 1;
            elseif strcmp(get(source_h, 'SelectionType'), 'extend')
                % Middle button is down.
                self.button_down = 2;
            elseif strcmp(get(source_h, 'SelectionType'), 'alt')
                % Right button is down.
                self.button_down = 3;
            else
                % The double click case, this happens when any button is double
                % clicked.
                self.button_down = 4;
            end
            
            self.last_eventdata = eventdata;
            notify(self, 'WindowButtonDown');
        end
        
        function buttonmotion_cb(self, source_h, eventdata)
            % Called when the mouse is moved, and a button is down.

            self.last_eventdata = eventdata;
            notify(self, 'WindowButtonMotion');
        end
        
        function buttonup_cb(self, source_h, eventdata)
            % Called when a button is released in a figure.
            self.button_down = 0;
            
            self.last_eventdata = eventdata;
            notify(self, 'WindowButtonUp');
        end
        
        function keypress_cb(self, source_h, eventdata)
            self.last_eventdata = eventdata;
            self.key_down_map(eventdata.Key) = 1;
            notify(self, 'WindowKeyPress');
        end
        
        function keyrelease_cb(self, source_h, eventdata)
            self.last_eventdata = eventdata;
            self.key_down_map(eventdata.Key) = 0;
            notify(self, 'WindowKeyRelease');
        end
        
        function tf = is_key_down(self, key_name)
            % is_key_down: returns true if the key given is currently being
            % pressed down.
            tf = isKey(self.key_down_map, key_name) && self.key_down_map(key_name);
        end
        
        function close_request_cb(self, source_h, eventdata)
            % close_request_cb: callback when the figure is closed.
            
            disp('FEN::close_request_cb');
            
            % For close do this first so that other functions can do close
            notify(self, 'CloseRequest');
            
            user_data = get(source_h, 'UserData');
            if ~isempty(user_data) 
                if isa(user_data, 'FigureEventNotifier')
                    % Then delete this from the UserData
                    set(source_h, 'UserData', []);
                end
            end
            
            % Now close the figure
            closereq();
            delete(self);
        end
    end
end