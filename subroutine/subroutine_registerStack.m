function [new_filename] = subroutine_registerStack(data,reference,overwrite,maxOffset,use_fft)

%% subroutine_registerStack.m
%
% Register a stack to the average projection using Matlab imaging processing
% toolbox.
%
% Note: If offset is greater than value of 'maxOffset' value, then the
%       previous frame will be used (to prevent large fluorescence
%       artifacts), and an error message will be posted.
%       If there are many missed frames, the data may be of poor
%       quality or have excessive movement
%
% Called by A_ProcessTimeSeries.m
%
% Code written by Michael Goard - updated: Oct 2016

%% Default parameters
if nargin==4
    use_fft = 1;
end
if nargin==3
maxOffset = 10; % maximum pixel offset (Default = 12 for 16x zoom)
end

if nargin==1
    reference = [];
    overwrite = 0;
elseif nargin==2
    overwrite = 0;
end

%% Load file and image parameters
filename = data.filename;
numFrames = data.numFrames;
xPixels = data.xPixels;
yPixels = data.yPixels;
image_matrix = zeros([yPixels xPixels numFrames],'uint16');
data.offsets = zeros(data.numFrames, 2);

%% Make reference frame
if isempty(reference)
    disp('generating target frame...');
    if numFrames < 1000
        idx_vec = 1:numFrames;
    else
        idx_vec = [1:floor(numFrames/1000):numFrames];
    end

    sum_proj = zeros(yPixels, xPixels, length(idx_vec), 'single');

    for i = progress(1:length(idx_vec))
        % subroutine_progressbar(i/length(idx_vec));
        sum_proj(:,:,i) = single(imread(data.filename,idx_vec(i)));
    end
    template = mean(sum_proj,3);
    % subroutine_progressbar(1);
    % close all
else
    template = reference;
end
ref_frame = zeros(size(template,1)+2*maxOffset,size(template,2)+2*maxOffset);
ref_frame(1+maxOffset:yPixels+maxOffset,1+maxOffset:xPixels+maxOffset) = template;

%% Register
disp('aligning frames...');
new_filename = [filename(1:end-4) '_registered.tif'];
for i = progress(1:numFrames)
    % if rem(i,10)==0
    %     subroutine_progressbar(i/numFrames);
    % end
    curr_frame = single(imread(filename,i));
    % Measure 2D xCorr
    if(use_fft)
        shifts = subroutine_dftregistration(fft2(template), fft2(curr_frame));
        corr_offset = -shifts(3:4);
    else
        cc = normxcorr2(template,curr_frame);
        [~,imax] = max(abs(cc(:)));
        [ypeak,xpeak] = ind2sub(size(cc),imax(1));
        corr_offset = [(ypeak-yPixels) (xpeak-xPixels)];
    end
    data.offsets(i,:) = corr_offset;
    % Determine offset and register
    if sum(abs(corr_offset)<maxOffset==[1 1])==2
        reg_frame = ref_frame;
        y_vec = 1+maxOffset-corr_offset(1):yPixels+maxOffset-corr_offset(1);
        x_vec = 1+maxOffset-corr_offset(2):xPixels+maxOffset-corr_offset(2);
        reg_frame(y_vec,x_vec) = curr_frame;
        reg_frame = reg_frame(1+maxOffset:yPixels+maxOffset,1+maxOffset:xPixels+maxOffset);
        prev_frame = reg_frame;
    else % If offset is greater than 'maxOffset', use previous frame
        disp(['Error: Frame ' num2str(i) ' offset greater than ' num2str(maxOffset) ' pixels, no registration performed'])
        if i>1
            reg_frame = prev_frame;
        else
            reg_frame = curr_frame;
            prev_frame = reg_frame;
        end
    end
    image_matrix(:,:,i) = uint16(reg_frame);
end
% subroutine_progressbar(1);
% close all

% write to Tif file (tif files >4GB supported)
disp('Writing to multi-page Tif file...')
options.big = true;
subroutine_saveastiff(image_matrix,new_filename,options);  

% delete old file
if overwrite==1
    disp('Deleting unregistered Tif file...')
    try imread(new_filename,numFrames);
        delete(filename)
        disp('Conversion complete.')
    catch disp('Error: new file appears not to have saved properly, unregistered Tif file preserved')
    end
else
    disp('Conversion complete.')
end


