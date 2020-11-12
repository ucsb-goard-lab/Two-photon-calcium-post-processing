function [] = OversampleCheck(CC_threshold,distance_threshold)
%%% Checks for redundantly sampled cells based on distance and response correlation
%%% Written MG 160401

clear
close all

% Default params
if nargin==0
    CC_threshold = 0.5;       % flag pairs above this threshold
    distance_threshold = 15;  % in pixels
end

% load file
disp('Select mat file: ')
[filename,~] = uigetfile('.mat');
load(filename)

% Calculate between-cell CCs
num_cells = size(data.DFF,1);
perm_mat = nchoosek([1:num_cells],2);
CC_vec = zeros(1,length(size(perm_mat,1)));
for i = 1:size(perm_mat,1)
    CC_output = corrcoef(data.DFF(perm_mat(i,1),:),data.DFF(perm_mat(i,2),:));
    CC_vec(i) = CC_output(2);
end

% Find neuron pairs with CC > threshold
check_index = find(CC_vec > CC_threshold);
exclude_count = 0;
excluded_neurons = [];

% Check neuron pairs with high response CC
for i = 1:length(check_index)
    % Measure distance between neurons
    neuron1 = perm_mat(check_index(i),1);
    neuron2 = perm_mat(check_index(i),2);
    mask_pos1 = data.cellMasks{neuron1};
    x1 = mean(mask_pos1(:,1));
    y1 = mean(mask_pos1(:,2));
    mask_pos2 = data.cellMasks{neuron2};
    x2 = mean(mask_pos2(:,1));
    y2 = mean(mask_pos2(:,2));
    pair_distance = sqrt((x1-x2)^2+(y1-y2)^2);
    
    % If less than threshold, exclude neuron with smaller integrated DF/F
    if pair_distance < distance_threshold
        exclude_count = exclude_count+1;
        if sum(data.DFF(neuron1,:))<=sum(data.DFF(neuron2,:))
            excluded_neurons(exclude_count) = neuron1;
        else excluded_neurons(exclude_count) = neuron2;
        end
        
        disp(['neuron #' num2str(excluded_neurons(exclude_count)) ' excluded, CC: ' ...
            num2str(CC_vec(check_index(i))) ', Distance from correlated cell: ' num2str(pair_distance)])
    end
end
close

% Update data matrix and save
if ~isempty(excluded_neurons)
    keep_index = setdiff([1:num_cells],excluded_neurons);
    for i=1:length(keep_index)
        keepMasks{i} = data.cellMasks{keep_index(i)};
    end
    data.cellMasks = keepMasks;
    data.raw_F = data.raw_F(keep_index,:);
    data.neuropil_F = data.neuropil_F(keep_index,:);
    data.DFF = data.DFF(keep_index,:);
    data.DFF_raw = data.DFF_raw(keep_index,:);
    data.oversampleCheck = 'True';
else disp('No oversampling detected')
    data.oversampleCheck = 'True'; 
end

% Save
save(filename,'data')
    
