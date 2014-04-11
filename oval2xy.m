function [x, y] = oval2xy(dims, detail, inscribed)
% Takes dims a Nx4 (Nx5) param array of [cx, cy, vx, vy] 
% ([cx, cy, vx, vy, angle]) describing an oval and returns an array of xy
% coordinates that describe the edge of the oval. 
% @param: dims Nx4 (Nx5) matrix - Nx[cx cy vx vy] (Nx[cx cy vx vy angle])
%   cx, cy - center of oval (in x, y)
%   vx, vy - width and height of rectangle describing oval, depending on
%   whether the oval is inscribed or circumscribed around rectangle
%   angle - the angle of rotation of the oval
% @param: detail the number of points used to describe the oval. default 20
% @param: inscribed if true oval is inscribed in rectangle, otherwise it
% will be circumscribed around rectange. Default true.
% @return: x,y the x, y coordinates of the oval's edge
%
% @file: oval2xy.m
% Contains the oval2xy function
% @author: Paxon Frady
% @created: 3/30/10

% @todo: error checks on params
if nargin < 2 || isempty(detail)
    detail = 20;
end
if nargin < 3 || isempty(inscribed)
    inscribed = 1;
end

if isempty(dims)
    % Then there is nothing to calculate
    x = [];
    y = [];
    return;
end

if size(dims, 2) < 4
    % Then the oval params are incorrect
    error('Oval params are incorrect, oval must be Nx4 or Nx5 matrix');
end

theta = linspace(0, 2*pi, detail);
theta = repmat(theta, size(dims, 1), 1);

if ~inscribed
    % Then find the dimensions of the inscribed rectangle, and use that to
    % calculate  the ellipse.
    dims(:, 3) = sqrt(2) .* dims(:, 3);
    dims(:, 4) = sqrt(2) .* dims(:, 4);
end

% Check if the oval is xyrra
if size(dims, 2) > 4
    angle = repmat(dims(:, 5), 1, size(theta, 2));
else
    % If not, xyrr is equal to xyrra with a = 0
    angle = zeros(size(theta));
end

x1 = repmat(dims(:, 3), 1, size(theta, 2)) .* cos(theta);
y1 = repmat(dims(:, 4), 1, size(theta, 2)) .* sin(theta);

% Do the rotation with the angles.
x = cos(angle) .* x1 - sin(angle) .* y1 + repmat(dims(:, 1), 1, size(theta, 2));
y = sin(angle) .* x1 + cos(angle) .* y1 + repmat(dims(:, 2), 1, size(theta, 2));

