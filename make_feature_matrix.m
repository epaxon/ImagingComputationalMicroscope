function [feature_matrix, feature_weights] = make_feature_matrix(ics, im_data)
% [feature_matrix, feature_weights] = make_feature_matrix(icp): creates a
% feature matrix of all the components.
%
% @author: Paxon Frady
% @created: 12/11/2013


rois = calc_rois_from_components(im_data);

feature_matrix = [];

for i = 1:size(ics, 2)
     %%
    [c, phi, s12, s1, s2, f] = coherencyc(repmat(ics(:,i), 1, size(ics, 2)), ics);
    
    % Get rid of the same component
    c(:,i) = 0;
    
    % Normalize
    c = norm_range(c ./ repmat(mean(c, 2), 1, size(c, 2)));

    % We only want correlations that are in phase
    c(phi > pi/6 | phi < -pi/6) = 0;
    
    cc_r = zeros(size(c));    
    cc_r = medfilt2(c, [3, 1]);
    
    cc_count = sum(cc_r > 0.5) ./ length(cc_r);
    cc_mean = mean(cc_r);
    
    centroid_dist = (rois(i,1) - rois(:,1)).^2 + (rois(i,2) - rois(:,2)).^2;
    centroid_close = 1 ./ (1 + 0.1 * sqrt(centroid_dist));
    centroid_close2 = 1 ./ (1 + 0.1 * centroid_dist);
        
    centroid_close(i) = 0;
    centroid_close2(i) = 0;
    
    feature_matrix(i,:,:) = [cc_count(:), cc_mean(:), centroid_close(:), centroid_close2(:)];
end
 
feature_weights = ones(1,1,size(feature_matrix, 3));