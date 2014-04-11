function [thresh, thresh_im] = max_corr_thresh(im)
% [thresh, thresh_im] = max_corr_thresh(im, thresh0): finds the maximum
% correlation threshold.
%
% @param: im MxNxT movie
%
% @author: Paxon Frady
% @created: 2/5/2014

resize_scale = 0.25;

thresh = zeros(size(im, 3));
for i = 1:size(im, 3)
    disp(i);
    im_frame = norm_range(imresize(imresize(im(:,:,i), resize_scale), size(im(:,:,i))));
    
    thresh_vals = linspace(min(im_frame(:)), max(im_frame(:)), 100);
    corr_vals = zeros(size(thresh_vals));
    
    for t = 1:length(thresh_vals)
        imt = im_frame > thresh_vals(t);
        %imt = tanh(im_frame - thresh_vals(t));
        corr_vals(t) = corr(imt(:), im_frame(:));
    end
    
    
    [max_corr, max_idx] = max(corr_vals);
    
    thresh(i) = thresh_vals(max_idx);
    imtx = im_frame > thresh(i);
    %imtx = tanh(im_frame - thresh(i));
    thresh_im(:,:,i) = imtx;
    
    figure(11);
    clf();
    subplot(2,2,1);
    hold on;
    plot(thresh_vals, corr_vals);
    plot(thresh_vals(max_idx), max_corr, 'o');
    subplot(2,2,2);
    plot(im_frame(:), imtx(:),  '.');
    subplot(2,2,3);
    imagesc(im_frame);
    subplot(2,2,4);
    imagesc(thresh_im(:,:,i));
    title(i);

    pause;
end
   
end