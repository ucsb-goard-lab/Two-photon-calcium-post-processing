function [new_filename] = subroutine_tifConvert(firstfile, save_directory)
% Convert individual tifs into a multi-page tif file
% Uses subroutine_loadtiff.m and subroutine_saveastiff.m for files >4GB
% Code written by Michael Goard - last update: Oct 2016
%                                              Nov 2020 - Added option for choosing a save directory KS

% load file name
if nargin==0 || isempty(firstfile)
    disp('Load first file')
    [firstfile,~] = uigetfile('.tif');
end

% choose current directory if save directory not provided
if nargin < 2 || isempty(save_directory)
    save_directory = pwd;
end
% find indices and initialize
underscore_index = find(firstfile=='_');
new_filename = [firstfile(1:underscore_index(1)-1) '.tif'];

% where do you want to save it
% if ~ispc; waitfor(msgbox('Choose where you want to save the multi-tiffr')); end % these two lines removed on 11Nov2020 KS
% new_path = uigetdir('Choose where you want to save the multi-tiff');
new_filename = strcat(save_directory,'/',new_filename);

number_idx = [find(firstfile=='.')-6:find(firstfile=='.')-1];
%number_idx = [find(firstfile=='.')-5:find(firstfile=='.')-1];


% determine number of frames
numFrames = 0;
stop_flag = 0;
filename = firstfile;
while stop_flag==0
    if exist(filename,'file')==2
        numFrames = numFrames+1;
        filename(number_idx)=num2str(str2num(filename(number_idx))+1,'%06d');
        %filename(number_idx)=num2str(str2num(filename(number_idx))+1,'%05d');
    elseif exist(filename,'file')==0
        stop_flag = 1;
    end
end

% initalize image matrix
filename = firstfile;
header = imfinfo(filename);
xPixels = header(1).Width;
yPixels = header(1).Height;
image_matrix = zeros([yPixels xPixels numFrames],'uint16');

% read tifs itno uint16 matrix
disp('Reading single-page Tif files...')
for i = 1:numFrames
    image_matrix(:,:,i) = imread(filename);
    filename(number_idx)=num2str(str2num(filename(number_idx))+1,'%06d');
    %filename(number_idx)=num2str(str2num(filename(number_idx))+1,'%05d');

    if rem(i,10)==0
        subroutine_progressbar(i/numFrames);
    end
end
subroutine_progressbar(1); 
close all

% write to tif file (tif files >4GB supported)
disp('Writing to multi-page Tif file...')
options.big = true;
subroutine_saveastiff(image_matrix,new_filename,options);  
    
% delete single files
disp('Deleting single-page Tif files...')
try imread(new_filename,numFrames);
    filename = firstfile;
    for i = 1:numFrames
        delete(filename)
        filename(number_idx)=num2str(str2num(filename(number_idx))+1,'%06d');
        %filename(number_idx)=num2str(str2num(filename(number_idx))+1,'%05d');

        if rem(i,10)==0
            subroutine_progressbar(i/numFrames);
        end
    end
    subroutine_progressbar(1);
    close all
    disp('Conversion complete.')
catch
    disp('Error: new file appears not to have saved properly, single-page Tif files preserved')
end
