function [thresh, thresh_im] = max_corr_thresh_all(im, viz)
% [thresh, thresh_im] = max_corr_thresh_all(im, thresh0): finds the maximum
% correlation threshold over all frames.
%
% @param: im MxNxT movie
%
% @author: Paxon Frady
% @created: 2/17/2014

if nargin < 2 || isempty(viz)
    viz = 0;
end

thresh_vals = linspace(min(im(:)), max(im(:)), 100);
corr_vals = zeros(size(thresh_vals));

for t = 1:length(thresh_vals)
    disp(t);
    imt = im(:) > thresh_vals(t);
    corr_vals(t) = corr(imt, im(:));
end

[max_corr, max_idx] = max(corr_vals);

thresh = thresh_vals(max_idx);
thresh_im = im > thresh;

if viz
    for i = 1:size(im, 3)
        figure(11);
        clf();
        subplot(2,2,1);
        hold on;
        plot(thresh_vals, corr_vals);
        plot(thresh_vals(max_idx), max_corr, 'o');
        subplot(2,2,2);
        plot(im(:), thresh_im(:),  '.');
        subplot(2,2,3);
        imagesc(im(:,:,i));
        subplot(2,2,4);
        imagesc(thresh_im(:,:,i));
        
        str = input('Press Enter to continue. Press "x" to quit', 's');
        if strcmp(str, 'x')
            % Then we're done
            break;
        end
    end
end