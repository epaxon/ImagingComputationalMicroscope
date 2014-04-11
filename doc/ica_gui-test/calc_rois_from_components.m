function rois = calc_rois_from_components(comp, x, y)
% rois = calc_rois_from_components(comp): Estimates ROI positions from the
% independent components.
%
% @param: comp the components in image form. 
% @param: x the x values of the image. Default 1:size(comp, 2).
% @param: y the y values of the image. Default 1:size(comp, 1).
% @return: rois Nx5 array of roi components.
%
% @author: Paxon Frady
% @created: 9/5/2013

if nargin < 2 || isempty(x)
    x = 1:size(comp, 2);
end

if nargin < 3 || isempty(y)
    y = 1:size(comp, 1);
end

% Number of std for significance.
sig_thresh = 2;

% @todo: checks

rois = nan(size(comp, 3), 5);

properties = {'Area', 'Centroid', 'MajorAxisLength', 'MinorAxisLength', 'Orientation'};

for i = 1:size(comp, 3)
    sig = comp(:,:,i);
    
    sig_pos_idx = find(sig(:) > sig_thresh * std(sig(:)));
    sig_neg_idx = find(-sig(:) > sig_thresh * std(sig(:)));
    
%     sig_pos_idx = find(sig(:) > sig_thresh);
%     sig_neg_idx = find(-sig(:) > sig_thresh);
    
    sig_im = zeros(size(comp, 1), size(comp, 2));
    
    sig_im(sig_pos_idx) = 1;
    %sig_im(sig_neg_idx) = -1;
    sig_im(sig_neg_idx) = 1;
    
    %sig_im_filt = mediflt2(sig_im, [3, 3]);
    
    stats = regionprops(bwlabel(sig_im), properties{:});
    
    areas = [stats.Area];
    
    [~, sidx] = sort(areas, 'descend');
    
    % just take the largest
    cx = stats(sidx(1)).Centroid(1);
    cy = stats(sidx(1)).Centroid(2);
    vx = stats(sidx(1)).MajorAxisLength/2;
    vy = stats(sidx(1)).MinorAxisLength/2;
    an = -pi / 180 * stats(sidx(1)).Orientation;
    
    % Convert roi based on the x, y
%     cx = interp1(1:size(comp, 2), x, cx);
%     cy = interp1(1:size(comp, 2), y, cy);
%     
%     vx = vx / mean(diff(x));
%     vy = vy / mean(diff(y));
    
    rois(i,:) = [cx, cy, vx, vy, an];
    
%     rois(i,:) = [stats(sidx(1)).Centroid, stats(sidx(1)).MajorAxisLength/2, stats(sidx(1)).MinorAxisLength/2, -pi/180*stats(sidx(1)).Orientation];

%     disp(rois(i,:));
%     figure(41);
%     clf();
%     hold on;
%     imagesc(sig_im);
%     [x,y] = oval2xy(rois(i,:));
%     plot(x', y');
%     
%     pause;
end

rois(:, 1) = interp1(1:size(comp, 2), x, rois(:, 1));
rois(:, 2) = interp1(1:size(comp, 1), y, rois(:, 2));
rois(:, 3) = mean(diff(x)) * rois(:, 3) / 2;
rois(:, 4) = mean(diff(y)) * rois(:, 4) / 2;