classdef DataEvent < event.EventData
    % DataEvent: standard class for even data that has a struct called
    % data. Assign values to the struct as desired. 
    properties
        data;
    end
    methods
        function self = DataEvent(data_s)
            % Constructor. Creates a new DataEvent object and assigns data
            % given in the struct (data_s).
            %
            % @param: data_s struct containing the data.
            
            if nargin < 1
                disp('nargin < 1');
                data_s = struct([]);
            end
            self.data = data_s;
        end
    end
end