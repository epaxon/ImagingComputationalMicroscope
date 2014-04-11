function h = plot_oval(dims, varargin)
% plot_oval: plots ovals from center and variance.
%   plot_oval(dims) plots an oval given [cx cy vx vy] in each row of dims.
%
%   plot_oval(dims, ...) sends optional arguments to the line function for
%   formatting, etc.
%
% @param: dims Nx4 matrix - [cx cy vx vy], for each row.
%   cx, cy - center of oval (in x, y)
%   vx, vy - width and height of oval.
% @return: h a list of handles for the oval objects. Each oval will have
% its own handle.
%
% @file: plot_oval.m
% @brief: plots ovals given [cx, cy, vx, vy] format.
% @author: Paxon Frady
% @created: 3/21/10
%
% see also: LINE, PLOT

[x,y] = oval2xy(dims, 20);

h = line(x', y', varargin{:});

end