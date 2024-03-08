function new_filename = subroutine_nonrigidRegisterStack(data)
% Function to warp and crop all of the frames of a multipage tiff according to a
% predetermined vector field and crop region
%
% data: struct with information on image file as well as warp parameters
%
% NOTE: if the data struct does not have a field called "warp," it should
% not be passed to this function

%% Load file and image parameters
image_matrix = zeros([length(data.warp.yCrop) length(data.warp.xCrop) data.numFrames], 'uint16');

%% Register
new_filename = [data.filename(1:end-4) '_warped.tif'];
for i = progress(1:data.numFrames)
    % if rem(i,10)==0
    %     subroutine_progressbar(i/data.numFrames);
    % end
    curr_frame = double(imread(data.filename,i));
    reg_frame = uint16(subroutine_vectorWarp(curr_frame, data.warp.vx, data.warp.vy, 0));
    image_matrix(:,:,i) = reg_frame(data.warp.yCrop, data.warp.xCrop);
end
% subroutine_progressbar(1);
% close all

% write to Tif file (tif files >4GB supported)
disp('Writing to multi-page Tif file...')
options.big = true;
subroutine_saveastiff(image_matrix,new_filename,options);  
