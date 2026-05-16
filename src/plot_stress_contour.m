function plot_stress_contour(nodes, elements, results, fig_title, save_path)
% PLOT_STRESS_CONTOUR  Color each beam element by its Von Mises stress.
%
%   plot_stress_contour(nodes, elements, results, fig_title, save_path)
%
%   David Angelou, U-M ME, 2026.

    if nargin < 4, fig_title = 'Von Mises stress per element'; end
    if nargin < 5, save_path = ''; end

    M = size(elements, 1);
    sigma_vm = arrayfun(@(r) r.sigma_vm_Pa, results) / 1e6;  % MPa

    sigma_min = min(sigma_vm);
    sigma_max = max(sigma_vm);

    cmap = jet(256);

    fig = figure('Color', 'w', 'Position', [100 100 1100 700]);
    hold on;
    for e = 1:M
        n1 = elements(e, 1); n2 = elements(e, 2);
        if sigma_max > sigma_min
            t = (sigma_vm(e) - sigma_min) / (sigma_max - sigma_min);
        else
            t = 0.5;
        end
        ci = max(1, min(256, round(1 + t * 255)));
        plot3([nodes(n1,1) nodes(n2,1)], ...
              [nodes(n1,2) nodes(n2,2)], ...
              [nodes(n1,3) nodes(n2,3)], ...
              'Color', cmap(ci, :), 'LineWidth', 3.0);
    end
    scatter3(nodes(:,1), nodes(:,2), nodes(:,3), 18, 'k', 'filled');

    grid on; axis equal;
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    colormap(cmap);
    cb = colorbar;
    caxis([sigma_min sigma_max]);
    cb.Label.String = 'Von Mises stress (MPa)';
    title(fig_title, 'Interpreter', 'none');
    view(35, 22);
    set(gca, 'FontName', 'Helvetica', 'FontSize', 11);

    if ~isempty(save_path)
        save_figure_portable(fig, save_path);
    end

end
