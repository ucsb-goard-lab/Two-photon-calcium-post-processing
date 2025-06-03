function img = imlongread(filepath, pageIndex)
%% imlongread.m
% Read multi-page tif stacks from file that have greater than 2^16 pages
% (the base imread function cannot go past this limit).
%
% Not tested with color, compressed, or otherwise complex image stacks --
% some of those may not work.
%
% Written DMM, May 2025

    arguments
        filepath (1,:) char
        pageIndex (1,1) double {mustBePositive, mustBeInteger}
    end
    t = Tiff(filepath, 'r');
    
    try
        t.setDirectory(pageIndex);
    catch ME
        t.close();
        error('Failed to read page %d: %s', pageIndex, ME.message);
    end
    img = t.read();
    t.close();
end