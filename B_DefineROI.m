function [] = B_DefineROI(filelist)

%% B_DefineROI.m
%
% Second step in analysis pipeline:
% Defines ROIs using average projection and/or activity map
%
% Instructions:
% 1. Open data file (created by A_ProcessTimeSeries).
% 2. GUI will open showing average projection and activity map.
% 3. Average projectiona dn activity map images can be toggled ON and OFF
%    by pressing on the image name button.
% 4. Image intensity can be adjusted using slider.
% 5. Automatic detection: Auto detection is enabled by checking the auto
%    detect box underneath the image. Note that the activity map generally
%    provides much superior automatic ROIs compared to the avg projection.
%
%    Parameters: [Best values will change with zoom and resolution]
%    Threshold offset: local threshold, more negative => more stringent
%    Threshold window: Size of local adaptive threshold window
%    Min pixels: Minimum ROI size (to avoid selecting processes)
%    Max pixels: ROIs larger than this value are targetted for segmentation
%    H_maxima: Segmentation maxima threshold (generally stays constant)
%
%    Once cells are selected, you can accept or reject them by
%    pushing the 'Finished' button (other actions unavailable until finish
%    button is pressed).
%
% 6. Manual selection: Once cells have been detected automatically, they
%      can be fine-tuned with manual selection.
%
%    Adding ROIs: Click and drag on image to create an ellipse,
%      double-click to confirm selection.
%
%    Deleting ROIs: Make an ellipse that completely encircles the
%      to-be-deleted ROI and double click
%
% 7. When finished with ROIs, press 'Finished' button and follow the prompt
%    to save ROIs to the data file (cellMasks field)
%
% Code written by Michael Goard & Gerald Pho - updated: Oct 2013

%% get list of all files from user
if nargin == 0
    disp('Select data files: ')
    [filelist,pathname] = uigetfile('.mat','MultiSelect','on');
else
    pathname = pwd;
end

if iscell(filelist)==0
    lengthList = 1;
    template_filename = filelist;
else
    lengthList = length(filelist);
    template_filename = filelist{1};
end
cd(pathname);

%% define ROIs for first recording
disp('Define ROIs on template imaging session: ')
template_filename = subroutine_interactiveROI(template_filename); % load interactive ROI selector
if isempty(template_filename)
    return
end

%% transfer ROIs
disp('transferring ROIs...')
template_pathname = pwd;
for i=1:lengthList
    if iscell(filelist)==0
        filename=filelist;
    else
        filename=filelist{i};
    end
    subroutine_transferROI(filename,template_filename,pathname,template_pathname);
end
disp('Done.')
