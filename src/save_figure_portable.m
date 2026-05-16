function save_figure_portable(fig, save_path)
% SAVE_FIGURE_PORTABLE  Save a figure to PNG, works in both MATLAB and Octave.
%
%   In MATLAB R2020a+ this uses exportgraphics. In Octave or older MATLAB
%   it falls back to print.
%
%   David Angelou, U-M ME, 2026.

    if exist('exportgraphics', 'builtin') || exist('exportgraphics', 'file')
        exportgraphics(fig, save_path, 'Resolution', 200);
    else
        % Octave or older MATLAB
        print(fig, save_path, '-dpng', '-r200');
    end

end
