function layup = composite_layup(comp, orientations_deg)
% COMPOSITE_LAYUP  Classical lamination theory for a flat symmetric laminate.
%
%   layup = composite_layup(comp, orientations_deg)
%
%   Inputs:
%     comp             : composite material struct from material_composite()
%     orientations_deg : (1 x n_plies) ply orientations in degrees,
%                        ordered from -h/2 to +h/2 through the thickness.
%                        Default: quasi-isotropic [0/45/-45/90]_s.
%
%   Returns a struct with:
%     orientations_deg : copy of input
%     t_ply            : per-ply thickness (m)
%     h_total          : total laminate thickness (m)
%     z                : ply interface z-coordinates, length n_plies+1
%     A, B, D          : 3x3 laminate stiffness blocks (N/m, N, N m)
%     Q_material       : 3x3 lamina stiffness in material axes (Pa)
%     Q_bar_per_ply    : cell array of 3x3 Q_bar for each ply (laminate axes)
%     E_eff_x, E_eff_y, G_eff_xy, nu_eff_xy : effective in-plane engineering
%                        constants of the laminate (only valid when B = 0)
%
%   References: Jones, "Mechanics of Composite Materials" (2nd ed.) Ch. 4-7.
%
%   David Angelou, U-M ME, 2026.

    if nargin < 2 || isempty(orientations_deg)
        % Quasi-isotropic symmetric default: [0/45/-45/90]_s
        orientations_deg = [0, 45, -45, 90, 90, -45, 45, 0];
    end

    n_plies = length(orientations_deg);
    t_ply   = comp.t_ply;
    h_total = n_plies * t_ply;

    % Q in material axes (plane stress)
    nu21 = comp.nu12 * comp.E2 / comp.E1;
    denom = 1 - comp.nu12 * nu21;
    Q11 = comp.E1 / denom;
    Q22 = comp.E2 / denom;
    Q12 = comp.nu12 * comp.E2 / denom;
    Q66 = comp.G12;
    Q = [Q11, Q12, 0;
         Q12, Q22, 0;
         0,   0,   Q66];

    % Ply interface z-coordinates, centered at the laminate midplane.
    z = -h_total/2 + (0:n_plies) * t_ply;

    A = zeros(3,3);
    B = zeros(3,3);
    D = zeros(3,3);
    Q_bar_per_ply = cell(n_plies, 1);

    for k = 1:n_plies
        theta = orientations_deg(k) * pi/180;
        c = cos(theta);
        s = sin(theta);

        % Stress transformation T such that sigma_material = T sigma_laminate.
        T = [ c^2,    s^2,     2*s*c;
              s^2,    c^2,    -2*s*c;
             -s*c,    s*c,     c^2 - s^2];

        % Reuter matrix to handle engineering shear strain.
        R = [1 0 0; 0 1 0; 0 0 2];

        % Q_bar (lamina stiffness in laminate axes) = T^-1 * Q * R * T * R^-1
        Q_bar = T \ (Q * R * T / R);
        Q_bar_per_ply{k} = Q_bar;

        z_k   = z(k);
        z_kp1 = z(k+1);

        A = A +       Q_bar * (z_kp1   - z_k);
        B = B + 0.5 * Q_bar * (z_kp1^2 - z_k^2);
        D = D + (1/3)*Q_bar * (z_kp1^3 - z_k^3);
    end

    % Effective laminate engineering constants assuming B = 0 (symmetric).
    layup.B_violation = max(abs(B(:))) / max(abs(A(:)));
    if layup.B_violation < 1e-8
        a = inv(A);
        layup.E_eff_x   = 1 / (a(1,1) * h_total);
        layup.E_eff_y   = 1 / (a(2,2) * h_total);
        layup.G_eff_xy  = 1 / (a(3,3) * h_total);
        layup.nu_eff_xy = -a(1,2) / a(1,1);
    else
        layup.E_eff_x   = NaN;
        layup.E_eff_y   = NaN;
        layup.G_eff_xy  = NaN;
        layup.nu_eff_xy = NaN;
    end

    layup.orientations_deg = orientations_deg;
    layup.t_ply            = t_ply;
    layup.h_total          = h_total;
    layup.z                = z;
    layup.A                = A;
    layup.B                = B;
    layup.D                = D;
    layup.Q_material       = Q;
    layup.Q_bar_per_ply    = Q_bar_per_ply;
end
