function data_fit = poly_subtract(data, N, fit_frames)
% poly_subtract fits a polynomial of order [N] to each row of [data] and
% subtracts the polynomial from the [data]. This returns the subtracted
% result in [data_fit].
%
% @author: Paxon Frady
% @created: 9/03/09

data_fit = nan(size(data));

if nargin < 2
    N = 8;
end

if nargin < 3
    fit_frames = 1:size(data, 2);
end

for k = 1:size(data,1)
    if mod(k, 1000) == 0
        disp(k);
    end
    mdata = data(k, fit_frames);
    
    warning off;
    p = polyfit(fit_frames, mdata, N);
    fit = polyval(p, 1:size(data, 2));
    warning on;
    data_fit(k,:) = data(k, :) - fit;
end