function nmat = norm_range(mat, rmin, rmax)
% nmat = norm_range(mat) returns a normalized matrix such that the values
% are between 0 and 1. 
%
% nmat = norm_range(mat, rmin, rmax) returns a normalized matrix such that
% the values are between rmin and rmax.
%
% @param: mat the matrix to normalize.
% @param: rmin the minimum value of the range. Default 0.
% @param: rmax the maximum value of the range. Default rmin + 1.
%
% @file: norm_range.m
% @brief: Normalizes a matrix to fit inside a range.
% @author: Paxon Frady
% @created: 10/6/10

if nargin < 2
    % rmin is not specified set default
    rmin = 0;
end

if nargin < 3
    % rmax is not specified set rmax
    rmax = rmin + 1;
end

if rmin >= rmax
    error('rmin must be less than rmax');
end

if isempty(mat)
    % If we have an empty matrix then there's nothing to do
    nmat = mat;
    return;
elseif (max(mat(:)) - min(mat(:))) == 0
    % Then, every number is the same, so just make everything 0 instead of
    % nan/inf.
    nmat = zeros(size(mat));
else
    nmat = (mat - min(mat(:))) ./ (max(mat(:)) - min(mat(:)));
end

nmat = nmat * rmax + rmin;
