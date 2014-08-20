classdef DataClickedEvent < event.EventData
    % Event class to notify if data is clicked.
    
    properties
        ClickedIndex = 0;
    end
    methods
        function self = DataClickedEvent(clicked_index)
            self.ClickedIndex = clicked_index;
        end
    end    
end