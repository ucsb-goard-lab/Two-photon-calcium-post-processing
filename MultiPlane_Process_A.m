function [] = MultiPlane_Process_A(num_plane,tif_convert,preprocess)
% Convert .tif files and sort into folders by imaging plane
% Run A_ProcessTimesSeries on all files

if nargin==0
    num_plane = 4;     % number of imaging planes
    tif_convert = 1;   % convert tifs from Prairie format to multipage
    preprocess = 1;    % run batchProcessTimeSeries.m
end

% get folder names
parent_dir = pwd;
curr_directory = dir;
num_sessions = size(curr_directory,1)-2;
for i = 3:2+num_sessions
    folder_list{i-2} = curr_directory(i).name;
end

% convert .tif files
if tif_convert==1
    for i = 1:num_sessions
        cd(folder_list{i})
        subroutine_tifconvert_multiplane(num_plane,folder_list{i})
        disp(['Session #' num2str(i) ' converted...'])
        cd ..
    end
end

% create plane folders
for i = 1:num_plane
    mkdir(['plane' num2str(i)])
    plane_folder_list{i} = ['plane' num2str(i)];
end

% Sort into folders by imaging plane
try
    for i = 1:num_plane
        for j = 1:num_sessions
            % move tif
            source = [parent_dir '\' folder_list{j} '\' folder_list{j} '_plane' num2str(i) '.tif'];
            destination = [parent_dir '\' plane_folder_list{i}];
            movefile(source,destination,'f');
            
            % move config file
            source = [parent_dir '\' folder_list{j} '\' folder_list{j} 'Config.cfg'];
            destination = [parent_dir '\' plane_folder_list{i}];
            copyfile(source,destination,'f');
        end
        disp(['Plane #' num2str(i) ' sorted...'])
    end
catch
    disp('Sorting failed:')
    disp(['Imaging session #' num2str(j)])
    disp(['Imaging plane #' num2str(i)]);
end

% run preprocessing code
if preprocess==1
    register_flag = 'Yes';
    movie_flag = 'Yes'; 
    for i = 1:num_plane
        cd(['plane' num2str(i)])
        
        % find tif files
        curr_dir = dir;
        file_num = 0;
        for i = 1:length(curr_dir)
            curr_idx = findstr(curr_dir(i).name,'tif');
            if ~isempty(curr_idx)
                file_num = file_num+1;
                filelist{file_num} = curr_dir(i).name;
            end
        end
        
        % run time series processing
        map_type = 'mDFF';  % type of activity map to use in preprocessing step
        A_ProcessTimeSeries(filelist,register_flag,movie_flag,map_type)
        
        cd ..
    end
end
