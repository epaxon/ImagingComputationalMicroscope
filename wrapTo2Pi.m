function value = wrapTo2Pi(input)
% Takes an input as a radian value and returns the same angle, but in the
% range of [0 2*pi].
%
% @file: wrapTo2Pi.m
% @brief: wraps radian values to range [0 2*pi]
% This function is already implemented in the mapping toolbox, but msr does
% not have this toolbox so I'm reimplementing it. 
% @author: Paxon Frady
% @created: 9/30/10

% really? thats it?
value = mod(input, 2 * pi);