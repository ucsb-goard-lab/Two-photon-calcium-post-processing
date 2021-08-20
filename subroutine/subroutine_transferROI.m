function [] = subroutine_transferROI(filename,template_filename,pathname,template_pathname)
%%% Transfer cells masks from another data file (if imaging same cell population)

if nargin==0
    disp('Load data file')
    [filename,pathname] = uigetfile('.mat');
    cd(pathname);
    data = importdata(filename);
    
    disp('Load file to transfer ROIs from:')
    [template_filename,template_pathname] = uigetfile('.mat');
    cd(template_pathname);
    transfer = importdata(template_filename);
else
    cd(pathname);
    data = importdata(filename);
    if nargin > 3
        cd(template_pathname);
    end
    transfer = importdata(template_filename);
end

% save
data.cellMasks = transfer.cellMasks;
cd(pathname)
eval(['save ' data.filename(1:end-4) '_data data']);
