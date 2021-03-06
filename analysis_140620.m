%% quick pca ica stuff for woods hole

fh = figure();
set(fh, 'Color', 'w', 'Position', [50 50 300 500]);
ax = axes('Parent', fh, 'YColor', 'w', 'YTick', [], 'OuterPosition', [0.1, 0, 0.9, 1]);
hold on;
offset = 5000;

components = [1, 2, 3, 4, 5, 6, 7, 8, 100, 101, 300, 400];

for i = 1:length(components)
    plot(icm.data(1).pca.pcs(:, components(i)) - offset * i, 'k', 'LineWidth', 2);
    
    text(-50, -offset * i, num2str(components(i)), 'FontSize', 18, 'HorizontalAlignment', 'right'); 
end

xlim([0 500]);

%%

ica_scores = reshape(icm.data(1).ica.im_data, [], 120);

%%
figure;
imagesc(ica_scores);

%%
figure;
imagesc(icm.data(1).ica.A);