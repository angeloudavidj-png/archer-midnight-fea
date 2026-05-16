function [K_global, T] = beam_element_3d(n1, n2, E, G, A, Iy, Iz, J)
% BEAM_ELEMENT_3D  12x12 stiffness matrix for a 3D Euler-Bernoulli beam.
%
%   [K_global, T] = beam_element_3d(n1, n2, E, G, A, Iy, Iz, J)
%
%   n1, n2 : 1x3 coordinate vectors of the two end nodes [x y z]
%   E      : Young's modulus (Pa)
%   G      : Shear modulus (Pa)
%   A      : Cross-section area (m^2)
%   Iy, Iz : Second moments of area about local y and z axes (m^4)
%   J      : Torsional constant (m^4)
%
%   Returns the 12x12 stiffness matrix in global coordinates and the
%   12x12 transformation matrix T such that K_global = T' * K_local * T.
%
%   DOF ordering at each node is [ux uy uz rx ry rz], so a 12-vector
%   per element. Local x is along the beam axis from n1 to n2.
%
%   Reference: Logan, A First Course in the Finite Element Method, Ch. 5.
%
%   David Angelou, U-M ME, 2026.

    % Geometry
    L_vec = n2 - n1;
    L = norm(L_vec);
    if L < eps
        error('Zero-length beam element between coincident nodes.');
    end

    % Local stiffness matrix in beam coordinates
    EA_L  = E * A / L;
    GJ_L  = G * J / L;
    EIy   = E * Iy;
    EIz   = E * Iz;

    K_local = zeros(12, 12);

    % Axial DOFs 1 and 7
    K_local([1 7], [1 7]) = EA_L * [1 -1; -1 1];

    % Torsion DOFs 4 and 10
    K_local([4 10], [4 10]) = GJ_L * [1 -1; -1 1];

    % Bending in x-z plane, uses Iy, DOFs 3 (uz), 5 (ry), 9 (uz), 11 (ry)
    kb_y = (EIy / L^3) * [ 12,    6*L,   -12,    6*L;
                            6*L,  4*L^2, -6*L,  2*L^2;
                           -12,   -6*L,   12,   -6*L;
                            6*L,  2*L^2, -6*L,  4*L^2];
    % Sign convention: positive ry rotates uz, careful with sign on coupling
    idx_y = [3 5 9 11];
    % Apply sign correction so that positive ry at n1 lifts the n2 end
    sign_fix_y = diag([1 -1 1 -1]);
    K_local(idx_y, idx_y) = sign_fix_y * kb_y * sign_fix_y;

    % Bending in x-y plane, uses Iz, DOFs 2 (uy), 6 (rz), 8 (uy), 12 (rz)
    kb_z = (EIz / L^3) * [ 12,    6*L,   -12,    6*L;
                            6*L,  4*L^2, -6*L,  2*L^2;
                           -12,   -6*L,   12,   -6*L;
                            6*L,  2*L^2, -6*L,  4*L^2];
    idx_z = [2 6 8 12];
    K_local(idx_z, idx_z) = kb_z;

    % Direction cosines for transformation
    ex = L_vec / L;

    % Choose a reference vector not parallel to ex for stable local y
    if abs(ex(3)) < 0.999
        ref = [0 0 1];
    else
        ref = [0 1 0];
    end
    ey = cross(ref, ex);
    ey = ey / norm(ey);
    ez = cross(ex, ey);

    % 3x3 rotation, rows are local axes expressed in global
    R = [ex; ey; ez];

    % 12x12 transformation: block-diagonal R repeated 4 times
    T = zeros(12, 12);
    for blk = 0:3
        T(blk*3 + (1:3), blk*3 + (1:3)) = R;
    end

    K_global = T' * K_local * T;

end
