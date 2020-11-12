function [vx,vy] = subroutine_generateWarpFromAnchorPoints(img, a1, a2, strategy)
% Function to create a vector field from corresponding points
%
% img: image on which points were detected
% 
% a1,a2: (x,y) locations of corresponsing points on image, as produced by
% subroutine_autodetect
%
% strategy: method to use for generating warp. Interpolation is currently
% the only working strategy
%
% outputs vector field in meshgrid form, perfect for using as input to
% subroutine_vectorWarp

if(nargin < 4)
    strategy = 'interpolation';
end

[x, y] = meshgrid(1:size(img,2),  1:size(img,1));
vx = x;
vy = y;

if(strcmp(strategy, 'interpolation'))
    %make point indices into ints
    for i = 1:size(a1,1)
        vx(round(a1(i,1)), round(a1(i,2))) = a2(i,2);
        vy(round(a1(i,1)), round(a1(i,2))) = a2(i,1);
    end
    
    %create scattered interpolants from point data. NOTE: will not work
    %if there are less that 3 points
    intx = scatteredInterpolant(a1(:,1), a1(:,2),a1(:,1) - a2(:,1));
    inty = scatteredInterpolant(a1(:,1), a1(:,2),a1(:,2) - a2(:,2));
    
    %use interpolants to create vectors for each point in the meshgrid
    vx = intx(x,y);
    vy = inty(x,y);

end

if(strcmp(strategy, 'delaunay'))
    %CAUION: Delaynay method is a WIP, use interpolation for now. Also,
    %interpolation is highly effective anyway.
    initTri = delaunay(a1(:,1),a1(:,2)); %Delaunay triangulation for initial points
    targetTri = delaunay(a2(:,1),a2(:,2));%triangulation for warped points
    for i = 1:size(initTri,1)%iterate over all triangles
       affineMat = zeros(3,3);
        X = zeros(6,6);
        xPrime = zeros(6,1);
        for j = 1:3 
            %Construct matrix of form [x1 y1 1 0 0 0; 0 0 0 x1 y1 1]
            X(2*j-1,:) = horzcat([a1(initTri(i,j),1) a1(initTri(i,j),2) 1],zeros(1,3));
            X(2*j,:) = horzcat(zeros(1,3), [a1(initTri(i,j),1) a1(initTri(i,j),2) 1]);
            %contruct target points vector [x1 y1 x2 y2 ... xn yn]
            xPrime(2*j-1) = a2(targetTri(i,j),1);
            xPrime(2*j) = a2(targetTri(i,j),2);
        end
        %solve for affine vector
        a = xPrime\X;
        %package vector into affine matrix
        affineMat(1,:) = a(1:3);
        affineMat(2,1:3) = a(4:6);
        affineMat(3,1:3) = [0 0 1];
        
        %extract points inside triangle
        ind = inpolygon(x(:),y(:),a1(initTri(i,:),1),a1(initTri(i,:),2));
        ind = reshape(ind, size(img,2), size(img,1));
        %transform points using affine matrix, put into vx, vy
        vx(ind) = affineMat(1,:)*[vx(ind) vy(ind) ones(size(vx(ind)))]';
        vy(ind) = affineMat(2,:)*[vx(ind) vy(ind) ones(size(vx(ind)))]';
    end
    vx = vx-x;
    vy = vy-y;
end


