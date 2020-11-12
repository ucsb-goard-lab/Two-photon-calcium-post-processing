function [xcrop, ycrop] = subroutine_maxAreaCrop(original, plotflag)
%Function to find the maximum area rectangle with no NaN values in an image 
%
%original: The image with NaN values to be cropped out. Should be the
%result of running subroutine_vectorWarp
%
%plotflag (0,1): Whether to plot the cropped rectangle on top of the image
%
%returns indices of cropped images. To crop another image, use image(ycrop, xcrop)

bin = reshape(~isnan(original),size(original,1),size(original,2));
bound = cell2mat(bwboundaries(bin));
max_area = 0;
for i = 1:size(bound,1)
    for j = i:size(bound,1)
        y1 = bound(i,1);
        x1 = bound(i,2);
        y2 = bound(j,1);
        x2 = bound(j,2);
        
        area = abs((y2 - y1)*(x2 - x1));
        if(~isnan(original(y1,x1)) && ~isnan(original(y1,x2)) &&...
            ~isnan(original(y2,x1)) && ~isnan(original(y2,x2)) && area > max_area)           
            max_area = area;
            Y1 = y1;
            Y2 = y2;
            X1 = x1;
            X2 = x2;
        end
    end
end
if(plotflag)
    imagesc(original)
    hold on
    xplot = [min(X1,X2), min(X1,X2), max(X1,X2), max(X1,X2)];
    yplot = [min(Y1,Y2), max(Y1,Y2), max(Y1,Y2), min(Y1,Y2)];
    plot(xplot, yplot, 'Color', 'Red');
    hold off
end

xcrop = min(X1,X2):max(X1,X2);
ycrop = min(Y1,Y2):max(Y1,Y2);

