% A quick overview of ICM and the data

% ICM image data analysis is broken into stages: Pre-processing,
% PCA, then ICA. At each stage you can look at various things.
% There are tabs at the bottom that control the display and give you access
% to the run buttons. You can just click run ica and everything will get
% run sequentially. 
%   When you have the PCA or ICA tabs open the viewer shows you the weights
% of each components. You can click through with the slider at the bottom
% and view different components. The Component plot will show you the
% current component.
%   There is also a 3D plot so you can look at the components in that
% space. You can change which components you want to look at, and theres a
% rotation button (for help visualizing). The 3D plot will change depending
% if you have the PCA or ICA tab open.
%   Once the ICA analyis is done you can click on calc rois button and it
% will come up with rois for each component (see
% calc_rois_from_components). You can also make your own ROIs and different
% ROI sets. Just use the mouse on the image to manipulate, and create ROIs.
% press ctrl+delete to delete the currently selected rois. You can add or
% delete roi sets with the + and - buttons below the roi set list.
%   This is still very much a work in progress, so forgive me for bugs and
% things that are incomplete. Maybe we should put a versioning system
% together if you guys are interested in further developing this.

%% ICM Example

% Start an ICM 
icm = ImagingComputationalMicroscope();

%% Loading Data
% ICM is designed to be both a useful GUI and a programatically accessible
% interface to ICA based image analysis. All GUI functions call matlab
% functions, which can be called from command line or in scripts.
% Open the sample data using the ICM menu: 
% :: ICM>Load Data. 
% Then load sample_data.mat, and ICM will read in the image data. 
% Programatically:
icm.load_data('sample_data.mat');

% Alternatively data can be entered from a matlab variable:
load('sample_data.mat'); % produces data
icm.set_data(data);

%% Settings
% In order to change the basic settings, pop-up menus can be accessed in
% the GUI. To change the preprocessing settings, use the ICM menu: 
% :: ICM>Edit Settings>PreProcessing
% The settings can be accessed programatically in the settings struct, lets
% set the preprocessing settings programatically:

icm.data(1).settings.preprocessing.smooth_window = [1 1 1]; % Smooth over MxNxT pixels
icm.data(1).settings.preprocessing.down_sample = [1 1 1];

% The image data was previously down sampled so it would be a small file.
% Above we set the preprocessing settings such that we use the same data.
% If your analysis takes too much time or memory, try smoothing and
% downsampling more.

% There are also settings for PCA and ICA you can see them here
disp('PCA Settings:');
disp(icm.data(1).settings.pca);
disp('ICA Settings:');
disp(icm.data(1).settings.ica);

%% Motion Correction
% A simple image-registration based motion correction algorithm is part of
% the ICM. The motion correction function can be changed to an outside
% function and you can get the GUI to call it by changing the settings:

icm.data(1).settings.preprocessing.motion_correction_func = @align_im_stack;
% This has already been done for the sample data provided, so no need.
%icm.run_motion_correction(); 

% Note: you'll have to make sure the function arguments are the same as
% [align_im_stack] in order for the GUI to call the function correctly.

%% Pre-Processing
% The pre-processing stage is used to down sample the data, run filters,
% and take other pre-processing steps.

icm.run_preprocessing();

%% PCA
% The next stage is to break the image pixels down into principal
% components. This can be run by going to the PCA tab and clicking "Run PCA".

% This algorithm looks for components that explain the maximum
% amount of variance of the image data. This will typically show you the
% most significant aspects of the data in the first few PCs. 

icm.run_pca();

% Once PCA is complete, the results can be viewed by opening the PCA tab
% and examining the frames in the ROI Editor. Each frame corresponds to the
% weights of the PC at each pixel. The component plot shows the PC over
% time.

% The results of the PCA analysis are stored in the pca struct
disp('PCA Results:');
disp(icm.data(1).pca);

%% ICA
% The next stage is to look for the individual cells using the ICA
% algorithm. This can be run by going to the ICA tab and clicking "Run ICA".

% ICA searches for components that are maximally independent based on the
% statistics of the PCA decomposition. This will pull out signals coming
% from a single cell. 

% An important setting for ica is [which_pcs] this tells ICA which
% principal components to look at, and determines the number of ICs the
% algorithm returns. Here we will use the first 50 PCs, to look at the
% data. 
icm.data(1).settings.ica.which_pcs = 1:50;

icm.run_ica();

% Note that ICA looks for a fixed number of components based on the number
% of PCs it analyzes based on [settings.ica.which_pcs]. Asking for more or
% less components can give different results -- too few components will
% lead to different cells being grouped as 1, too many components will
% occasionally cause cells to be split into multiple components.

% The ICs can be viewed in a similar fashion as the PCs inside the ROI Editor. 

% The results of ICA are stored in the ica struct
disp('ICA Results:');
disp(icm.data(1).ica);

%% ROI
% Basic ROI analysis can be done inside ICM. Oval shaped ROIs can be drawn
% using the ROI Editor. 
% Create ROI: Click on an empty spot in the ROI editor and drag to draw
%             a new oval, release to create the ROI.
% Move ROI: Click and drag inside a created ROI to move it to a new
%           position.
% Resize ROI: A selected ROI will have 3 black boxes. The outer boxes can
%             be clicked and dragged to resize the ROI.
% Rotate ROI: The inner black box can be clicked and dragged to rotate the
%             ROI.
% Delete ROI: select an ROI and press <ctrl+delete> to delete it. 
%
% The data of an ROI is shown in the Data plot. This is the average of all
% pixels inside the ROI for each frame.

%% Segmentation and Automatically Generated ROI
% A simple algorithm to calculate ROIs from the ICA results is also
% provided. The ICs are segmented by setting a threshold and a down_sample
% factor in the segment tab. Then oval-shaped ROIs can be automatically
% generated from the segmentation,

icm.data(1).settings.segment.down_size = 2;
icm.data(1).settings.segment.thresh = 3.2;

icm.run_segmentation();

