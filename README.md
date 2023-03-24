# Two-photon-calcium-post-processing

Developed by MG

Feel free to use and distribute (for non-commercial purposes).

## Use

1. Start with all of your image files in a multi-page TIF file. `subroutine_tifConvert.m` will convert single-page TIFs to a multi-page TIF if necessary.
1. Run `A_ProcessTimeSeries.m`. This program performs several operations to prepare for ROI determination:
    1. Extract parameters from TIF header and microscope files Important: If you are not using PrairieView to collect your data, you will need to alter program lines 90-119 to correctly determine your frame rate (or enter manually)
    1. Image registration (rigid or non-rigid).
        * **Rigid registration:** for aligning images within a session using linear translation
        * **Non-rigid registration:** for aligning images between sessions (separated by time) using a warp transform. This is useful for tracking the activity of the same neurons over days or weeks.
    1. Calculate kurtosis map. This will be used for ROI selection in subsequent processing.
    1. Measure photobleaching
    1. Create a movie of the time series (optional)
1. Run `B_DefineROI.m`. This program used the kurtosis map to perform semi-automated ROI detection. More detailed instructions can be found in the program comments.
    1. Open the data file (created by `A_ProcessTimeSeries`)
    1. Auto detection is enabled by checking the auto detect box underneath the image. Note that the activity map generally provides much superior automatic ROIs compared to the avg projection.
    1. Parameters. Best values will change with zoom and resolution.
        * **Threshold offset:** local threshold, more negative -> more stringent
        * **Threshold window:** Size of local adaptive threshold window
        * **Min pixels:** Minimum ROI size (to avoid selecting processes)
        * **Max pixels:** ROIs larger than this value are targetted for segmentation
        * **H_maxima:** Segmentation maxima threshold (generally stays constant)
    1. Once cells are selected, you can accept or reject them by pushing the 'Finished' button (other actions unavailable until finish button is pressed).
    1. Manual selection: Once cells have been detected, they can be fine-tuned with manual selection:
        * **Adding ROIs:** Click and drag on image to create an ellipse, double-click to confirm selection.
        * **Deleting ROIs:** Make an ellipse that completely encircles the to-be-deleted ROI and double click.
    1. When finished with ROIs, press 'Finished' button and follow the prompt to save ROIs to the data file (cellMasks field)
1. Run `C_ExtractDFF`. This program extracts the DF/F traces from the defined ROIs
    1. Neuropil subtraction: Several methods available, ‘local neuropil’ is recommended
    1. If 'local neuropil' is selected, you have the option of dynamically weighting the subtraction multiplier to minimize the correlation between the ROI and local neuropil (recommended)
1. Run `D_PlotDFF` (optional). For visualizing DF/F traces and spatial position of individual neurons

## Notes

* Multiplane Process performs same pipeline for multiple planes (volume imaging), see comments.
* OversampleCheck ensures that ROIs were not redundantly sampled by looking for ROIs with both close physical proximity and high signal correlation.
