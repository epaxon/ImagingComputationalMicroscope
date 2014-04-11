function [xyrra_pixels, box] = xyrra_image(xyrra, im_x, im_y)
% Finds the pixels that fall within the borders of the oval and returns
% them as a logical image where 1 indicates the pixel is within the oval's
% border, and 0 indicates it is not. 
% 


% [x, y] = oval2xy(xyrra, 30, 0);
% 
% minc = floor(min(x(:)));
% maxc = ceil(max(x(:)));
% minr = floor(min(y(:)));
% maxr = ceil(max(y(:)));

% Get a bounding box. The square box thats the size of the biggest
% dimension will always have the oval regardless of the angle. This is a
% little faster than calculating it otherwise.
maxdim = sqrt(2) * max(max(xyrra(:, [3, 4])));
minx = floor(min(xyrra(:, 1) - maxdim));
maxx = ceil(max(xyrra(:, 1) + maxdim));
miny = floor(min(xyrra(:, 2) - maxdim));
maxy = ceil(max(xyrra(:, 2) + maxdim));

if nargin == 2
    error('Need 1 or 3 arguments');
elseif nargin > 2 % @todo more checks
    minx = max(minx, min(im_x));
    maxx = min(maxx, max(im_x));
    miny = max(miny, min(im_y));
    maxy = min(maxy, max(im_y));
else
    im_x = minx:maxx;
    im_y = miny:maxy;
end

% Make the box to be the full range.
box = [minx, maxx, miny, maxy];

xvals = im_x(im_x >= minx & im_x <= maxx);
yvals = im_y(im_y >= miny & im_y <= maxy);

% Create a matrix of x and y values that will span the oval space.
[square_x, square_y, ~] = meshgrid(xvals, yvals, ones(size(xyrra, 1), 1));

% Now make the oval values span the entire space.
ovalr = reshape(xyrra', 1, 5, size(xyrra, 1));
ovalrep1 = repmat(ovalr(:, 1, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep2 = repmat(ovalr(:, 2, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep3 = repmat(ovalr(:, 3, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep4 = repmat(ovalr(:, 4, :), [size(square_x, 1), size(square_x, 2), 1]);
ovalrep5 = repmat(ovalr(:, 5, :), [size(square_x, 1), size(square_x, 2), 1]);

xr = cos(-ovalrep5) .* (square_x - ovalrep1) - sin(-ovalrep5) .* (square_y - ovalrep2);
yr = sin(-ovalrep5) .* (square_x - ovalrep1) + cos(-ovalrep5) .* (square_y - ovalrep2);

d = 0.5 * ((xr ./ ovalrep3) .^ 2 + (yr ./ ovalrep4) .^ 2);

xyrra_pixels = d <= 1;