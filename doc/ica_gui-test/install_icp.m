function install_icp()
%% Run this to install ICP

% @todo: check the version and for the right functions.
currentdir = pwd();

thisdir = fileparts(mfilename('fullpath'));

addpath(thisdir);
addpath(fullfile(thisdir, 'ecc'));
addpath(fullfile(thisdir, 'FastICA_25'));
addpath(fullfile(thisdir, 'Resources'));
cd(fullfile(thisdir, 'GUILayout-v1p13'));
install();
cd(currentdir);

if savepath()
    % Then save failed
    fprintf('- Failed to save path, you will need to re-install when MATLAB is restarted\n');
else
    fprintf('+ Path saved\n');
end