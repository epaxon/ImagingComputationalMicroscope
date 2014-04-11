function [segment_masks, segment_info] = segment_ics(comp, thresh, down_size, min_area)
% [segment_mask, segment_info] = segment_ics(comp): Segments ics into
% localized components.
%
% @param: comp the components in image form
%
% @author: Paxon Frady
% @created: 12/10/2013

if nargin < 2 || isempty(thresh)
    thresh = 1; % @todo: do max_corr_thresh?
end

if nargin < 3 || isempty(down_size)
    down_size = 1/4;
end

if nargin < 4 || isempty(min_area)
    min_area = 6;
end

% These are properties for regionprops
properties = {'FilledImage', 'Image', 'BoundingBox', 'Area', 'Centroid', ...
    'MajorAxisLength', 'MinorAxisLength', 'Orientation'};

% These will be included in segment_struct
%all_segment_data = [];
all_centroids = [];
all_segment_ids = [];
all_ic_ids = [];
all_rois = [];
all_is_pos = [];

% This is the main thing to return
segment_masks = [];

c = 1;
for i = 1:size(comp, 3)
    filt_im = imresize(imresize(comp(:,:,i), down_size), size(comp(:,:,i)));
    
    pos_mask = filt_im > thresh;
    neg_mask = -filt_im > thresh;
    
    pos_mask = medfilt2(medfilt2(pos_mask));
    neg_mask = medfilt2(medfilt2(neg_mask));
    
    pos_stats = regionprops(bwlabel(pos_mask), properties{:});
    neg_stats = regionprops(bwlabel(neg_mask), properties{:});
    
    pos_areas = [pos_stats.Area];
    neg_areas = [neg_stats.Area];
    
    pos_too_small = pos_areas < min_area;
    neg_too_small = neg_areas < min_area;
    
    pos_stats(pos_too_small) = [];
    neg_stats(neg_too_small) = [];
    % Got to fix the areas
    pos_areas(pos_too_small) = [];
    neg_areas(neg_too_small) = [];    
    
    % I use these a lot. This must be after you delete the small ones!
    lps = length(pos_stats);
    lns = length(neg_stats);
    
    pos_centroids = reshape([pos_stats.Centroid], 2, []);
    neg_centroids = reshape([neg_stats.Centroid], 2, []);
    
    centroids = [pos_centroids'; neg_centroids'];
    
    %segment_data = zeros(length(pos_stats) + length(neg_stats), size(icp.pp.im_data, 3));
    rois = zeros(lps + lns, 5);
    data_mask = zeros(size(comp, 1), size(comp, 2), lps + lns);
    %%
    for j = 1:lps % length(pos_stats)
        row_idxs = ceil(pos_stats(j).BoundingBox(2)):(ceil(pos_stats(j).BoundingBox(2)) + pos_stats(j).BoundingBox(4) - 1);
        col_idxs = ceil(pos_stats(j).BoundingBox(1)):(ceil(pos_stats(j).BoundingBox(1)) + pos_stats(j).BoundingBox(3) - 1);
        
        pos_data_mask = zeros(size(comp(:,:,i)));
        pos_data_mask(row_idxs, col_idxs) = max(pos_data_mask(row_idxs, col_idxs), pos_stats(j).Image);
        
        data_mask(:,:,j) = pos_data_mask;
        
        %segment_data(j, :) = mean_roi(icp.pp.im_data, pos_data_mask);
        
        rois(j, 1) = centroids(j, 1);
        rois(j, 2) = centroids(j, 2);
        rois(j, 3) = pos_stats(j).MajorAxisLength/2;
        rois(j, 4) = pos_stats(j).MinorAxisLength/2;
        rois(j, 5) = -pi / 180 * pos_stats(j).Orientation;
    end
    
    for j = 1:length(neg_stats)
        row_idxs = ceil(neg_stats(j).BoundingBox(2)):(ceil(neg_stats(j).BoundingBox(2)) + neg_stats(j).BoundingBox(4) - 1);
        col_idxs = ceil(neg_stats(j).BoundingBox(1)):(ceil(neg_stats(j).BoundingBox(1)) + neg_stats(j).BoundingBox(3) - 1);
        
        neg_data_mask = zeros(size(comp(:,:,i)));
        neg_data_mask(row_idxs, col_idxs) = max(neg_data_mask(row_idxs, col_idxs), neg_stats(j).Image);
        
        data_mask(:,:,j+lps) = neg_data_mask;
        
        %segment_data(j+lps, :) = mean_roi(icp.pp.im_data, neg_data_mask);
                
        rois(j + lps, 1) = centroids(j + lps, 1);
        rois(j + lps, 2) = centroids(j + lps, 2);
        rois(j + lps, 3) = neg_stats(j).MajorAxisLength/2;
        rois(j + lps, 4) = neg_stats(j).MinorAxisLength/2;
        rois(j + lps, 5) = -pi / 180 * neg_stats(j).Orientation;
    end
    
    %segment_data = segment_data ./ repmat(segment_data(:, 20), 1, size(segment_data, 2));
    %%
%     figure(20);
%     clf();
%     subplot(2,1,1);
%     plot(segment_data');
%     subplot(2,1,2);
%     imagesc(sum(data_mask .* repmat(reshape(1:size(data_mask, 3), 1, 1, size(data_mask, 3)), size(data_mask, 1), size(data_mask, 2)), 3));
    
    %% Ok... I somehow need to save a bunch of stuff for each of the segments
    num_segments = lps + lns;
    
    all_segment_ids = [all_segment_ids; (c:(c + num_segments - 1))']; % This will end up being 1;2;3;4;5;... but sanity check.
    %all_segment_data = [all_segment_data; segment_data];
    all_centroids = [all_centroids; centroids];
    all_ic_ids = [all_ic_ids; i * ones(num_segments, 1)];
    all_rois = [all_rois; rois];
    all_is_pos = [all_is_pos; true(lps, 1); false(length(neg_stats), 1)];
    
    segment_masks(:,:,c:(c+num_segments-1)) = data_mask;
    
    c = c+num_segments;
    
end

% This is just to return all the info and make it flexible.
segment_info.segment_ids = all_segment_ids;
%segment_struct.segment_data = all_segment_data;
segment_info.centroids = all_centroids;
segment_info.ic_ids = all_ic_ids;
% @todo: fix the rois with the x,y from the image.
segment_info.rois = all_rois;
segment_info.is_pos = all_is_pos;


