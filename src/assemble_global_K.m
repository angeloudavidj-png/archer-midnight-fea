function K = assemble_global_K(nodes, elements, section, material)
% ASSEMBLE_GLOBAL_K  Build the sparse global stiffness matrix.
%
%   K = assemble_global_K(nodes, elements, section, material)
%
%   nodes    : N x 3 array of nodal coordinates
%   elements : M x 2 array of element connectivity (node indices)
%   section  : struct with fields A, Iy, Iz, J (hollow tube section props)
%   material : struct with fields E, G (Pa)
%
%   Returns the (6N x 6N) sparse global stiffness matrix.
%   DOF ordering: node i occupies rows/cols 6*(i-1)+1 : 6*i.
%
%   David Angelou, U-M ME, 2026.

    N = size(nodes, 1);
    M = size(elements, 1);
    ndof = 6 * N;

    % Pre-allocate triplet arrays for sparse assembly
    nnz_est = 144 * M;
    I = zeros(nnz_est, 1);
    J = zeros(nnz_est, 1);
    V = zeros(nnz_est, 1);
    idx = 0;

    for e = 1:M
        n1 = elements(e, 1);
        n2 = elements(e, 2);

        Ke = beam_element_3d(nodes(n1,:), nodes(n2,:), ...
                              material.E, material.G, ...
                              section.A, section.Iy, section.Iz, section.J);

        % Global DOF indices for this element
        dof = [6*(n1-1) + (1:6), 6*(n2-1) + (1:6)];

        for a = 1:12
            for b = 1:12
                idx = idx + 1;
                I(idx) = dof(a);
                J(idx) = dof(b);
                V(idx) = Ke(a, b);
            end
        end
    end

    K = sparse(I(1:idx), J(1:idx), V(1:idx), ndof, ndof);

end
