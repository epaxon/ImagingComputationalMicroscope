function [oval_pixels, box] = oval_image(oval, im_x, im_y)
% Finds the pixels that fall within the borders of the oval and returns
% them as a logical image where 1 indicates the pixel is within the oval's
% border, and 0 indicates it is not. The size of the oval image will be the
% minimum size that can contain the entire oval.
%
% @param: oval coordinates of oval, indicated by xyrr
% @param: max_range describes the limiting coordinates of an oval. 
%   i.e. if oval had to be on a 256x256 image, then max_range would be
%   [1, 256, 1, 256].
% @return: oval_pixels binary image of which pixels are within oval
% @return: box the coordinates of the bounding box used to calculate oval
%
% @file: oval_image.m
% @brief: Returns the pixels which fall inside given oval
% @author: Paxon Frady
% @created: 4/1/2010

box(:,1) = floor(oval(:,1) - oval(:,3));
box(:,2) = ceil(oval(:,1) + oval(:,3));
box(:,3) = floor(oval(:,2) - oval(:,4));
box(:,4) = ceil(oval(:,2) + oval(:,4));

% Find the full range of the box that we should check.
minx = min(box(:,1));
maxx = max(box(:,2));
miny = min(box(:,3));
maxy = max(box(:,4));

if nargin == 2
    error('Need 1 or 3 arguments');
elseif nargin > 2
    minx = max(minx, min(im_x));
    maxx = min(maxx, max(im_x));
    miny = max(miny, min(im_y));
    maxy = min(maxy, max(im_y));
else
    im_x = minx:maxx;
    im_y = miny:maxy;
end
% Reassign box to fit within the allowed range.
box = [minx, maxx, miny, maxy];

xvals = im_x(im_x >= minx & im_x <= maxx);
yvals = im_y(im_y >= miny & im_y <= maxy);

% create a matrix of the x and y values that will span the entire space.
[square_x, square_y, ~] = meshgrid(xvals, yvals, ones(size(oval, 1), 1));

% Now make the oval values also span the entire space.
ovalr = reshape(oval', 1, 4, size(oval, 1));
ovalrep1 = repmat(ovalr(:, 1, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep2 = repmat(ovalr(:, 2, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep3 = repmat(ovalr(:, 3, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep4 = repmat(ovalr(:, 4, :), [size(square_x, 1), size(square_x, 2), 1]);

% Now we can calculate the distances for the entire space.
d = ((ovalrep1 - square_x) ./ ovalrep3) .^ 2 + ((ovalrep2 - square_y) ./ ovalrep4) .^ 2;

oval_pixels = d < 1;
