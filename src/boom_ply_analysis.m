function results = boom_ply_analysis(sigma_xx_peak, layup, comp)
% BOOM_PLY_ANALYSIS  Apply a single laminate-axis longitudinal stress
% sigma_xx, distribute through a symmetric laminate via CLT, evaluate
% per-ply Tsai-Wu and Hashin indices in material axes.
%
%   results = boom_ply_analysis(sigma_xx_peak, layup, comp)
%
%   Inputs:
%     sigma_xx_peak : Pa, signed peak longitudinal stress at the outer
%                     fiber of the most stressed boom element. Negative
%                     for compression, positive for tension.
%     layup         : output of composite_layup()
%     comp          : output of material_composite()
%
%   Returns a struct with per-ply stress states (material axes), failure
%   indices, and a summary of the critical ply and dominant failure mode.
%
%   Assumes the boom wall sees uniaxial laminate-axis loading: sigma_xx
%   only, sigma_yy = 0, tau_xy = 0. This is the right reduction for an
%   Euler-Bernoulli beam under pure axial + bending. Transverse shear from
%   beam shear or torsion is small for the inboard boom segments that
%   govern LC2 and is neglected here.
%
%   David Angelou, U-M ME, 2026.

    h = layup.h_total;

    % Apply uniaxial laminate force per unit width (h * sigma_xx in x, zero
    % in y and shear).
    N = [sigma_xx_peak * h; 0; 0];

    % Mid-plane strain. B = 0 for the symmetric layups we use, so the
    % membrane response is decoupled from bending.
    if layup.B_violation > 1e-8
        warning('boom_ply_analysis:nonSymmetricLayup', ...
                'Layup B/A ratio = %.2e, decoupled membrane assumption may be invalid.', ...
                layup.B_violation);
    end
    a_compliance = inv(layup.A);
    eps_global   = a_compliance * N;

    n_plies = length(layup.orientations_deg);

    ply(n_plies, 1) = struct('idx', [], 'theta_deg', [], ...
                             'sigma_11', [], 'sigma_22', [], 'tau_12', [], ...
                             'tsai_wu', [], 'hashin_fiber', [], ...
                             'hashin_matrix', [], 'hashin_mode', '');

    for k = 1:n_plies
        theta_deg = layup.orientations_deg(k);
        theta     = theta_deg * pi/180;
        c = cos(theta);
        s = sin(theta);

        % Ply stress in laminate axes (same strain, ply-specific stiffness).
        sigma_global = layup.Q_bar_per_ply{k} * eps_global;

        % Stress transformation laminate -> material axes.
        T = [ c^2,    s^2,     2*s*c;
              s^2,    c^2,    -2*s*c;
             -s*c,    s*c,     c^2 - s^2];
        sigma_material = T * sigma_global;

        F_tw       = tsai_wu(sigma_material, comp);
        [idx_h, m] = hashin(sigma_material, comp);

        ply(k).idx           = k;
        ply(k).theta_deg     = theta_deg;
        ply(k).sigma_11      = sigma_material(1);
        ply(k).sigma_22      = sigma_material(2);
        ply(k).tau_12        = sigma_material(3);
        ply(k).tsai_wu       = F_tw;
        ply(k).hashin_fiber  = idx_h.fiber;
        ply(k).hashin_matrix = idx_h.matrix;
        ply(k).hashin_mode   = m;
    end

    % Critical ply by Tsai-Wu
    tw_all = arrayfun(@(p) p.tsai_wu, ply);
    [tw_max, k_crit] = max(tw_all);

    results.sigma_xx_applied       = sigma_xx_peak;
    results.eps_global             = eps_global;
    results.ply                    = ply;
    results.critical_ply           = k_crit;
    results.critical_orientation   = ply(k_crit).theta_deg;
    results.critical_tsai_wu       = tw_max;
    results.critical_hashin_fiber  = ply(k_crit).hashin_fiber;
    results.critical_hashin_matrix = ply(k_crit).hashin_matrix;
    results.critical_hashin_mode   = ply(k_crit).hashin_mode;
end
