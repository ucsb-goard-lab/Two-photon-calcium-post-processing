function [] = subroutine_moviePlayer(data,avgFrame,downSamp,saveFlag)

%% subroutine_moviePlayer.m
%
% Plays and saves movie from multi-file tif
%
% Called by A_ProcessTimeSeries.m
%
% Code written by Michael Goard - updated: Oct 2013
    
%% defaults
if nargin==1
    avgFrame = 5; % number of local frames to average
    downSamp = 1; % downsample frames for smaller size movies
	saveFlag = 1; % save to AVI
end

%% scale mean fluorescence to 1/8 max value
scaleFactor = mean(mean(data.avg_projection))*8/64;

%% Initialize figure window
fig = figure;
set(fig,'Color',[0 0 0])
set(fig,'Position',[100 100 525 525]);
subplot('Position',[0.05 0.05 0.9 0.9])
colormap('gray');
if saveFlag==1
    mov_filename = data.filename(1:end-4);
	aviobj = VideoWriter(mov_filename,'Uncompressed Avi');
    aviobj.FrameRate = data.frameRate;
    open(aviobj);
end

%% Display frames
for i = 1:data.numFrames-(avgFrame-1)
	if rem(i,downSamp)==0
		currFrame = double(imread(data.filename,i))/scaleFactor;
        
        % calculate local average frame
        for j = 1:avgFrame-1
            currFrame = currFrame+double(imread(data.filename,i+j))/scaleFactor;
        end
        currFrame = currFrame/avgFrame;
        
        % display frame
		image(currFrame);
        axis square
		title(['Frame ' num2str(i) '/' num2str(data.numFrames)],'color',[1 1 1]);
		F = getframe(fig);
        writeVideo(aviobj, F);
	end
end

%% Save AVI file
if saveFlag==1
    disp('Saving movie...')
    close(aviobj);
end
close
