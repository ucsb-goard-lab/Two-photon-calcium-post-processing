function [] = D_PlotDFF(data,fig,currPage,stopFlag)

%% D_plotDFF.m
%
% Fourth (optional) step in analysis pipeline:
% Plots fluorescence traces and associated ROIs.
% 
% Input: None (listed inputs are for GUI usage)
% 
% Output: None, only for visualization
%
% Scroll bar changes between pages (6 neurons per page). 
% Press 'Finished' to close window.
% 
% Code written by Michael Goard - updated: Oct 2013

%% Set paths
addpath(genpath('./subroutine'))

% initialize on first iteration
if nargin==0
	clear
	disp('load data file')
	[filename,pathname] = uigetfile('.mat');
	cd(pathname);
	load(filename);
	currPage = 1;
	fig = figure;
	stopFlag = 0;
    scrn_size = get(0,'ScreenSize');
	set(fig,'Position',[50 50 scrn_size(3)-100 scrn_size(4)-150]);
    set(fig,'color',[1 1 1]);
end

% stop function if button is pressed
if stopFlag==1
	close
	clear global data
	return
end

% User input
visStimFlag = 1;   % set to 1 if visual stim was present, 0 otherwise
eventFlag = 0;     % set to 1 if events were detected in extractDFF
stimTime = 2;      % on/off cycle
yPosition = -10;   % where to display in y dimension

% calculate values
numTraces = 6;    % number of traces to display simultaneously
numCells = length(data.cellMasks);
numPages = ceil(numCells/numTraces);
xAxis = [1/data.frameRate:1/data.frameRate:data.numFrames/data.frameRate];
subplot('Position',[0.025 0.25 0.35 0.6])
currIm = data.avg_projection;
maxVal = max(max(data.avg_projection));
[m,n] = size(data.avg_projection);
imagesc(currIm)
colormap('gray')
axis square

% plot traces of selected cells
for i = 1:numTraces
	subplot('Position',[0.4 0.075+(numTraces-i)*0.15 0.55 0.1])
	try plot(xAxis,data.DFF((currPage-1)*numTraces+i,:))
		yAxisVal = ylim;
        xlim([xAxis(1) xAxis(end)]);
		ylabel(['cell #' num2str((currPage-1)*numTraces+i)]);
		hold on;
        
		% plot events times
        if eventFlag==1
            eventTimes = data.eventTimes{(currPage-1)*numTraces+i};
            for j = 1:length(eventTimes)
                scatter(xAxis(eventTimes),ones(1,length(eventTimes))*yAxisVal(1)/2,5,'r','filled');
            end
        end
		
		% plot vis stim times
		if visStimFlag==1
			xaxis2 = 0:.1:xAxis(end);
			yaxis2 = xaxis2(mod(floor(xaxis2/stimTime),2)==1);
			plot(yaxis2,ones(1,length(yaxis2))*yPosition,'.','MarkerSize',1)
		end
		hold off
		
		% make circle masks for selected cells
        position = data.cellMasks{(currPage-1)*numTraces+i};
        mask = poly2mask(position(:,1),position(:,2),m,n);
        curr_ROI = mask-0.25*[mask(2:end,:); mask(end,:)]-0.25*[mask(1,:); mask(1:end-1,:)]...
			-0.25*[mask(:,2:end) mask(:,end)]-0.25*[mask(:,1) mask(:,1:end-1)];
		curr_ROI(curr_ROI~=0) = maxVal;
		[xInd,yInd] = ind2sub(size(curr_ROI),find(curr_ROI~=0));
		if max(xInd)+3>size(data.avg_projection,2)
			xPos(i) = min(xInd)-3; yPos(i) = mean(yInd);
		else xPos(i) = max(xInd)+3; yPos(i) = mean(yInd);
		end
		currIm = currIm+curr_ROI;
		currIm(currIm>maxVal) = maxVal;
	catch plot(zeros(1,size(data.DFF,2)));
		xlim([xAxis(1) xAxis(end)]);
	end
end

% plot circles and numbers of selected cells
subplot('Position',[0.025 0.25 0.35 0.6])
imagesc(currIm)
colormap('gray')
axis square
for i = 1:length(xPos)
    text(yPos(i),xPos(i),num2str((currPage-1)*numTraces+i),'color',[1 1 1]);
end

plotButton = uicontrol(fig,'Style','pushbutton','Units','normal',...
	'Position',[0.15 0.12 0.1 0.025],...
	'String','Finished',...
	'Parent',fig,...
	'Callback',@buttonCallback);

plotSlider = uicontrol(fig,'Style','slider','Units','normal',...
	'Position',[0.15 0.15 0.1 0.025],...
	'Min',1,'Max',numPages,...
	'Value',currPage,'SliderStep',[1/(numPages-1) 1/(numPages-1)],...
	'Parent',fig,...
	'Callback',@sliderCallback);

%%% callback functions
	function buttonCallback(src,evt)
		% change stopFlag
		disp('Finished')
		stopFlag = 1;
		D_PlotDFF(data,fig,currPage,stopFlag);
	end % plotButtonCallback

	function sliderCallback(hObject,eventdata,handles)
		% change cells and re-plot
		currPage = get(hObject,'Value');
		D_PlotDFF(data,fig,currPage,stopFlag);
	end % plotButtonCallback

end % end defineROI

