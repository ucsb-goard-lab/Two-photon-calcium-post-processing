function final_corr = subroutine_find_corr(r_neuropil,data,print_flag)
%%% Finds the correaltion coefficient for a specific r_neuropil value
%%% Called by subroutine_test_r.m
%%% Written by James Roney for Goard Lab, updated Oct 2016

if nargin==1
	[filename,pathname] = uigetfile('.mat');
	cd(pathname);
	load(filename);
    save_flag = 1; 
    print_flag = 1;
end

%Initialize vector of correlation coefficients
test_F = data.raw_F - r_neuropil*data.neuropil_F;
corr = zeros(length(data.cellMasks),1);

%Add squared correlation coefficient or each cell
for i = 1:length(data.cellMasks)
    j = corrcoef(test_F(i,:), data.neuropil_F(i,:)); % calculate correlation coeff matrix
    corr(i) = j(2).^2; % use j(1,2) to get correlation b/w 2 diferent series
end
final_corr = corr;  

if print_flag ==1
    disp(['avg corr = ' num2str(mean(corr))])
end    

