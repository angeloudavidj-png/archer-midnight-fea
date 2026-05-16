function results = drop_test(params, mat, lg_section)
% DROP_TEST  Explicit dynamic landing simulation of the tricycle gear.
%
%   results = drop_test(params, mat, lg_section)
%
%   Simulates the landing event at the FAR 23.473 sink rate of 2.6 m/s
%   using Newmark beta time integration of the linear LG structure with
%   a penalty-spring ground contact at each wheel patch. The airframe is
%   represented as lumped masses at the three attachment nodes per the
%   tricycle weight distribution (10 percent nose, 45 percent each main).
%   Initial velocity v_0 = -2.6 m/s on every node. Total simulated time
%   0.05 s with dt = 1e-5 s. Rayleigh damping is tuned to 3 percent on the
%   first two elastic modes of the constrained (K, M) pencil.
%
%   Returns a struct with peak quantities and time histories. The caller
%   (main.m) handles plotting and CSV output.
%
%   David Angelou, U-M ME, 2026.

    % Build the LG model. Same nodes and elements as the static case.
    [lg_nodes, lg_elements, contacts] = build_landing_gear(params);
    n_nodes = size(lg_nodes, 1);
    n_dof   = 6 * n_nodes;

    % Linear system matrices: same K and M as the static analysis would
    % see, but with no DOF constraints. The contact at the wheel patches
    % is enforced through a penalty force in F_func, not a BC.
    K = assemble_global_K(lg_nodes, lg_elements, lg_section, mat.al7075);
    M = assemble_global_M(lg_nodes, lg_elements, lg_section, mat.al7075);

    % Lumped airframe mass at the three attachment nodes (translational
    % DOFs only). Each main carries 0.45 MTOW, the nose 0.10 MTOW.
    W_share      = [0.10, 0.45, 0.45];
    m_share      = W_share * params.MTOW_kg;
    attach_nodes = [contacts.attach_nose, contacts.attach_main_L, contacts.attach_main_R];

    M_aug = M;
    for i = 1:3
        for dir = 1:3   % three translational DOFs only, no rotational lumping
            dof = 6*(attach_nodes(i) - 1) + dir;
            M_aug(dof, dof) = M_aug(dof, dof) + m_share(i);
        end
    end

    % Lumped wheel + tire mass at each contact node, z direction only.
    % A bare massless strut tip is unphysical and would produce a numerical
    % bounce against a stiff penalty contact; representing the wheel and
    % tire as 10 kg per contact gives the contact patch finite inertia.
    m_wheel = 10.0;   % kg per wheel + tire assembly
    contact_nodes_pre = [contacts.nose, contacts.main_left, contacts.main_right];
    for c = contact_nodes_pre
        dof_z = 6*(c-1) + 3;
        M_aug(dof_z, dof_z) = M_aug(dof_z, dof_z) + m_wheel;
    end

    fprintf('Drop test mass: strut alone %.1f kg, augmented (airframe + 3 wheels @ %.0f kg each) total %.1f kg.\n', ...
            full(sum(diag(M(1:6:end, 1:6:end)))), m_wheel, ...
            full(sum(diag(M_aug(1:6:end, 1:6:end)))));

    % Rayleigh damping. Pin the three wheel-patch translations to compute
    % the constrained modes (otherwise the assembly has 6 rigid body modes
    % and the "first elastic mode" indexing is ambiguous).
    contact_nodes = [contacts.nose, contacts.main_left, contacts.main_right];
    fixed_for_damping = [];
    for c = contact_nodes
        fixed_for_damping = [fixed_for_damping, 6*(c-1) + (1:3)]; %#ok<AGROW>
    end
    target_zeta = 0.03;
    [C, damp_info] = build_damping_matrix(K, M_aug, target_zeta, [1 2], fixed_for_damping);

    % Penalty contact at the three wheel patches, z direction only.
    % Initial wheel-node z is 0 (ground plane). U_z < 0 means penetration.
    % The value 5e6 N/m represents tire vertical compliance, not a rigid
    % wall enforcement. A typical light aircraft tire has vertical
    % stiffness in this range and absorbs ~50 to 100 mm of deflection at
    % peak landing load.
    k_pen = 5e6;
    contact_dof_z = 6*(contact_nodes - 1) + 3;
    fprintf('Penalty contact stiffness: k_pen = %.1e N/m at %d wheel patches (models tire compliance).\n', ...
            k_pen, length(contact_dof_z));

    % Static gravity preload on the lumped airframe mass. Small compared to
    % the inertial impact loads but kept for physical fidelity.
    F_grav = zeros(n_dof, 1);
    for i = 1:3
        F_grav(6*(attach_nodes(i) - 1) + 3) = -m_share(i) * params.g;
    end

    F_func = @(t, U) F_grav + penalty_force(U, contact_dof_z, k_pen);

    % Initial conditions: every node moving downward at the sink rate.
    sink_rate = 2.6;   % m/s, FAR 23.473 utility category
    U0 = zeros(n_dof, 1);
    V0 = zeros(n_dof, 1);
    for i = 1:n_nodes
        V0(6*(i-1) + 3) = -sink_rate;
    end

    % Consistent initial acceleration: M A0 = F(0, U0) - C V0 - K U0
    F0 = F_func(0, U0);
    A0 = M_aug \ (F0 - C*V0 - K*U0);

    % Time integration. The airframe-bending mode (~3.5 Hz, period 285 ms)
    % governs the impact response. We integrate for 150 ms, covering more
    % than a half period so the peak strut load is captured and rebound
    % has begun. dt = 1e-5 s resolves the tire contact period (~16 ms with
    % these parameters) to better than 1 percent.
    dt      = 1e-5;
    t_end   = 0.15;
    n_steps = round(t_end / dt);
    fprintf('Newmark drop test: %d steps, dt = %.0e s, t_end = %.3f s.\n', n_steps, dt, t_end);

    tic;
    [U_hist, V_hist, A_hist, t_hist] = ...
        newmark_integrator(M_aug, C, K, U0, V0, A0, dt, n_steps, F_func);
    elapsed = toc;
    fprintf('Newmark loop elapsed: %.2f s wallclock.\n', elapsed);

    % --- Post-process the time history --------------------------------
    n_t = n_steps + 1;

    % Contact force history (sum of all three wheel patches in z)
    contact_force_z = zeros(1, n_t);
    for n = 1:n_t
        u_now = U_hist(:, n);
        for cd = contact_dof_z
            if u_now(cd) < 0
                contact_force_z(n) = contact_force_z(n) + (-k_pen * u_now(cd));
            end
        end
    end
    [peak_contact, peak_idx] = max(contact_force_z);

    % Strut internal force history (element 2 = main left strut)
    main_left_elem = 2;
    axial_history  = zeros(1, n_t);
    bend_history   = zeros(1, n_t);
    vm_history     = zeros(1, n_t);
    for n = 1:n_t
        r = post_process(lg_nodes, lg_elements, U_hist(:, n), lg_section, mat.al7075);
        axial_history(n) = r(main_left_elem).axial_force_N;
        bend_history(n)  = sqrt(r(main_left_elem).moment_y_Nm^2 + r(main_left_elem).moment_z_Nm^2);
        vm_history(n)    = r(main_left_elem).sigma_vm_Pa;
    end

    % Peak strut quantities at the peak contact time (synchronized snapshot)
    U_peak     = U_hist(:, peak_idx);
    r_peak     = post_process(lg_nodes, lg_elements, U_peak, lg_section, mat.al7075);
    sigma_vm   = arrayfun(@(s) s.sigma_vm_Pa,    r_peak);
    rf_peak    = arrayfun(@(s) s.reserve_factor, r_peak);
    peak_vm    = max(sigma_vm);
    min_rf     = min(rf_peak);

    % Independent peak across the full history (peak VM can lag peak contact)
    peak_vm_history = max(vm_history);

    % Vertical acceleration at the main-left wheel and its attachment
    wheel_dof_z  = 6*(contacts.main_left - 1) + 3;
    attach_dof_z = 6*(contacts.attach_main_L - 1) + 3;
    accel_wheel_g  = A_hist(wheel_dof_z, :)  / params.g;
    accel_attach_g = A_hist(attach_dof_z, :) / params.g;

    % Static 3g reference: full vertical reaction the static analysis used
    W_3g_total = 3 * params.MTOW_kg * params.g;

    % Pack results
    results.t                 = t_hist;
    results.contact_force_z   = contact_force_z;
    results.axial_history     = axial_history;
    results.bend_history      = bend_history;
    results.vm_history        = vm_history;
    results.accel_wheel_g     = accel_wheel_g;
    results.accel_attach_g    = accel_attach_g;
    results.peak_idx          = peak_idx;
    results.peak_contact      = peak_contact;
    results.static_3g_ref     = W_3g_total;
    results.dynamic_factor    = peak_contact / W_3g_total;
    results.peak_axial        = max(abs(axial_history));
    results.peak_bending      = max(bend_history);
    results.peak_vm           = max(peak_vm, peak_vm_history);
    results.min_rf            = min_rf;
    results.peak_accel_wheel  = max(abs(accel_wheel_g));
    results.peak_accel_attach = max(abs(accel_attach_g));
    results.damping_info      = damp_info;
    results.k_penalty         = k_pen;

    fprintf('\nDrop test results:\n');
    fprintf('  Peak total contact force (kN)       : %.1f\n', peak_contact/1e3);
    fprintf('  Static 3g reference     (kN)        : %.1f\n', W_3g_total/1e3);
    fprintf('  Dynamic factor (peak / static 3g)   : %.2f\n', results.dynamic_factor);
    fprintf('  Peak strut von Mises (MPa)          : %.1f\n', results.peak_vm/1e6);
    fprintf('  Peak strut RF (snapshot at peak)    : %.2f\n', results.min_rf);
    fprintf('  Peak axial force (kN)               : %.1f\n', results.peak_axial/1e3);
    fprintf('  Peak bending moment (kN.m)          : %.1f\n', results.peak_bending/1e3);
    fprintf('  Peak vertical accel at wheel (g)    : %.1f\n', results.peak_accel_wheel);
    fprintf('  Peak vertical accel at attach (g)   : %.1f\n', results.peak_accel_attach);
end

% --------------------------------------------------------------------------
function F = penalty_force(U, contact_dofs_z, k_pen)
    % One-sided penalty contact: force only when the wheel patch penetrates
    % below the ground plane (z = 0 reference). Vectorized for the three
    % wheel patches.
    F = zeros(length(U), 1);
    for cd = contact_dofs_z
        z = U(cd);
        if z < 0
            F(cd) = -k_pen * z;   % upward reaction
        end
    end
end
