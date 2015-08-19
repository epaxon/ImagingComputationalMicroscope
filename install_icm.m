function install_icm()
%% Run this to install ICP

% @todo: check the version and for the right functions.
currentdir = pwd();

thisdir = fileparts(mfilename('fullpath'));

addpath(thisdir);
addpath(fullfile(thisdir, 'ecc'));
addpath(fullfile(thisdir, 'FastICA_25'));
addpath(fullfile(thisdir, 'Resources'));
addpath(fullfile(thisdir, 'hdf5prop'));
addpath(genpath(fullfile(thisdir, 'chronux')));

if verLessThan('matlab', '8.4')
    cd(fullfile(thisdir, 'GUILayout-v1p13'));
    install();
    cd(currentdir);
else
    disp('You must install the GUILayout Toolbox');
end

if savepath()
    % Then save failed
    fprintf('- Failed to save path, you will need to re-install when MATLAB is restarted\n');
else
    fprintf('+ Path saved\n');
end