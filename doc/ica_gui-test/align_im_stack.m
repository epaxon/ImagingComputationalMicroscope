function [im_stack, warp] = align_im_stack(im, n_iters, n_levels, transform, viz)
% im_stack = align_im_stack(im): Aligns an image stack using image
% registration -- Motion correction algorithm.
%
% @param: im image data MxNxT
% @param: n_iters the number of iterations to run the alignment. Deafult
% 20.
% @param: n_levels the number of pyramid-levels. Default 1.
% @param: transform the type of transform. Default 'affine';
% @param: viz flag to show visualization. Default 0.

if nargin < 2 || isempty(n_iters)
    n_iters = 20;
end

if nargin < 3 || isempty(n_levels)
    n_levels = 1;
end

if nargin < 4 || isempty(transform)
    transform = 'affine';
    % transform = 'translation';
    %transform = 'homography';
    %transform = 'euclidean';
end

if nargin < 5 || isempty(viz)
    viz = 0;
end

transform_types = {'affine', 'translation', 'homography', 'euclidean'};

switch transform
    case transform_types;
    otherwise error('Incorrect transform type. Must be one of [affine, translation, homography, euclidean]');
end

im = double(im);

im_stack = zeros(size(im));
warp = [];
final_warp = eye(2,3)
for i = 1:size(im, 3)
    [results, final_warp, warped_image] = ecc(im(:,:,i), im(:,:,1), n_levels, n_iters, transform, final_warp);
    
    im_stack(:,:,i) = spatial_interp(im(:,:,i), final_warp, 'linear', transform, 1:size(im, 2), 1:size(im, 1));
    warp(:,:,i) = final_warp;
end    

%%% IDK how to handle this, but I'm just going to hack it for now. The
%%% edges of the aligned images need to be cut off.
xmx = ceil(max(warp(1,3,:)));
ymx = ceil(max(warp(2,3,:)));

im_stack = im_stack((1+ymx):(end-ymx), (1+xmx):(end-xmx), :);

%%

figure(21);
clf();
c = 1;
for i = 1:size(warp, 1)
    for j = 1:size(warp, 2)
        subplot(size(warp, 1), size(warp, 2), c);
        plot(squeeze(warp(i,j,:)));
        axis tight;
        
        c = c+1;
    end
end


%% 

xy1 = ones(3, size(warp, 3));
xy0 = xy1;
xy0(1:2, :) = 0;
xy0_warp = xy0;
xy1_warp = xy1;
for i = 1:size(warp, 3)
    xy0_warp(1:2, i) = warp(:,:,i) * xy0(:, i);
    xy1_warp(1:2, i) = warp(:,:,i) * xy1(:, i);
end

figure(22);
clf();
hold on;
plot(xy0_warp(1,:), xy0_warp(2,:), 'k');
plot(xy0_warp(1,1), xy0_warp(2,1), 'o', 'MarkerFaceColor', 'k', 'MarkerSize', 5);
plot(xy1_warp(1,:)-1, xy1_warp(2,:)-1, 'b');