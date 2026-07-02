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

% data.warp.vx / data.warp.vy are the same for every frame in the stack,
% so the query grid used by interp2 (equivalent to what
% subroutine_vectorWarp rebuilds internally on every call) only needs to
% be computed once here rather than once per frame.
[x, y] = meshgrid(1:size(image_matrix,2), 1:size(image_matrix,1));
Xq = x - data.warp.vx;
Yq = y - data.warp.vy;

for i = progress(1:data.numFrames)

    if data.numFrames < 2^16
        curr_frame = double(imread(data.filename,i));
    elseif data.numFrames >= 2^16
        curr_frame = double(imlongread(data.filename, i));
    end

    reg_frame = uint16(interp2(curr_frame, Xq, Yq));
    image_matrix(:,:,i) = reg_frame(data.warp.yCrop, data.warp.xCrop);
end
% subroutine_progressbar(1);
% close all

% write to Tif file (tif files >4GB supported)
disp('Writing to multi-page Tif file...')
options.big = true;
subroutine_saveastiff(image_matrix,new_filename,options);  
