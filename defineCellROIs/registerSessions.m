function [registeredProjections,registeredActivityMaps,rowShiftVector,columnShiftVector,D,B] = registerSessions(mouseName,dates,blocks)
%% Settings 

    % Registration across sessions
    maxPixelOffset = 50;
    reference = [mouseName,'_',num2str(dates(1)),'_',num2str(blocks(1))];   % Reference projection is first session
    

%% Registration across imaging sessions
    
    averageProjections = [];
    activityMaps = [];
    n = 0;
    D = [];
    B = [];
    for k=dates
        for j=blocks
            if exist(['D:\Experiments\Two-Photon\',num2str(k),'\',mouseName,'_',num2str(k),'_',num2str(j),'.mat'],'file') > 0
                load(['D:\Experiments\Two-Photon\',num2str(k),'\',mouseName,'_',num2str(k),'_',num2str(j),'.mat'])
                averageProjections = cat(3,averageProjections,mouseData.averageProjection);
                activityMaps = cat(3,activityMaps,mouseData.activityMap);
                n = n + 1;
                if strcmp([mouseName,'_',num2str(k),'_',num2str(j)],reference)
                    idx = n;
                end
                % Dates and blocks
                D = cat(1,D,k);
                B = cat(1,B,j);
            end
        end
    end

    referenceProjection = averageProjections(:,:,idx);
    referenceActivityMap = activityMaps(:,:,idx);
    clear('x','n')
    
    % Registration
    registeredProjections = [];
    registeredActivityMaps = [];
    rowShiftVector = [];
    columnShiftVector = [];
    X = fft2(referenceProjection);
    referenceProj = zeros(size(referenceProjection,1)+2*maxPixelOffset,size(referenceProjection,2)+2*maxPixelOffset);
    referenceProj(1+maxPixelOffset:size(referenceProjection,1)+maxPixelOffset,1+maxPixelOffset:size(referenceProjection,2)+maxPixelOffset) = referenceProjection;
    referenceMap = zeros(size(referenceActivityMap,1)+2*maxPixelOffset,size(referenceActivityMap,2)+2*maxPixelOffset);
    referenceMap(1+maxPixelOffset:size(referenceActivityMap,1)+maxPixelOffset,1+maxPixelOffset:size(referenceActivityMap,2)+maxPixelOffset) = referenceActivityMap;
    for i=1:size(averageProjections,3)
        % FFT on average projection
        x = fft2(single(averageProjections(:,:,i)));
        [nr,nc] = size(x);
        Nr = ifftshift(-fix(nr/2):ceil(nr/2)-1);
        Nc = ifftshift(-fix(nc/2):ceil(nc/2)-1);
        % Pixel registration
        CC = ifft2(X.*conj(x)); CCabs = abs(CC);
        [rowShift,columnShift] = find(CCabs==max(CCabs(:)),1,'first');
        rowShift = Nr(rowShift); columnShift = Nc(columnShift);
        rowShiftVector = cat(1,rowShiftVector,rowShift);
        columnShiftVector = cat(1,columnShiftVector,columnShift);
        clear('x')
        % Move average projection and activity map
        registeredProj = referenceProj;
        registeredMap = referenceMap;
        currentProj = averageProjections(:,:,i);
        currentMap = activityMaps(:,:,i);
        yIndices = 1+maxPixelOffset+rowShift:size(referenceProjection,1)+maxPixelOffset+rowShift;
        xIndices = 1+maxPixelOffset+columnShift:size(referenceProjection,2)+maxPixelOffset+columnShift;
        registeredProj(yIndices,xIndices) = currentProj;
        registeredMap(yIndices,xIndices) = currentMap;
        clear('currentProj','currentMap','yIndices','xIndices','rowShift','columnShift')
        % Register average projection and activity map
        registeredProj = registeredProj(1+maxPixelOffset:size(referenceProjection,1)+maxPixelOffset,1+maxPixelOffset:size(referenceProjection,2)+maxPixelOffset);
        registeredMap = registeredMap(1+maxPixelOffset:size(referenceActivityMap,1)+maxPixelOffset,1+maxPixelOffset:size(referenceActivityMap,2)+maxPixelOffset);
        registeredProjections = cat(3,registeredProjections,registeredProj);
        registeredActivityMaps = cat(3,registeredActivityMaps,registeredMap);
        clear('registeredProj','registeredMap')
    end
    clear('referenceProj','referenceMap')
    
    