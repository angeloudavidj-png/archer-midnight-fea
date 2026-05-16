function [C, info] = build_damping_matrix(K, M, target_zeta, mode_indices, fixed_dofs)
% BUILD_DAMPING_MATRIX  Rayleigh damping tuned to a target modal damping
% ratio on two specified elastic modes.
%
%   [C, info] = build_damping_matrix(K, M, target_zeta, mode_indices, fixed_dofs)
%
%   Rayleigh: C = alpha M + beta K. With 2 zeta_i omega_i = alpha + beta omega_i^2
%   for two anchor modes (i = mode_indices(1), mode_indices(2)) requiring the
%   same target zeta, the closed-form solution is:
%
%       alpha = 2 zeta omega_1 omega_2 / (omega_1 + omega_2)
%       beta  = 2 zeta / (omega_1 + omega_2)
%
%   Modes in between the two anchors have lower damping; modes outside the
%   range have higher damping. Anchoring on the first two elastic modes is a
%   common convention for transient analysis where the lowest modes dominate
%   the response.
%
%   Inputs:
%     K, M         : sparse global stiffness and mass matrices
%     target_zeta  : desired damping ratio (e.g., 0.03 for 3 percent)
%     mode_indices : (1 x 2) elastic mode indices to anchor (1-based, after
%                    rigid body modes are removed if fixed_dofs is empty,
%                    or 1-based on the constrained pencil if fixed_dofs is
%                    given). Use [1 2] for the first two elastic modes.
%     fixed_dofs   : (optional) DOFs to constrain before computing modes.
%                    Pass [] or omit to use the unconstrained pencil; this
%                    will include rigid body modes that are skipped here.
%
%   Returns:
%     C    : sparse damping matrix, same dimension as K and M.
%     info : struct with fields alpha, beta, omega_1, omega_2, freq_anchored_Hz.
%
%   David Angelou, U-M ME, 2026.

    if nargin < 5
        fixed_dofs = [];
    end

    % Pull enough modes that we can skip rigid body modes if any.
    n_modes_solve = max(mode_indices) + 10;
    [freq_Hz, ~, ~] = modal_analysis(K, M, n_modes_solve, fixed_dofs);

    % Drop near-zero rigid body modes. Threshold matches test_modal_rigid_body.
    elastic_freq = freq_Hz(freq_Hz > 0.01);

    if length(elastic_freq) < max(mode_indices)
        error('build_damping_matrix:notEnoughElasticModes', ...
              'Asked for elastic mode %d but only %d available.', ...
              max(mode_indices), length(elastic_freq));
    end

    w_1 = 2*pi * elastic_freq(mode_indices(1));
    w_2 = 2*pi * elastic_freq(mode_indices(2));

    if abs(w_2 - w_1) < 0.1
        warning('build_damping_matrix:closeAnchors', ...
                'Anchor modes are within 0.1 rad/s (%.4f Hz, %.4f Hz). Tuning may be poorly conditioned.', ...
                w_1/(2*pi), w_2/(2*pi));
    end

    alpha_R = 2*target_zeta * w_1 * w_2 / (w_1 + w_2);
    beta_R  = 2*target_zeta / (w_1 + w_2);

    C = alpha_R * M + beta_R * K;

    info.alpha            = alpha_R;
    info.beta             = beta_R;
    info.omega_1          = w_1;
    info.omega_2          = w_2;
    info.freq_anchored_Hz = [w_1, w_2] / (2*pi);

    fprintf('Rayleigh damping: anchored at modes %d (%.2f Hz) and %d (%.2f Hz)\n', ...
            mode_indices(1), w_1/(2*pi), mode_indices(2), w_2/(2*pi));
    fprintf('  target zeta = %.3f, alpha = %.4e, beta = %.4e\n', ...
            target_zeta, alpha_R, beta_R);
end
