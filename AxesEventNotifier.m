classdef AxesEventNotifier < handle
    % class AxesEventNotifier: sends out notifications during axes events.
    
    properties
        ah; % The axes handles associated with this notifier.
        source_h; % The handle of the axes where the event occured
        button_down; % Which mouse button is down.
        last_eventdata; % Keeps the data given by eventdata from the last event.
    end
    
    events
        ButtonDown;
        Delete;
    end
    
    methods 
        function self = AxesEventNotifier(ah)
            % Constructor
            self.ah = [];
            % First check if there is already a AxesEventNotifier for
            % this axes.
            user_data = get(ah(1), 'UserData');
            if ~isempty(user_data)
                if isa(user_data, 'AxesEventNotifier')
                    % Then the axes already has an AxesEventNotifier.
                    self = user_data;
                    return;
                else
                    % Then there is something else in user_data. Issue a
                    % warning.
                    warning('AxesEventNotifier:deletingUserData', ...
                        'Axes UserData is not empty and will be replaced.');
                end
            end
            
            set(ah, 'UserData', self);
            self.add_handle(ah);
        end
        
        %%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function buttondown_cb(self, source_h, eventdata)
            % Called when a button is pressed in an axes.            
            self.source_h = source_h;
            self.last_eventdata = eventdata;
            self.notify('ButtonDown');
        end
        
        function delete_cb(self, source_h, eventdata)
            disp('AEN::delete_cb');
            
            idx = find(self.ah == source_h);
            
            if isempty(idx)
                % Then the axes wasn't found...
                disp('delete function called, but source_h not part of AEN.');
                return;
            end
            
            notify(self, 'Delete');
            
            user_data = get(source_h, 'UserData');
            if ~isempty(user_data)
                if isa(user_data, 'AxesEventNotifier')
                    % Then delete this from user data
                    set(source_h, 'UserData', []);
                end
            end
            
            self.ah(idx) = [];
            
            % Ok if there's nothing left in the ah, then delete the object
            if isempty(self.ah)
                delete(self);
            end
        end
        
        %%%%%%%%%% Main Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function add_handle(self, ah)
            if ismember(ah, self.ah)
                % Then we already have this axes, so just return
                disp('Axes already part of AxesEventNotifier');
                return;
            end
            set(ah, 'ButtonDownFcn', @self.buttondown_cb);
            set(ah, 'DeleteFcn', @self.delete_cb);
            self.ah = [self.ah ah];
        end
    end
end