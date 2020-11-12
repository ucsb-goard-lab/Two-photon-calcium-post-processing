function D = subroutine_vectorWarp(img,vx,vy,drawflag)
% Function for warping images according to a specified vector field
% img: the image to be warped
%
% vx,vy: The x and y components of the vector field in meshgrid format
% (try: ``help meshgrid`` for more info)
%
% drawgflag (0,1): whether to plot the vector field on top of the image
% 
% returns warped image

[x, y] = meshgrid(1:size(img,2),  1:size(img,1));

if(nargin == 1)
    % generate synthetic test data, for experimenting only
    vx = 30*sin(x/70);% an arbitrary flow field
    vy = 30*sin(y/70);
    drawflag = 1;
end

% compute the warped image - the subtractions are because we're specifying
% where in the original image each pixel in the new image comes from
D = interp2(double(img), x-vx, y-vy);

%draw flow vectors
if(drawflag)
    imagesc(D);
    hold on
        for i = 1:50:size(img,1)
            for j = 1:50:size(img,2)
                xPlot = [x(i,j), x(i,j) + vx(i,j)];
                yPlot = [y(i,j), y(i,j) + vy(i,j)];
                plot(xPlot, yPlot, 'Color','Red','LineWidth',1);
            end
        end
    hold off
end

