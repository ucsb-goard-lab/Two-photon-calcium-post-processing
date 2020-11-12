
function [data] = spikeInference(filename,save_flag)

% Updated 09Jul2019 changed the save from eval(['save' filename 'data']) to current, fixing bad form
% Infers spike rates from calcium imaging data
% requires function deconvolveCa in the path (dropbox>postprocessing)

if nargin == 0
    [filename,pathname] = uigetfile('.mat');
    load(filename);
    save_flag = questdlg('Save file?','Dialog box','Yes','No','Yes');
elseif nargin == 1
    save_flag = questdlg('Save file?','Dialog box','Yes','No','Yes');
end

load(filename);

dffDeconv = zeros(size(data.DFF));

for n = 1:size(data.DFF, 1)
subroutine_progressbar(n/size(data.DFF,1));
    % get trace and run deconvolution
    n
    trace = data.DFF(n,:);
    [denoised,spikes,opt] = deconvolveCa(trace, 'ar1' ,'foopsi', 'optimize_pars');
    dffDeconv(n,:) = spikes;
    
end
subroutine_progressbar(1);close all;

data.spikes = dffDeconv;


if strcmp(save_flag,'Yes')
save(filename,'data');
end
end

