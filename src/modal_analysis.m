function [freq_Hz, modes, lambdas] = modal_analysis(K, M, n_modes, fixed_dofs)
% MODAL_ANALYSIS  Solve the generalized eigenvalue problem K phi = lambda M phi.
%
%   [freq_Hz, modes, lambdas] = modal_analysis(K, M, n_modes, fixed_dofs)
%
%   K, M       : sparse global stiffness and mass matrices, both 6N x 6N
%   n_modes    : number of lowest-frequency modes to return
%   fixed_dofs : (optional) vector of constrained DOF indices to remove
%                before solving. Pass [] or omit for unconstrained modes,
%                in which case the lowest 6 modes are the rigid body modes
%                (3 translations, 3 rotations) at zero frequency.
%
%   Returns:
%     freq_Hz : (n_modes x 1) natural frequencies in Hz, sorted ascending
%     modes   : (6N x n_modes) mode shapes with zeros at fixed DOFs
%     lambdas : (n_modes x 1) raw eigenvalues, lambda = (2*pi*f)^2
%
%   Implementation notes: for the small problem sizes in this project
%   (< 200 DOFs) a direct generalized eig on the full reduced matrices is
%   both faster and more reliable than eigs(). The reduced K and M are
%   symmetric so we symmetrize before solving to suppress numerical
%   asymmetry below 1e-12. Small numerical negatives from the rigid body
%   modes are clamped to zero before taking sqrt.
%
%   David Angelou, U-M ME, 2026.

    if nargin < 4 || isempty(fixed_dofs)
        fixed_dofs = [];
    end

    n_dof = size(K, 1);
    all_dofs = 1:n_dof;
    free_dofs = setdiff(all_dofs, fixed_dofs);

    Kf = full(K(free_dofs, free_dofs));
    Mf = full(M(free_dofs, free_dofs));

    % Symmetrize to suppress asymmetry below 1e-12.
    Kf = 0.5 * (Kf + Kf');
    Mf = 0.5 * (Mf + Mf');

    [V_eig, D_eig] = eig(Kf, Mf);
    lambdas_all = real(diag(D_eig));

    % Clamp numerical negatives (rigid body modes return tiny negative
    % values from finite-precision arithmetic).
    lambdas_all(lambdas_all < 0) = 0;

    [lambdas_sorted, sort_idx] = sort(lambdas_all, 'ascend');

    n_return = min(n_modes, length(lambdas_sorted));
    lambdas = lambdas_sorted(1:n_return);
    freq_Hz = sqrt(lambdas) / (2*pi);

    % Expand reduced mode shapes back to the full DOF space, leaving zeros
    % at constrained DOFs.
    modes = zeros(n_dof, n_return);
    modes(free_dofs, :) = V_eig(:, sort_idx(1:n_return));
end
