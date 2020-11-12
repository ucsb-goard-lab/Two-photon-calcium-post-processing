function [warp, original, reconstructed] =  subroutine_manualAnchorPoints(original, distorted, a1, a2)
% GUI to automatically and manually create corresponding points across
% images and disply the resuting warps in real time
%
% original: template image
%
% distorted: image to be warped onto original
%
% a1,a2: previously detected corresponding points to be loaded in. (Optional)
%
% warp: struct containg warp info like vector fields, anchor points, crops, etc.
%
% original: original image but cropped to fit constraints of warping
%
% distorted: warped and cropped version of distorted image, should line up
% well with original

currVar.original = original;
currVar.distorted = distorted;
currVar.reconstructed = distorted;
[currVar.x,currVar.y] = meshgrid(1:size(original,2),  1:size(original,1));
currVar.vx = currVar.x;
currVar.vy = currVar.y;
if(nargin == 2)
    currVar.a1 = [];
    currVar.a2 = [];
else
    currVar.a1 = a1;
    currVar.a2 = a2;
end
currVar.currVec = [];
currVar.stopFlag = 0;

%% setup GUI
close all
currVar.fig=figure;
set(currVar.fig,'Position',[300 100 950 950]);
set(currVar.fig,'Color',[1 1 1])
l = 30; % leftmost
s = 30; % spacing

currVar.amapAuto = uicontrol(currVar.fig,'Style','pushbutton','Tag','amap',...
     'String','Auto Detect','Units','characters','Position',[l+s 1 20 1],'Callback',@autoDetect);

currVar.finished = uicontrol(currVar.fig,'Style','pushbutton','Units','characters',...
    'Position',[l+4*s-5 4 20 2],'String','Finished','Callback',@stopLoop);

currVar.modeSelect = uicontrol(currVar.fig,'Style','listbox','Units','characters',...
    'Position',[l+3*s 2.5 15 5.5],'String', 'vector|delete|zoom|pan','Callback',@changeMode);
set(gcf,'DeleteFcn',@stopLoop)
set(gcf,'WindowButtonDownFcn',@updateVectors)
set(gcf,'KeyPressFcn',@changeMode)


%% display image
recalculateWarp
replotImage

%% loop

while currVar.stopFlag == 0
    pause(0.5)
     if ~isempty(get(0,'CurrentFigure')) && get(currVar.modeSelect,'Value') < 3 && (isempty(currVar.currVec) || ~isvalid(currVar.currVec) || isempty(getPosition(currVar.currVec)))
        getInput;
     end
    
end

%% Subfunctions %%
    function getInput(src,evt)
        
        replotImage
        switch get(currVar.modeSelect,'Value')
            case 1
                try
                    currVar.currVec = imline;
                catch
                    %disp('input interrupted A')
                    return
                end
            case 2
                try
                    currVar.currVec = imfreehand;
                catch
                    %disp('input interrupted B')
                    return
                end
        end
    end

    function changeMode(src, evt)
        uiresume(gcf)
        currVar.currVec = [];
        switch get(currVar.modeSelect,'Value')
            case 1
                zoom off;
                pan off;
                set(gcf,'WindowButtonDownFcn',@updateVectors)
            case 2
                zoom off;
                pan off;
                set(gcf,'WindowButtonDownFcn',@updateVectors)
            case 3
                zoom on;
                h = zoom;
                set(h,'ActionPostCallback',@replotImage)
            case 4
                pan on;
                h = pan;
                set(h,'ActionPostCallback',@replotImage)
        end
    end
               
    
    function stopLoop(src,evt)
        warp.vx = currVar.vx;
        warp.vy = currVar.vy;
        warp.a1 = currVar.a1;
        warp.a2 = currVar.a2;
        [warp.xCrop, warp.yCrop] = subroutine_maxAreaCrop(currVar.reconstructed,0);
        original = currVar.original;
        reconstructed = currVar.reconstructed;
        currVar.stopFlag=1;
        if src == currVar.finished
            close
        end
    end

    function replotImage(src,evt)        
        % update labels
        currAxis = axis;  
        
        imgOverlay = imfuse(currVar.original, currVar.distorted);
        imgOverlay(:,:,1) = imgOverlay(:,:,2);
        imgOverlay(:,:,2) = imgOverlay(:,:,3);
        
        imgOverlay2 = imfuse(currVar.original, currVar.reconstructed);
        imgOverlay2(:,:,1) = imgOverlay2(:,:,2);
        imgOverlay2(:,:,2) = imgOverlay2(:,:,3);

        subplot(1,2,2)
        image(imgOverlay2)
        hold on
        if(size(currVar.a1,1) > 2)
            for i = 1:50:size(currVar.original,1)
                for j = 1:50:size(currVar.original,2)
                xPlot = [currVar.x(i,j), currVar.x(i,j) + currVar.vx(i,j)];
                yPlot = [currVar.y(i,j), currVar.y(i,j) + currVar.vy(i,j)];
                plot(xPlot, yPlot, 'Color','Red');
                end
            end
        end
        hold off
        axis square
        if min(currAxis == [0 1 0 1]) == 0
            axis(currAxis)
        end

        xticks = [ceil(min(xlim)) round(mean(xlim)) floor(max(xlim))];
        yticks = [ceil(min(ylim)) round(mean(ylim)) floor(max(ylim))];
        set(gca,'XTick',xticks)
        set(gca,'YTick',yticks)        
        set(gca,'XTickLabel',sprintf('%d|Zoom = %1.2fx|%d',xticks(1),...
            size(imgOverlay,2)/diff(xlim),xticks(3)))
        set(gca,'YTickLabel',sprintf('%d|Zoom = %1.2fx|%d',yticks(1),...
            size(imgOverlay,1)/diff(ylim),yticks(3)))
        
        subplot(1,2,1)
        image(imgOverlay)
        hold on
        for i = 1:size(currVar.a1,1)
             xPlot = [currVar.a1(i,1),currVar.a2(i,1)];
             yPlot = [currVar.a1(i,2),currVar.a2(i,2)];
             plot(currVar.a1(i,1),currVar.a1(i,2),'o','Color','red');
             plot(xPlot, yPlot, 'Color','yellow');
             plot(currVar.a2(i,1),currVar.a2(i,2),'o','Color','cyan');

        end
        hold off
        axis square
        if min(currAxis == [0 1 0 1]) == 0
            axis(currAxis)
        end

        xticks = [ceil(min(xlim)) round(mean(xlim)) floor(max(xlim))];
        yticks = [ceil(min(ylim)) round(mean(ylim)) floor(max(ylim))];
        set(gca,'XTick',xticks)
        set(gca,'YTick',yticks)        
        set(gca,'XTickLabel',sprintf('%d|Zoom = %1.2fx|%d',xticks(1),...
            size(imgOverlay,2)/diff(xlim),xticks(3)))
        set(gca,'YTickLabel',sprintf('%d|Zoom = %1.2fx|%d',yticks(1),...
            size(imgOverlay,1)/diff(ylim),yticks(3)))
        
    end

    function autoDetect(src,evt)
        [auto1,auto2] = subroutine_autoDetectAnochorPoints(original, distorted, 0);
        currVar.a1 = vertcat(currVar.a1, auto1);
        currVar.a2 = vertcat(currVar.a2, auto2);
        recalculateWarp
        replotImage
    end

    function updateVectors(src,evt)
        if strcmp(get(src,'SelectionType'),'open') % require double click
            if (~isempty(currVar.currVec) && isvalid(currVar.currVec))
                if get(currVar.modeSelect,'Value') == 1 % vector
                    position = getPosition(currVar.currVec);
                    currVar.a1 = vertcat(currVar.a1, position(2,:));
                    currVar.a2 = vertcat(currVar.a2, position(1,:));
                elseif get(currVar.modeSelect,'Value') == 2 % deleting
                    igood = false(size(currVar.a1,1),1);
                    position = getPosition(currVar.currVec);
                    for i = 1:size(igood)
                        if(inpolygon(currVar.a1(i,1),currVar.a1(i,2),position(:,1),position(:,2)))
                            igood(i) = 0;
                        else
                            igood(i) = 1;
                        end
                    end
                    currVar.a1 = currVar.a1(igood,:);
                    currVar.a2 = currVar.a2(igood,:);
                end
                recalculateWarp
                replotImage
            end
        end
    end

    function recalculateWarp(src,evt)
        if(size(currVar.a1,1) > 2)
            [currVar.vx, currVar.vy] = subroutine_generateWarpFromAnchorPoints(currVar.original, currVar.a1, currVar.a2, 'interpolation');
             currVar.reconstructed = subroutine_vectorWarp(currVar.distorted,currVar.vx, currVar.vy, 0);
        else
             currVar.reconstructed = currVar.distorted;
        end
    end
end 