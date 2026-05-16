function visualize_deformed(nodes, elements, U, scale, fig_title, save_path)
% VISUALIZE_DEFORMED  3D plot of undeformed and deformed structure.
%
%   visualize_deformed(nodes, elements, U, scale, fig_title, save_path)
%
%   scale     : displacement amplification factor for visual clarity
%   fig_title : title string for the plot
%   save_path : optional path to save the figure as PNG
%
%   David Angelou, U-M ME, 2026.

    if nargin < 4 || isempty(scale)
        scale = 100;
    end
    if nargin < 5
        fig_title = 'Deformed shape';
    end
    if nargin < 6
        save_path = '';
    end

    N = size(nodes, 1);
    disp_xyz = zeros(N, 3);
    for i = 1:N
        disp_xyz(i, :) = U(6*(i-1) + (1:3))';
    end
    deformed = nodes + scale * disp_xyz;

    fig = figure('Color', 'w', 'Position', [100 100 1100 700]);
    hold on;
    % Undeformed in light gray
    for e = 1:size(elements, 1)
        n1 = elements(e, 1); n2 = elements(e, 2);
        plot3([nodes(n1,1) nodes(n2,1)], ...
              [nodes(n1,2) nodes(n2,2)], ...
              [nodes(n1,3) nodes(n2,3)], ...
              'Color', [0.7 0.7 0.7], 'LineWidth', 1.0);
    end
    % Deformed in blue
    for e = 1:size(elements, 1)
        n1 = elements(e, 1); n2 = elements(e, 2);
        plot3([deformed(n1,1) deformed(n2,1)], ...
              [deformed(n1,2) deformed(n2,2)], ...
              [deformed(n1,3) deformed(n2,3)], ...
              'Color', [0.12 0.31 0.47], 'LineWidth', 2.0);
    end
    % Node markers
    scatter3(deformed(:,1), deformed(:,2), deformed(:,3), 25, ...
             [1.00 0.74 0.00], 'filled');

    grid on; axis equal;
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title(sprintf('%s, displacement scale = %dx', fig_title, scale), ...
          'Interpreter', 'none');
    view(35, 22);
    set(gca, 'FontName', 'Helvetica', 'FontSize', 11);

    if ~isempty(save_path)
        save_figure_portable(fig, save_path);
    end

end
