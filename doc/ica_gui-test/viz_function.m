function colors = viz_function(icp)
% colors = viz_function(icp): takes an icp (or just the components?) and
% computes a volor for each component for visualization.

% Ok this is just a test function to get to the interface.

% Lets return some colors based on the first 3 pcs. The A matrix contains
% the PC weight for each IC.
%colors = norm_range(abs(icp.ica.A(:, [3, 5, 7])));

which_pcs = [7];
%c = icp.ica.A(3, :) + icp.ica.A(5,:);
c = icp.data(icp.gui.current_trial).ica.A(3,:);
c(c<0) = 0;
colors = norm_range(c)';
%colors = [norm_range(max(icp.ica.A(5,:), 0)); norm_range(max(-icp.ica.A(5,:), 0)); norm_range(max(icp.ica.A(7,:),0))]';
%colors(:, 4) = sqrt(sum(icp.ica.A(which_pcs,:).^2));