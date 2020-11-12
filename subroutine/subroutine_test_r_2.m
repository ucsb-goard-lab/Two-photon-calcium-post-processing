function min_corr = subroutine_test_r_2(test_vec,data,plot_flag)
%%% tests different r_neuropil values to find the vlaue that minimizes the
%%% correlation between the corrected repsonse and the neuropil
%%% Written by James Roney for Goard Lab, updated Oct 2016

if nargin==1
	[filename,pathname] = uigetfile('.mat');
	cd(pathname);
	load(filename);
    plot_flag = 1;
end

% Initialize matrix of correlation coefficients of each combination (cell x r_neuropil) 
corr_mat = zeros(length(data.cellMasks),length(test_vec));

for i = 1:length(test_vec)
    corr_mat(:,i) = subroutine_find_corr_2(test_vec(i),data,0); % save vector from find_corr to one col  
end
corr_mat(isnan(corr_mat)) = 0;
[~,idx] = min(mean(corr_mat,1));
m = test_vec(idx);
% disp(['mean r_neuropil = ' num2str(m)])

if plot_flag == 1
    plot(test_vec, mean(corr_mat,1))
end    

[~,min_idx] = min(corr_mat,[],2);
min_corr = test_vec(min_idx)';
disp(['mean r_neuropil = ' num2str(mean(min_corr))])

