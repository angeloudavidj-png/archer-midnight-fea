function [K_bc, F_bc, free_dofs, fixed_dofs] = apply_boundary_conditions(K, F, fixed_node_dofs)
% APPLY_BOUNDARY_CONDITIONS  Reduce the linear system by direct elimination.
%
%   [K_bc, F_bc, free_dofs, fixed_dofs] = apply_boundary_conditions(K, F, fixed_node_dofs)
%
%   K, F            : full global stiffness and load
%   fixed_node_dofs : cell array, each row {node_index, [dof_list]} where
%                     dof_list is a subset of 1..6 to constrain to zero.
%                     Example: { 5, [1 2 3] ; 7, 1:6 }
%
%   Returns reduced K_bc, F_bc, and the lists of free and fixed global DOFs.
%   Recover full displacement vector after solving with:
%       U = zeros(size(F));
%       U(free_dofs) = K_bc \ F_bc;
%
%   David Angelou, U-M ME, 2026.

    ndof = size(K, 1);
    all_dofs = (1:ndof)';

    fixed_dofs = [];
    for r = 1:size(fixed_node_dofs, 1)
        node_idx = fixed_node_dofs{r, 1};
        local_dofs = fixed_node_dofs{r, 2};
        global_dofs = 6 * (node_idx - 1) + local_dofs(:);
        fixed_dofs = [fixed_dofs; global_dofs];
    end
    fixed_dofs = unique(fixed_dofs);

    free_dofs = setdiff(all_dofs, fixed_dofs);

    K_bc = K(free_dofs, free_dofs);
    F_bc = F(free_dofs);

end
