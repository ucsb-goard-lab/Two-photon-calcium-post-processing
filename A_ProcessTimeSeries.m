function [] = A_ProcessTimeSeries(filelist,register_flag,nonrigid_flag,movie_flag)

%% A_ProcessTimeSeries.m
%
% First step in analysis pipeline:
% Extracts calcium imaging data from multi-page TIFs, performs X-Y
% registration, and calculates activity map (using local corr or modified
% DF/F) for further segmentation into ROIs
%
% Input:
% filelist: 1xN Cell array containing filenames as strings. If no input is
% given, user will be prompted to load file from current folder
%
% Multiple files can be batch processed, but files *must* belong to same
% imaging plane. If you wish to process multiple files from different
% imaging planes, run function within a loop.
%
% register_flag: (0,1) Whether to perform image registration (recommended,
% but increases processing time)
%
% nonrigid_flag: Whether to warp seperate files together using nonrigid
% registration. Use for aligning corresponding recordings from different
% sessions. Note: Computer Vision Systems toolbox required for this step.
%
% movie_flag: (0,1) Whether to save an avi movie file of time series
%
% Output: None - Data will be saved to a MAT file.
%
% Code written by Michael Goard - updated: Oct 2016
% Nonrigid registration added by James Roney - June 2017

%% Set paths
addpath(genpath('./subroutine'))

%% Load files
if nargin==0
    filelist = uigetfile('.tif','MultiSelect','on');
    nonrigid_flag = 'No';
    register_flag = questdlg('Perform X-Y registration (movement correction)?','Dialog box','Yes','No','Yes');
    if iscell(filelist)
        nonrigid_flag = questdlg('Perform Nonrigid Registration (for aligning seperate recordings)?','Dialog box','Yes','No','Yes');
    end
    movie_flag = questdlg('Create movie?','Dialog box','Yes','No','Yes');
elseif nargin ==1
    register_flag = questdlg('Perform X-Y registration (movement correction)?','Dialog box','Yes','No','Yes');
    if iscell(filelist)
        nonrigid_flag = questdlg('Perform Nonrigid Registration (for aligning seperate recordings)?','Dialog box','Yes','No','Yes');
    end
    movie_flag = questdlg('Create movie?','Dialog box','Yes','No','Yes');
end

if(strcmp(nonrigid_flag, 'Yes'))
    i = listdlg('PromptString', 'Select master recording:','SelectionMode','single','ListString',filelist);
    master = filelist{i};
    filelist{i} = filelist{1};
    filelist{1} = master; %shift master file to be in 1st index
end

%% Calculate length of file list
if iscell(filelist)==0
    lengthList = 1;
else
    lengthList = length(filelist);
end

%% Extract time series parameters from TIF file and save to data structure
for i = 1:lengthList
    
    %% Determine filename
    if iscell(filelist)==0
        data.filename = filelist;
    else
        data.filename = filelist{i};
    end
    
    %% Attempt to extract number of frames and image size from TIF header
    % If TIF header cannot be read, prompt user for values
    try
        header = imfinfo(data.filename);
        data.numFrames = length(header);
        data.xPixels = header(1).Width;
        data.yPixels = header(1).Height;
    catch
        data.numFrames = input('Enter number of frames: ');
        data.xPixels = input('Enter number of pixels (X dimension): ');
        data.yPixels = input('Enter number of pixels (Y dimension): ');
    end
    data.map_type = 'kurtosis';
    
    %% Attempt to extract frame rate from cfg file (PrairieView format)
    % If cfg file cannot be read, prompt user for frame rate
    directory = dir;
    for j = 1:length(directory)
        if ~isempty(strfind(directory(j).name,'env')) && sum(cfg_idx)<1
            cfg_idx(j) = 1;
        else
            cfg_idx(j) = 0;
        end
    end
    if sum(cfg_idx)==1
        cfg_filename = directory(cfg_idx==1).name;
    elseif sum(cfg_idx)>1
        cfg_filename = directory(cfg_idx==1).name;
    else
        cfg_filename = [];
    end
    if ~isempty(cfg_filename)
        cfg_file = importdata(cfg_filename);
        for j = 1:length(cfg_file)
            if strfind(cfg_file{j},'repetitionPeriod') > 0
                cfg_line = cfg_file{j};
                index = strfind(cfg_line,'repetitionPeriod');
                data.frameRate = 1/sscanf(cfg_line(index:end),'repetitionPeriod="%f"');
                if isinf(data.frameRate)
                    data.frameRate = input('Enter frame rate (Hz): ');
                end
            end
        end
    else
        data.frameRate = input('Enter frame rate (Hz): ');
    end
    
    %% Perform X-Y Registration (movement correction)
    if strcmp(register_flag,'Yes')
        disp('Performing X-Y registration...')
        if i==1 || strcmp(nonrigid_flag,'Yes')
            reference = [];
        end
        overwrite = 1;
        maxOffset = 25;
        [new_filename] = subroutine_registerStack(data,reference,0,maxOffset,1);
        data.filename = new_filename;
        if strcmp(nonrigid_flag,'Yes')
            data.filename = [data.filename(1:end-4) '_warped.tif'];
        end
        if lengthList==1
            filelist = data.filename;
        else
            filelist{i} = data.filename;
        end
    end
    
    %% Calculate kurtosis map
    
    % mean frame flourescence (for measuring photobleaching)
    frame_F = zeros(1,data.numFrames);
    
    % Params
    win = 7;             % in pixels (e.g., default: 7x7 neighborhood)
    block_size = 1000;    % frames in each block (to avoid memory crash)
    
    % Initalize
    num_blocks = ceil(data.numFrames/block_size);
    k_xy = zeros(data.yPixels,data.xPixels); % activity map
    avg_projection = zeros(data.yPixels,data.xPixels);
    frame_F = [];
    disp('Calculating activity map...')
    
    for j = 1:num_blocks
        subroutine_progressbar(j/num_blocks);
        idx_vec = (j-1)*block_size+1:min(j*block_size,data.numFrames);
        curr_block_size = length(idx_vec);
        tc = zeros(data.yPixels,data.xPixels,curr_block_size, 'single');
        
        for n = 1:curr_block_size
            tc(:,:,n) = single(imread(data.filename,idx_vec(n)));
        end 
        
        % average projection
        avg_projection = avg_projection+sum(tc,3);
        
        % mean fluorescence across frame
        frame_F = cat(2,frame_F,squeeze(mean(mean(tc,1),2))');
        
        % filter
        kernel = ones(win,win); % rectangular kernal
        for n = 1:curr_block_size
            tc(:,:,n) = imfilter(tc(:,:,n),kernel,'same')/sum(sum(kernel));
        end
        
        % Kurtosis
        k_image = kurtosis(tc,[],3);
        
        % Add to running average
        k_xy = k_xy+k_image*curr_block_size;
    end
    
    subroutine_progressbar(1);
    close all
    
    data.avg_projection = avg_projection/data.numFrames;
    data.frame_F = frame_F;
    reference = data.avg_projection;
    
    %% plot fluorescence over time (To look for photobleaching)
    if lengthList == 1
        plot(frame_F,'linewidth',2)
        F_fit = polyfit(1:data.numFrames,frame_F,1);
        PhotoBl = round((F_fit(1)*data.numFrames)/F_fit(2)*100);
        ylim([0 max(frame_F)*1.25])
        title(['Fluorescence timecourse, Photobleaching = ' num2str(PhotoBl) '%'])
        xlabel('Frame #')
        ylabel('Raw fluorescence')
        set(gcf,'color',[1 1 1])
        saveas(gcf,'Fluorescence_timecourse')
        close
    end
    
    % Divide activity map by frame number and save to data structure
    k_xy = k_xy/data.numFrames;
    k_xy(isnan(k_xy)) = 0;
    data.activity_map = k_xy;
                                                                              
%    % where do you want to save it
%     if ~ispc
%         waitfor(msgbox('Choose where you want to save the figures'));       % Added by Santi 
%     end                                                                     % Added by Santi
%     current_path = pwd;                                                     % Added by Santi
%     new_path = uigetdir('Choose where you want to save the figures'); 
                                                               
                                                                                                                                             
    %% show movie
    if strcmp(movie_flag,'Yes')
        disp('Writing video...')
        avg_frame = 10;   % number of frames to average for movie
        down_samp = 10;  % down sample frames (for smaller movie)
        save_flag = 1;   % save movie                                                   
        subroutine_moviePlayer(data,avg_frame,down_samp,save_flag)
    end
    
    %% Plot
    if lengthList==1
        subplot(1,2,1);
        imagesc(data.avg_projection)
        colormap('gray')
        title('Average Projection')
        axis square
        subplot(1,2,2);
        norm_map = data.activity_map;
        norm_map = norm_map-min(min(norm_map));
        norm_map = norm_map/max(max(norm_map));
        red_activity_map = cat(3,norm_map,zeros(size(norm_map)),zeros(size(norm_map)));
        image(red_activity_map)
        title('Activity Map')
        axis square
        set(gcf,'Position',[100 100 1600 850])
        set(gcf,'color',[1 1 1])
        saveas(gcf,'Activity_map')
        close
    end
    
    %% save
    eval(['save ' data.filename(1:end-4) '_data data']);
    clear data
end

if lengthList > 1 
    if ~strcmp(nonrigid_flag,'Yes')
        %% Combine activity maps across multiple files
        disp('Calculating mean activity map across files')
        frame_F_allFiles = [];
        for i = 1:lengthList
            filename = filelist{i};
            load([filename(1:end-4) '_data.mat']);
            if i==1
                mean_activity_map = zeros(data.yPixels,data.xPixels);
                mean_avg_projection = zeros(data.yPixels,data.xPixels);
            end
            mean_activity_map = mean_activity_map+data.activity_map;
            mean_avg_projection = mean_avg_projection+data.avg_projection;
            frame_F_allFiles = [frame_F_allFiles data.frame_F];
            clear data
        end
        mean_activity_map = mean_activity_map/lengthList;
        mean_avg_projection = mean_avg_projection/lengthList;
        for i = 1:lengthList
            filename = filelist{i};
            load([filename(1:end-4) '_data.mat']);
            data.activity_map = mean_activity_map;
            data.avg_projection = mean_avg_projection;
            save([filename(1:end-4) '_data.mat'],'data')
        end
    elseif strcmp(nonrigid_flag,'Yes')
        %%initialize master file data
        filename = filelist{1};
        load([filename(1:end-4) '_data.mat']);

        data.warp.vx = zeros(data.yPixels, data.xPixels);
        data.warp.vy = zeros(data.yPixels, data.xPixels);
        data.warp.a1 = [];
        data.warp.a2 = [];
        data.warp.xCrop = 1:data.xPixels;
        data.warp.yCrop = 1:data.yPixels;
        save([data.filename(1:end-4) '_data.mat'],'data')

        target = data.avg_projection;
        new_avg_proj = data.avg_projection;
        new_activity_map = data.activity_map;
        all_activity_map = data.activity_map;
        totalCropX = data.warp.xCrop;
        totalCropY = data.warp.yCrop;
        frame_F_allFiles = [];

        %first loop to compute warps + crops + averages
        for i = 2:length(filelist)
            filename = filelist{i};
            load([filename(1:end-4) '_data.mat']);
            [warp, ~, recon] = subroutine_manualAnchorPoints(mat2gray(target), mat2gray(data.avg_projection));

            totalCropX = intersect(totalCropX, warp.xCrop);
            totalCropY = intersect(totalCropY, warp.yCrop);

            new_avg_proj = new_avg_proj + recon;

            am_warped = subroutine_vectorWarp(data.activity_map,warp.vx, warp.vy,0);
            new_activity_map = new_activity_map + am_warped;
            all_activity_map(:,:,i) = am_warped;

            frame_F_allFiles = [frame_F_allFiles data.frame_F];

            data.warp = warp;
            save([data.filename(1:end-4) '_data.mat'],'data')
        end

        %second loop to execute warps
        for i = 1:length(filelist)
            filename = filelist{i};
            load([filename(1:end-4) '_data.mat']);
            data.warp.xCrop = totalCropX;
            data.warp.yCrop = totalCropY; 
            data.filename = subroutine_nonrigidRegisterStack(data);
            data.avg_projection = new_avg_proj(totalCropY, totalCropX)/length(filelist);
            data.avg_projection(isnan(data.avg_projection)) = mean(mean(data.avg_projection, 'omitnan')); %Just in case the crop missed something
            data.activity_map = new_activity_map(totalCropY, totalCropX)/length(filelist);
            data.activity_map(isnan(data.activity_map)) = mean(mean(data.activity_map, 'omitnan'));
            data.all_activity_map = all_activity_map(totalCropY, totalCropX,i);
            data.all_activity_map(isnan(data.all_activity_map)) = mean(mean(data.all_activity_map, 'omitnan'));
            data.xPixels = size(data.avg_projection,2);
            data.yPixels = size(data.avg_projection,1);
            save([data.filename(1:end-4) '_data.mat'],'data')
        end
    end
    %% Plot fluorescence time course
    plot(frame_F_allFiles,'linewidth',2)
    F_fit = polyfit([1:length(frame_F_allFiles)],frame_F_allFiles,1);
    PhotoBl = round((F_fit(1)*length(frame_F_allFiles))/F_fit(2)*100);
    ylim([0 max(frame_F_allFiles)*1.25])
    title(['Fluorescence timecourse, Photobleaching = ' num2str(PhotoBl) '%'])
    xlabel('Frame #')
    ylabel('Raw fluorescence')
    set(gcf,'color',[1 1 1])
    saveas(gcf,'Fluorescence_timecourse')
    close

    %% Plot
    subplot(1,2,1);
    imagesc(data.avg_projection)
    colormap('gray')
    title('Average Projection')
    axis square
    subplot(1,2,2);
    norm_map = data.activity_map;
    norm_map = norm_map-min(min(norm_map));
    norm_map = norm_map/max(max(norm_map));
    red_activity_map = cat(3,norm_map,zeros(size(norm_map)),zeros(size(norm_map)));
    image(red_activity_map)
    title('Activity Map')
    axis square
    set(gcf,'Position',[100 100 1600 850])
    set(gcf,'color',[1 1 1])
    saveas(gcf,'Activity_map')
    close       
    
end


