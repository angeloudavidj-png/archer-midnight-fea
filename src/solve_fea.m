function U = solve_fea(K, F, fixed_node_dofs)
% SOLVE_FEA  Solve KU = F with prescribed zero displacement boundary conditions.
%
%   U = solve_fea(K, F, fixed_node_dofs)
%
%   Returns the full global displacement vector (6N x 1).
%
%   David Angelou, U-M ME, 2026.

    [K_bc, F_bc, free_dofs, ~] = apply_boundary_conditions(K, F, fixed_node_dofs);

    % Check conditioning before solving
    if condest(K_bc) > 1e14
        warning('Reduced stiffness matrix is poorly conditioned (cond ~ %.2e).', condest(K_bc));
    end

    U_free = K_bc \ F_bc;

    U = zeros(size(F));
    U(free_dofs) = U_free;

end
