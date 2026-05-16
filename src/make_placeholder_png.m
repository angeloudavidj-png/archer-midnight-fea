function make_placeholder_png(filename, title_str, body_str)
% MAKE_PLACEHOLDER_PNG  Write a simple PNG with text indicating the figure
% is pending an external (Ansys) run. Used so docs/index.md can reference
% docs/figures/joint_shell_screenshot.png and strut_top_shell_screenshot.png
% before David has executed the Ansys submodel scripts.
%
%   David Angelou, U-M ME, 2026.

    fig = figure('Visible', 'off', 'Position', [100 100 900 500], 'Color', 'w');
    axis off;
    xlim([0 1]); ylim([0 1]);

    text(0.5, 0.80, 'PENDING ANSYS RUN', ...
         'HorizontalAlignment', 'center', ...
         'FontSize', 30, 'FontWeight', 'bold', 'Color', [0.4 0.4 0.4]);

    text(0.5, 0.62, title_str, ...
         'HorizontalAlignment', 'center', ...
         'FontSize', 18, 'Color', [0.2 0.2 0.2]);

    text(0.5, 0.45, body_str, ...
         'HorizontalAlignment', 'center', ...
         'FontSize', 13, 'Color', [0.25 0.25 0.25]);

    text(0.5, 0.20, 'Re-run the MATLAB pipeline to regenerate this placeholder.', ...
         'HorizontalAlignment', 'center', ...
         'FontSize', 11, 'Color', [0.5 0.5 0.5], 'FontAngle', 'italic');

    saveas(fig, filename);
    close(fig);
end
