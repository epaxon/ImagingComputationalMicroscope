function image = tifread(filename)
% image = tifread(filename): reads a tif image stack from a file.
%
% @param: filename string of the filename
%
% @file: tifread.m
% @author: Paxon Frady
% @created: 1/31/2014

info = imfinfo(filename);
image = zeros(info(1).Height, info(1).Width, length(info));
for i = 1:length(info)
    image(:,:,i) = imread(filename,'index',i, 'Info', info);
end
