function [M_global, T] = build_mass_matrix(n1, n2, rho, A, Iy, Iz)
% BUILD_MASS_MATRIX  12x12 consistent mass matrix for a 3D Euler-Bernoulli beam.
%
%   [M_global, T] = build_mass_matrix(n1, n2, rho, A, Iy, Iz)
%
%   n1, n2 : 1x3 coordinate vectors of the two end nodes [x y z]
%   rho    : Material density (kg/m^3)
%   A      : Cross-section area (m^2)
%   Iy, Iz : Second moments of area about local y and z axes (m^4)
%
%   Returns the 12x12 mass matrix in global coordinates and the 12x12
%   transformation matrix T (block-diagonal repeats of the 3x3 rotation).
%   DOF ordering at each node is [ux uy uz rx ry rz].
%
%   Formulation: consistent (not lumped) mass, derived from cubic Hermite
%   shape functions for bending and linear shape functions for axial and
%   torsion. Rotary inertia of the cross section is captured through the
%   coupling between transverse translation and end rotation in the bending
%   block. Polar moment of inertia I_p = Iy + Iz is used for the torsional
%   rotational mass.
%
%   Reference: Logan, A First Course in the Finite Element Method, Ch. 9.
%
%   David Angelou, U-M ME, 2026.

    L_vec = n2 - n1;
    L = norm(L_vec);
    if L < eps
        error('Zero-length beam element between coincident nodes.');
    end

    M_local = zeros(12, 12);

    % Axial DOFs 1 and 7
    M_local([1 7], [1 7]) = (rho*A*L/6) * [2 1; 1 2];

    % Torsional DOFs 4 and 10. Polar moment of inertia of the section.
    Ip = Iy + Iz;
    M_local([4 10], [4 10]) = (rho*Ip*L/6) * [2 1; 1 2];

    % Cubic Hermite consistent mass template for one bending plane.
    mb = (rho*A*L/420) * [ 156,    22*L,    54,   -13*L;
                            22*L,  4*L^2,   13*L, -3*L^2;
                            54,    13*L,    156,  -22*L;
                           -13*L, -3*L^2,  -22*L,  4*L^2];

    % Bending in x-z plane (Iy plane). DOFs 3 (uz), 5 (ry), 9 (uz), 11 (ry).
    % Sign convention matches beam_element_3d: positive ry at node 1 lifts
    % the node-2 end, hence the same sgn diag([1 -1 1 -1]) wrap as in K.
    sgn = diag([1 -1 1 -1]);
    M_local([3 5 9 11], [3 5 9 11]) = sgn * mb * sgn;

    % Bending in x-y plane (Iz plane). DOFs 2 (uy), 6 (rz), 8 (uy), 12 (rz).
    M_local([2 6 8 12], [2 6 8 12]) = mb;

    % Direction cosines for the local-to-global transformation. Identical
    % construction to beam_element_3d so M and K share the same T.
    ex = L_vec / L;
    if abs(ex(3)) < 0.999
        ref = [0 0 1];
    else
        ref = [0 1 0];
    end
    ey = cross(ref, ex);
    ey = ey / norm(ey);
    ez = cross(ex, ey);
    R = [ex; ey; ez];

    T = zeros(12, 12);
    for blk = 0:3
        T(blk*3 + (1:3), blk*3 + (1:3)) = R;
    end

    M_global = T' * M_local * T;
end
