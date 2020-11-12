function [bw_final cellMasks] = subroutine_autodetect(img, params)

%% subroutine_autodetect.m
%
% Automatically detects ROIs using local adaptive threshold and
% iterative segmentation. See B_DefineROI for usage instructions.
%
% Called by subroutine_interactiveROI
%
% Inputs=> img: image for automatic detection
%          params: detection parameters
%
% Outputs=> bw_final: bw-image of masks
%           cellMasks: cell array of polygonal masks
%
% Code written by Michael Goard & Gerald Pho - updated: Oct 2013

%% default parameters
if nargin>1
    adapt_thresh_offset = params(1);
    adapt_thresh_window = params(2);
    minPixels = params(3);
    maxPixels = params(4);
    H_maxima = params(5);
else
    adapt_thresh_offset = -0.03;    % default(25x) = -0.02;
    adapt_thresh_window = 50;       % default(25x) = 25;
    minPixels = 50;                 % default(25x) = 50;
    maxPixels = 300;                % default(25x) = 250;
    H_maxima = 0.01;                % default(25x) = 0.01;
end
activity_map = img;

%% adaptive threshold
bw = subroutine_adaptivethreshold(activity_map,adapt_thresh_window,adapt_thresh_offset);

%% fill holes
bw2 = imfill(bw,'holes');

%% remove inappropriately shaped ROIs
se = ones(2);           % make structural element
bw3 = imopen(bw2,se);   % area opening

%% remove ROIs smaller than set number of pixels
bw4 = bw3;
CC = bwconncomp(bw4,4);
numPixels = cellfun(@numel,CC.PixelIdxList);        % find number of pixels in each ROI
del_idx = find(numPixels<minPixels);
for i = 1:length(del_idx)
    bw4(CC.PixelIdxList{del_idx(i)}) = 0;
end

%% Seperate image in small cells (no segmentation) and large cells (to be segmented)
bw_no_seg = bw4;                                    % initialize no seg matrix
bw_seg = bw4;                                       % initialize seg matrix
CC = bwconncomp(bw4,4);                             % determine connected elements (ROIs)
CC2 = bwconncomp(bw_no_seg,4);                      % determine connected elements (ROIs)
CC3 = bwconncomp(bw_seg,4);                         % determine connected elements (ROIs)
numPixels = cellfun(@numel,CC.PixelIdxList);        % find number of pixels in each ROI
largeIdx = find(numPixels>maxPixels);               % index large ROIs
smallIdx = setdiff([1:length(numPixels)],largeIdx); % index small ROIs
for i=1:length(largeIdx)                            % make no segmentation image (small ROIs)
    bw_no_seg(CC2.PixelIdxList{largeIdx(i)}) = 0;
end
for i=1:length(smallIdx)                            % make segmentation image (small large)
    bw_seg(CC3.PixelIdxList{smallIdx(i)}) = 0;
end

%% Use maxima to segment large ROIs
maxima = imextendedmax(activity_map,H_maxima);

%% clean up image
se = ones(2);                   % make structural element
maxima2 = imclose(maxima,se);   % area closing

%% fill holes
maxima3 = imfill (maxima2,'holes');

%% Remove maxima smaller than set number of pixels
maxima4 = maxima3;
CC = bwconncomp(maxima4,4);
numPixels = cellfun(@numel,CC.PixelIdxList);
del_idx = find(numPixels<minPixels);
for i = 1:length(del_idx)
    maxima4(CC.PixelIdxList{del_idx(i)}) = 0;
end

%% image complement
activity_map_c = imcomplement(activity_map);

%% impose minima
minima = imimposemin(activity_map_c, ~bw_seg | maxima4);
se = ones(2);                   % make structural element
minima2 = imclose(minima,se);   % area closing

%% watershed transform
L = watershed(minima2,4);

%% clean up segmented image
L(L==1) = 0;
L(L>1) = 1;
L = logical(L);

%% remove ROIs smaller than set number of pixels
CC = bwconncomp(L,4);
numPixels = cellfun(@numel,CC.PixelIdxList);
del_idx = find(numPixels<minPixels);
for i = 1:length(del_idx)
    L(CC.PixelIdxList{del_idx(i)}) = 0;
end

%% Recombine unsegmented and segmented ROIs
bw_final = bw_no_seg+L;

%% save to cellMasks array
cellMasks = bwboundaries(bw_final,4,'noholes');
for i = 1:length(cellMasks)
    cellMasks{i}(:,[1,2]) = cellMasks{i}(:,[2,1]); % switch to [X,Y], instead of [r,c]
end

