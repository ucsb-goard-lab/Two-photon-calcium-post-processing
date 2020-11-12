function [a1, a2] =  subroutine_autoDetectAnochorPoints(original, distorted, plot)
%Functions to automatically detect corresponding points in images
%
%original, distorted = pair of images with same dimensions in which to
%identify corresponding features
%
%plot: Whether to plot corresponding points on an overlayed image
%
%outputs lists of points for each image in [x y] form.
%
%NOTE: This function requires the Computer Vision Systems toolbox

%Find points using SURF Feature extraction.
ptsOriginal  = detectSURFFeatures(original,'MetricThreshold',.01);
ptsDistorted = detectSURFFeatures(distorted,'MetricThreshold',.01);
[featuresOriginal,validPtsOriginal] = ...
    extractFeatures(original,ptsOriginal);
[featuresDistorted,validPtsDistorted] = ...
    extractFeatures(distorted,ptsDistorted);

%Find features that match across images
index_pairs = matchFeatures(featuresOriginal,featuresDistorted);
matchedPtsOriginal  = validPtsOriginal(index_pairs(:,1));
matchedPtsDistorted = validPtsDistorted(index_pairs(:,2));
igood = logical(size(matchedPtsOriginal,1));

for i = 1:size(matchedPtsOriginal,1)
    p1 = matchedPtsOriginal(i,:);
    p2 = matchedPtsDistorted(i,:);
    dx = (p1.Location(1) - p2.Location(1))^2;
    dy = (p1.Location(2) - p2.Location(2))^2;
    %throw out points that are too far apart
    if(sqrt(dx + dy) < 100)
        igood(i) = 1;
    else
        igood(i) = 0;
    end
end   
matchedPtsOriginal = matchedPtsOriginal(igood,:);
matchedPtsDistorted = matchedPtsDistorted(igood,:);
%show matched points
if(plot)
    figure;
    showMatchedFeatures(original,distorted,...
        matchedPtsOriginal,matchedPtsDistorted);
end
a1 = double(matchedPtsOriginal.Location);
a2 = double(matchedPtsDistorted.Location);

