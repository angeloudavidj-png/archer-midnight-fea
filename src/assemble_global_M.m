function M = assemble_global_M(nodes, elements, section, material)
% ASSEMBLE_GLOBAL_M  Build the sparse global consistent mass matrix.
%
%   M = assemble_global_M(nodes, elements, section, material)
%
%   nodes    : N x 3 array of nodal coordinates
%   elements : M x 2 array of element connectivity (node indices)
%   section  : struct with fields A, Iy, Iz (hollow tube section props)
%   material : struct with field rho (kg/m^3)
%
%   Returns the (6N x 6N) sparse global mass matrix, parallel in structure
%   to assemble_global_K so the two share sparsity patterns and the same
%   DOF ordering: node i occupies rows/cols 6*(i-1)+1 : 6*i.
%
%   David Angelou, U-M ME, 2026.

    N = size(nodes, 1);
    n_elem = size(elements, 1);
    ndof = 6 * N;

    nnz_est = 144 * n_elem;
    I = zeros(nnz_est, 1);
    J = zeros(nnz_est, 1);
    V = zeros(nnz_est, 1);
    idx = 0;

    for e = 1:n_elem
        n1 = elements(e, 1);
        n2 = elements(e, 2);

        Me = build_mass_matrix(nodes(n1,:), nodes(n2,:), ...
                                material.rho, ...
                                section.A, section.Iy, section.Iz);

        dof = [6*(n1-1) + (1:6), 6*(n2-1) + (1:6)];

        for a = 1:12
            for b = 1:12
                idx = idx + 1;
                I(idx) = dof(a);
                J(idx) = dof(b);
                V(idx) = Me(a, b);
            end
        end
    end

    M = sparse(I(1:idx), J(1:idx), V(1:idx), ndof, ndof);
end
