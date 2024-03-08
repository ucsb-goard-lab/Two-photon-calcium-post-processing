function [] = B_DefineROI(filelist)

%% B_DefineROI.m
%
% This is actually just a wrapper now to access the actual B_DefineROI scripts.
% The newest version of B_DefineROI contains functions that don't exist in older releases of MATLAB (<2018b).
% Therefore, this will check for the version of MATLAB you're running and ping you to the correct code version.

if nargin < 1
    filelist = [];
end

current_version = version('-release');

if current_version >= "2018b"
    B_DefineROI_Current(filelist);
else
    fprintf("Using legacy version of 'B_DefineROI' because your MATLAB install (ver %s) is older than 2018b\n", current_version)
    B_DefineROI_Legacy(filelist);
end