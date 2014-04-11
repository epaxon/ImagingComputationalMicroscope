function data = mean_roi(ccd_movie, roi_data, im_x, im_y)
% This function uses the roi_data and takes the mean value for the pixels
% within each roi for each frame.
%
% @param: ccd_movie a NxMxT movie, where T is the number of frames
% @param: roi_data a NxM image, where each integer represents a roi
%                 or a Nx4 matrix where each row is an roi [cx, cy, vx, vy]
% @param: im_x the x-values of the image pixels, must have length M
% @param: im_y the y-values of the image pixels, must have length N
% @return: data the time series inside each roi. Frames x ROIs
%
% @file: mean_roi.m
% Contains the mean_roi function
% @author: Paxon Frady
% @created: 3/4/2010

data = [];
if isempty(roi_data)
    % Then do nothing
    return;
end

if isempty(ccd_movie)
    % Also do nothing
    return;
end

if nargin < 3 || isempty(im_x)
    % Default for im_x is just the pixel length
    im_x = 1:size(ccd_movie, 2);
end

if nargin < 4 || isempty(im_y)
    im_y = 1:size(ccd_movie, 1);
end

if (size(roi_data, 2) == 4)
    % Then we have a xyrr form roi_data
    data = mean_roi_xyrr(ccd_movie, roi_data, im_x, im_y);
elseif (size(roi_data, 2) == 5)
    data = mean_roi_xyrra(ccd_movie, roi_data, im_x, im_y);
else
    % Then assume that we have roi_data of image form
    data = mean_roi_map(ccd_movie, roi_data);
end
end

function data = mean_roi_map(ccd_movie, roi_data)
% Helper function, returns the roi data given that the form of roi_data is
% of an image map.

max_roi = max(roi_data(:));
nframes = size(ccd_movie, 3);
data = zeros(nframes, max_roi);
% @todo: get rid of these for loops like in xyrr for more efficiency.
for i = 1:nframes
    ccd_frame = imresize(ccd_movie(:, :, i), size(roi_data));
    for j = 1:max_roi
        data(i, j) = nanmean(ccd_frame(roi_data == j));
    end
end

end

function data = mean_roi_xyrr(ccd_movie, roi_data, im_x, im_y)
% Helper function to distinguish between roi_data that has an roi for each
% frame or if rois are for all frames.
%disp(ndims(roi_data));
if ndims(roi_data) == 2
    % we have a single roi for all frames, call the all function
    data = mean_roi_xyrr_all(ccd_movie, roi_data, im_x, im_y);
else
    % we have an roi for each frame, call the each function
    
    % assert that the number of frames is equal in the movie and rois.
    % There may be a way to do this without needing this to be true,
    % like interpolating or something, but for now...
    assert(size(ccd_movie, 3) == size(roi_data, 3));
    data = mean_roi_xyrr_each(ccd_movie, roi_data, im_x, im_y);
end
end

function data = mean_roi_xyrr_each(ccd_movie, roi_data, im_x, im_y)
% Helper function, returns the roi data given that the form is xyrr and
% there is an roi for each frame of the video.
nframes = size(ccd_movie, 3);
data = zeros(nframes, size(roi_data, 1));

for j = 1:size(roi_data, 1)
    ovals = reshape(roi_data(j,:,:), 4, [])';
    [d, box] = oval_image(ovals, im_x, im_y);
    
    xvals = im_x >= box(1) & im_x <= box(2);
    yvals = im_y >= box(3) & im_y <= box(4);
    
    square_movie = ccd_movie(yvals, xvals, :);

    data(:, j) = nanmean(reshape(square_movie(d), [], size(ccd_movie,3)));
end

end

function data = mean_roi_xyrr_all(ccd_movie, roi_data, im_x, im_y)
% Helper function, returns the roi data given that the form of roi_data is
% of [cx, cy, vx, vy] for each row.

nframes = size(ccd_movie, 3);
data = zeros(nframes, size(roi_data, 1));
range = [1, max(im_x), 1, max(im_y)];

for j = 1:size(roi_data, 1)
    [d, box] = oval_image(roi_data(j,:), im_x, im_y);

    % alright now we make the logic array the depth of the movie.
    d_logic = repmat(d, [1, 1, nframes]);
        
    % We just want the rectangle of the movie in which our roi falls into.
    % Then we'll use the logic array to selecte out the correct pixels.
    xvals = im_x >= box(1) & im_x <= box(2);
    yvals = im_y >= box(3) & im_y <= box(4);
    
    square_movie = ccd_movie(yvals, xvals, :);
    

    % Yep, like this... Breakdown:
    % - get all of the desired pixels (square_movie(d_logic), this every
    %   pixel we want to consider, but now their frame info is sorta lost.
    % - reshape to fit in NxnFrames, this reformat this so that the pixels
    %   for each frame are sorted by cols. N == sum(d >= 1).
    % - Then take the mean across the pixels.
    data(:, j) = nanmean(reshape(square_movie(d_logic), [], nframes));
end
end

function data = mean_roi_xyrra(ccd_movie, roi_data, im_x, im_y)
% Helper function to distinguish between roi_data that has an roi for each
% frame or if an roi is for all frames.

if ndims(roi_data) == 2
    % We have a single roi for all frames, call the all function.
    data = mean_roi_xyrra_all(ccd_movie, roi_data, im_x, im_y);
else
    % There is an roi for each frame, call the each function.
    
    % assert that the number of frames is equal in the movie and rois.
    assert(size(ccd_movie, 3) == size(roi_data, 3));
    data = mean_roi_xyrra_each(ccd_movie, roi_data, im_x, im_y); 
end
end

function data = mean_roi_xyrra_each(ccd_movie, roi_data, im_x, im_y)
    % Returns the roi data given the form is xyrra and there is an roi for
    % each video frame.
    nframes = size(ccd_movie, 3);
    data = zeros(nframes, size(roi_data, 1));

    for j = 1:size(roi_data, 1)
        ovals = reshape(roi_data(j, :, :), 5, [])';
        [d, box] = xyrra_image(ovals, im_x, im_y);
        
        xvals = im_x >= box(1) & im_x <= box(2);
        yvals = im_y >= box(3) & im_y <= box(4);
        
        square_movie = ccd_movie(yvals, xvals, :);
        
        square_movie(~d) = nan;
        data(:, j) = nanmean(nanmean(square_movie, 1), 2);
    end
end

function data = mean_roi_xyrra_all(ccd_movie, roi_data, im_x, im_y)
    % Returns the roi data given the form is xyrra and there is an roi for
    % all frames.
    nframes = size(ccd_movie, 3);
    data = zeros(nframes, size(roi_data, 1));
    
    for j = 1:size(roi_data, 1)
        [d, box] = xyrra_image(roi_data(j, :), im_x, im_y);
        
        d_all = repmat(d, [1, 1, nframes]);
        
        xvals = im_x >= box(1) & im_x <= box(2);
        yvals = im_y >= box(3) & im_y <= box(4);
        
        square_movie = ccd_movie(yvals, xvals, :);
                
        data(:, j) = nanmean(reshape(square_movie(d_all), [], nframes));
    end
end