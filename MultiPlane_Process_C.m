function [] = MultiPlane_Process_C(norm_type,num_plane)
% Extract DFF from ROIs
% Run C_ExtractDFF on all files

if nargin==0
    norm_type = questdlg('Normalize fluorescence traces?','Dialog box',...
        'Whole Frame','Local Neuropil','Local Neuropil');
    num_plane = 4;     % number of imaging planes
elseif nargin==1
    num_plane = 4;     % number of imaging planes
end

for i = 1:num_plane
    cd(['plane' num2str(i)])
    
    % find tif files
    curr_dir = dir;
    file_num = 0;
    for i = 1:length(curr_dir)
        curr_idx = findstr(curr_dir(i).name,'tif');
        if ~isempty(curr_idx)
            file_num = file_num+1;
            tif_name = curr_dir(i).name;
            mat_name = [tif_name(1:end-4) '_data.mat'];
            filelist{file_num} = mat_name;
        end
    end
    
    % run time series processing
    C_ExtractDFF(filelist,norm_type)
    
    cd ..
end
