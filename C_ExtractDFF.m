function C_ExtractDFF(filelist,norm_type,smart_subtract)

%% C_ExtractDFF.m
%
% Third step in analysis pipeline:
% Extracts fluorescence traces from time series using defined ROIs.
% 
% Input(optional): filelist (user will be prompted if empty)
%                  norm_type: 'Whole Frame', 'Local Neuropil' or 'None'
% 
% Output: None - Data will be save to a MAT file.
%
% Normalization types:
%
% 'Local Neuropil':  Subtracts local neuropil pixels excluding cells (Default)
%  (see Chen TW et al., Nature 2013 for details on local neuropil subtraction)
%
% 'Whole Frame': Divides each ROI by the average for the entire frame
%
% 'None': Just extract raw fluorescence with no normalization
% 
% Code written by Michael Goard - updated: June 2017

%% Determine type of normalization
if nargin < 2
    norm_type = questdlg('Normalize fluorescence traces?','Dialog box',...
        'Local Neuropil','Whole Frame','None','Local Neuropil');
end
if nargin < 3 && strcmp(norm_type,'Local Neuropil')
    smart_subtract = questdlg('Weight subtraction to minimize signal-noise correlation?','Dialog box',...
        'Yes','No','Yes');
else smart_subtract = 'No';
end
switch norm_type
    case 'Local Neuropil' % normalize to neuropil (local area with cells excluded)
        norm_frame = 0;
        norm_neuropil = 1;
        r_neuropil = 0.7;  % neuropil weight factor (default = 0.7)
        dil_size = 30;     % number of pixels for local dilation (default = 30)
    case 'Whole Frame' % normalize to entire frame
        norm_frame = 1;
        norm_neuropil = 0;
    case 'None'
        norm_frame = 0;
        norm_neuropil = 0;
end

%% get filenames
if nargin==0
    [filelist,pathname] = uigetfile('.mat','MultiSelect','on');
    cd(pathname);
end
if iscell(filelist)==0
    lengthList = 1;
else
    lengthList = length(filelist);
end

%% Extract DF/F in several discrete chunks
for filenum = 1:lengthList
    
    % load file
    disp(['analyzing file ' num2str(filenum) '/' num2str(lengthList) '...'])
    if iscell(filelist)==0
        load(filelist);
        filename = filelist;
    else
        load(filelist{filenum});
        filename = filelist{filenum};
    end
    [m,n] = size(data.avg_projection);
    
    % extract raw fluorescence values from tif
    disp('Extracting fluorescence from cells masks...')
    numCells = length(data.cellMasks);
    data.raw_F = zeros(numCells,data.numFrames);
    data.normtype = norm_type;
    
    % create neuropil mask
    if norm_neuropil==1
        data.neuropil_F = zeros(numCells,data.numFrames);
        all_cell_mask = zeros(m,n);
        for j = 1:numCells
            position = data.cellMasks{j};
            [curr_mask] = logical(poly2mask(position(:,1),position(:,2),m,n));
            all_cell_mask = all_cell_mask+curr_mask;
        end
        all_cell_mask(all_cell_mask>1) = 1;
        no_cell_mask = ~all_cell_mask;
    end
    
    % create mask matrix for all cells
    disp('Creating mask matrix...')
    mask = zeros(m,n,numCells);
    for j = 1:numCells
        position = data.cellMasks{j};
        mask(:,:,j) = poly2mask(position(:,1),position(:,2),m,n);
        if norm_neuropil==1
            if j==1
                neuropil_mask = zeros(m,n,numCells);
                neuropil_mask = logical(neuropil_mask);
            end
            dilated_mask = imdilate(mask(:,:,j),ones(dil_size));
            neuropil_mask(:,:,j) = and(dilated_mask,no_cell_mask);
        end     
    end
    mask = logical(mask);
    mask = reshape(mask, [], numCells);
    if norm_neuropil==1
        neuropil_mask = reshape(neuropil_mask, [], numCells);
    end
    
    % extract raw fluorescence
    disp('Extracting raw fluorescence...')
    block_size = 500;    % frames in each block (to avoid memory crash)
    num_blocks = ceil(data.numFrames/block_size);
    meanF = mean(mean(data.avg_projection));
    for i = 1:num_blocks
        idx = ((i-1)*block_size+1:min(i*block_size, data.numFrames));
        curr_block_size = length(idx);
        curr_chunk = zeros(data.yPixels,data.xPixels,curr_block_size);
        for n = 1:curr_block_size
            curr_chunk(:,:,n) = imread(data.filename,idx(n));
        end 
        
        curr_chunk = single(reshape(curr_chunk, [], curr_block_size));%unroll pixels
        
        % normalize according to specified method
        if norm_frame==1 
            norm_vec = mean(curr_chunk)/meanF; % timecouse of mean flourescence
            norm_mat = repmat(norm_vec, size(curr_chunk,1),1);
            curr_chunk = curr_chunk./norm_mat;
        end
     
        for j = 1:numCells
            data.raw_F(j,idx) = sum(curr_chunk(mask(:,j),:))/sum(mask(:,j));%collapse into 1D timecourse and save
            if rem(j,10)==0
                subroutine_progressbar((numCells*(i-1)+j)/(numCells*num_blocks));
            end
            if norm_neuropil==1
                data.neuropil_F(j,idx) = sum(curr_chunk(neuropil_mask(:,j),:))/sum(neuropil_mask(:,j));
            end
        end
        if norm_neuropil==1
            data.neuropil_F(isnan(data.neuropil_F)) = 0;
        end
    end
    subroutine_progressbar(1); close all
    
    % calculate DFF
    disp('Calculating DF/F...')
    DFF = zeros(numCells,data.numFrames);
    
    % determine optimum r_neuropil
    if strcmp(smart_subtract,'Yes') && norm_neuropil==1
        test_vec = [0:0.01:1];
        r_neuropil = subroutine_test_r(test_vec,data,0);
        data.r_neuropil = r_neuropil;
    elseif strcmp(smart_subtract,'No') && norm_neuropil==1
        r_neuropil = ones(1,numCells)*r_neuropil;
        data.r_neuropil = r_neuropil;
    end    
    
    for j = 1:numCells
        raw_F = data.raw_F(j,:);
        
        % Find F0 using mode of distribution estimate
        [KSD,Xi] = ksdensity(raw_F);
        [~,maxIdx]= max(KSD);
        F0 = Xi(maxIdx);
        
        % Raw DF/F calculation
        data.DFF_raw(j,:) = (raw_F-F0)/F0*100;
        
        % subtract neuropil response
        if norm_neuropil==1
            neuropil_F = data.neuropil_F(j,:);
            norm_F = raw_F-r_neuropil(j)*neuropil_F+r_neuropil(j)*mean(neuropil_F);
            
            % Find F0 using mode of distribution estimate
            [KSD,Xi] = ksdensity(norm_F);
            [~,maxIdx]= max(KSD);
            F0 = Xi(maxIdx);
            
            % DF/F calculation
            DFF(j,:) = (norm_F-F0)/F0*100;
        else
            DFF(j,:) = data.DFF_raw(j,:);
        end       
    end
    
    data.DFF = DFF;
    eval(['save ' filename ' data'])
    disp('File finished')
end
