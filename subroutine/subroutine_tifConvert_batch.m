folder_list = {'AlternatingDriftingGratingsRandom-002',...
    'AlternatingDriftingGratingsOrdered-003', 'AlternatingDriftingGratingsAOnly-004',...
    'AlternatingDriftingGratingsBOnly-005', 'SpatialMappingDriftingBars-006'};

for i = 1:length(folder_list)
    cd(folder_list{i})
    firstfile = [folder_list{i} '_Cycle00001_Ch2_000001.ome.tif'];
    subroutine_tifConvert(firstfile)
    cd ..
end


    
    