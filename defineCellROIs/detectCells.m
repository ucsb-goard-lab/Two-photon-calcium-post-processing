function [registeredActivityMap,ROIMap,cellROIs] = detectCells(registeredActivityMaps,rowShiftVector,columnShiftVector,activityMapThreshold,offset,diskRadius,windowSize,minPixels,maxPixels,Hmaxima)

    % mouseData
    registeredActivityMap = mean(registeredActivityMaps,3);
    registeredActivityMap(registeredActivityMap<=activityMapThreshold) = 0;
    if max(columnShiftVector) > 0
        registeredActivityMap(:,1:max(columnShiftVector)) = 0;
    end
    if min(columnShiftVector) < 0
        registeredActivityMap(:,size(registeredActivityMap,2)+min(columnShiftVector):end) = 0;
    end
    if max(rowShiftVector) > 0
        registeredActivityMap(1:max(rowShiftVector),:) = 0;
    end
    if min(rowShiftVector) < 0
        registeredActivityMap(size(registeredActivityMap,1)+min(rowShiftVector):end,:) = 0;
    end
    
    % Automated detection of cells
        % Binary image
            mIM = imfilter(registeredActivityMap,fspecial('average',windowSize),'replicate');
            sIM = mIM-registeredActivityMap-(offset); 
            bw = imbinarize(sIM,0); bw = imcomplement(bw);
            bw = imfill(bw,'holes'); bw = imopen(bw,strel('disk',diskRadius));
            CC = bwconncomp(bw,4);
            numPixels = cellfun(@numel,CC.PixelIdxList);
            idx = find(numPixels<minPixels);
            for i = 1:length(idx)
                bw(CC.PixelIdxList{idx(i)}) = 0;
            end
            clear('mIM','sIM','CC','numPixels','idx')
        % Segment large ROIs
            % Find large ROIs
            bwNoSeg = bw; bwSeg = bw;
            CC1 = bwconncomp(bw,4);
            numPixels = cellfun(@numel,CC1.PixelIdxList);
            largeIdx = find(numPixels>maxPixels);
            smallIdx = setdiff(1:length(numPixels),largeIdx);
            CC2 = bwconncomp(bwNoSeg,4);
            for i=1:length(largeIdx)
                bwNoSeg(CC2.PixelIdxList{largeIdx(i)}) = 0;
            end
            CC3 = bwconncomp(bwSeg,4);
            for i=1:length(smallIdx)
                bwSeg(CC3.PixelIdxList{smallIdx(i)}) = 0;
            end
            clear('bw','CC1','CC2','CC3','numPixels','largeIdx','smallIdx')
            % Segment large ROIs using maxima
            bwMaxima = imextendedmax(registeredActivityMap,Hmaxima);
            bwMaxima = imclose(bwMaxima,strel('disk',diskRadius));
            bwMaxima = imfill (bwMaxima,'holes');
            CC = bwconncomp(bwMaxima,4);
            numPixels = cellfun(@numel,CC.PixelIdxList);
            idx = find(numPixels<minPixels);
            for i=1:length(idx)
                bwMaxima(CC.PixelIdxList{idx(i)}) = 0;
            end
            activityMap2 = imcomplement(registeredActivityMap);
            bwMinima = imimposemin(activityMap2, ~bwSeg | bwMaxima);
            bwMinima = imclose(bwMinima,strel('disk',diskRadius));
            L = watershed(bwMinima,4);
            L(L==1) = 0; L(L>1) = 1; L = logical(L);
            clear('CC','idx','bwMaxima','bwMinima','activityMap2')
            % Combine segmented large ROIs with the rest of the ROIs
            CC = bwconncomp(L,4);
            numPixels = cellfun(@numel,CC.PixelIdxList);
            idx = find(numPixels<minPixels);
            for i=1:length(idx)
                L(CC.PixelIdxList{idx(i)}) = 0;
            end
            bw = bwNoSeg+L;
            clear('CC','idx','bwNoSeg','bwSeg','L')
            % Obtain cell masks
            cellROIs = bwboundaries(bw,4,'noholes');
            for i=1:length(cellROIs)
                cellROIs{i}(:,[1,2]) = cellROIs{i}(:,[2,1]);
            end
            
    ROIMap = zeros(size(registeredActivityMap,1),size(registeredActivityMap,2),'single');
    for i=1:size(cellROIs,1)
        ROIMap = ROIMap + single(poly2mask(cellROIs{i}(:,1),cellROIs{i}(:,2),size(registeredActivityMap,1),size(registeredActivityMap,2)));
    end
    
    
        
        