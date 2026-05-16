function results = post_process(nodes, elements, U, section, material)
% POST_PROCESS  Compute element forces, bending stress, axial stress,
% combined Von Mises stress, and reserve factor against allowable.
%
%   results = post_process(nodes, elements, U, section, material)
%
%   Returns a struct array, one entry per element, with fields:
%       axial_force_N
%       shear_y_N, shear_z_N
%       torsion_Nm
%       moment_y_Nm, moment_z_Nm
%       sigma_axial_Pa
%       sigma_bend_max_Pa
%       sigma_total_Pa
%       tau_torsion_Pa
%       sigma_vm_Pa
%       reserve_factor
%
%   David Angelou, U-M ME, 2026.

    M = size(elements, 1);
    c = section.OD / 2;       % outer fiber radius for bending stress

    % Use sigma_all when defined (CFRP design allowable with knockdown).
    % Fall back to sigma_y for metals where only yield is given.
    if isfield(material, 'sigma_all')
        sigma_allow = material.sigma_all;
        if isfield(material, 'sigma_y')
            sigma_allow = min(sigma_allow, material.sigma_y);
        end
    elseif isfield(material, 'sigma_y')
        sigma_allow = material.sigma_y;
    else
        error('post_process:noAllowable', ...
              'Material has neither sigma_all nor sigma_y.');
    end

    results(M, 1) = struct();

    for e = 1:M
        n1 = elements(e, 1);
        n2 = elements(e, 2);

        % Element displacement vector in global coords
        dof = [6*(n1-1) + (1:6), 6*(n2-1) + (1:6)];
        ue_global = U(dof);

        % Rebuild element stiffness and transformation
        [Ke_global, T] = beam_element_3d(nodes(n1,:), nodes(n2,:), ...
                                          material.E, material.G, ...
                                          section.A, section.Iy, section.Iz, section.J);
        ue_local = T * ue_global;

        % Element internal forces in local coordinates
        % We rebuild K_local for force recovery
        L = norm(nodes(n2,:) - nodes(n1,:));
        E = material.E; G = material.G;
        A = section.A; Iy = section.Iy; Iz = section.Iz; J = section.J;

        K_local = zeros(12, 12);
        K_local([1 7], [1 7]) = (E*A/L) * [1 -1; -1 1];
        K_local([4 10], [4 10]) = (G*J/L) * [1 -1; -1 1];
        kb_y = (E*Iy/L^3) * [ 12  6*L -12  6*L; 6*L 4*L^2 -6*L 2*L^2; ...
                              -12 -6*L 12 -6*L; 6*L 2*L^2 -6*L 4*L^2];
        sgn = diag([1 -1 1 -1]);
        K_local([3 5 9 11], [3 5 9 11]) = sgn * kb_y * sgn;
        kb_z = (E*Iz/L^3) * [ 12  6*L -12  6*L; 6*L 4*L^2 -6*L 2*L^2; ...
                              -12 -6*L 12 -6*L; 6*L 2*L^2 -6*L 4*L^2];
        K_local([2 6 8 12], [2 6 8 12]) = kb_z;

        f_local = K_local * ue_local;

        % Internal force convention, at node 2 end
        N_axial   = f_local(7);
        Vy        = f_local(8);
        Vz        = f_local(9);
        T_torsion = f_local(10);
        My        = f_local(11);
        Mz        = f_local(12);

        % Stresses
        sigma_axial = N_axial / A;
        sigma_bend  = sqrt((My * c / Iy)^2 + (Mz * c / Iz)^2);
        sigma_total = abs(sigma_axial) + sigma_bend;
        tau_torsion = abs(T_torsion) * c / J;

        % Von Mises with combined normal + shear
        sigma_vm = sqrt(sigma_total^2 + 3 * tau_torsion^2);

        RF = sigma_allow / max(sigma_vm, 1);

        results(e).element_id      = e;
        results(e).axial_force_N   = N_axial;
        results(e).shear_y_N       = Vy;
        results(e).shear_z_N       = Vz;
        results(e).torsion_Nm      = T_torsion;
        results(e).moment_y_Nm     = My;
        results(e).moment_z_Nm     = Mz;
        results(e).sigma_axial_Pa  = sigma_axial;
        results(e).sigma_bend_max_Pa = sigma_bend;
        results(e).sigma_total_Pa  = sigma_total;
        results(e).tau_torsion_Pa  = tau_torsion;
        results(e).sigma_vm_Pa     = sigma_vm;
        results(e).reserve_factor  = RF;
    end

end
