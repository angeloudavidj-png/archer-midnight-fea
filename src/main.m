%% MAIN  Archer Midnight FEA driver
%
%   Runs frame analysis under four flight load cases and landing gear
%   analysis under a 3g hard landing. Writes figures to ../docs/figures/.
%
%   Usage:  >> main
%
%   David Angelou, U-M ME, 2026.

clearvars; clc; close all;

%% Setup
fprintf('============================================================\n');
fprintf('Archer Midnight FEA, MATLAB beam element analysis\n');
fprintf('============================================================\n\n');

params = aircraft_parameters();
mat    = material_properties();

% Hollow circular tube section properties (see tube_section.m)
frame_section = tube_section(params.boom_OD_m, params.boom_t_m);
lg_section    = tube_section(params.lg_OD_m,   params.lg_t_m);

fprintf('Frame tube section: OD = %.0f mm, wall = %.1f mm, A = %.2f mm^2\n', ...
    params.boom_OD_m*1e3, params.boom_t_m*1e3, frame_section.A*1e6);
fprintf('LG strut section : OD = %.0f mm, wall = %.1f mm, A = %.2f mm^2\n\n', ...
    params.lg_OD_m*1e3, params.lg_t_m*1e3, lg_section.A*1e6);

%% Build the frame
[frame_nodes, frame_elements] = build_frame_geometry(params);
fprintf('Frame model: %d nodes, %d beam elements\n', ...
    size(frame_nodes,1), size(frame_elements,1));

% Assemble global stiffness
K_frame = assemble_global_K(frame_nodes, frame_elements, frame_section, mat.cfrp);

% Boundary conditions:
% For each flight case we restrain rigid body motion at the central wing
% attachment node (spine node 3), fully fixed. This models inertia
% relief approximately for trim analysis.
wing_attach_node = 3;  % from build_frame_geometry
bc_frame = { wing_attach_node, 1:6 };

%% Frame load cases
load_cases = {'LC1_hover_static', 'LC2_2g_maneuver', 'LC3_cruise', 'LC4_motor_out'};
case_titles = {'LC1 hover 1g', 'LC2 maneuver 2g', 'LC3 cruise', 'LC4 motor out 1.5g'};

if ~exist('../docs/figures', 'dir')
    mkdir('../docs/figures');
end

frame_summary = struct();

for i = 1:numel(load_cases)
    lc = load_cases{i};
    fprintf('\n>>> Frame analysis: %s\n', lc);

    F = apply_loads(frame_nodes, params, lc);
    U = solve_fea(K_frame, F, bc_frame);
    results = post_process(frame_nodes, frame_elements, U, frame_section, mat.cfrp);

    % Summary numbers
    sigma_vm_all = arrayfun(@(r) r.sigma_vm_Pa, results);
    RF_all       = arrayfun(@(r) r.reserve_factor, results);
    max_disp     = max(abs(U(1:6:end)) + abs(U(2:6:end)) + abs(U(3:6:end)));

    fprintf('   max VM stress    = %.1f MPa\n', max(sigma_vm_all)/1e6);
    fprintf('   min reserve fac. = %.2f\n', min(RF_all));
    fprintf('   max nodal disp.  = %.2f mm\n', max_disp*1e3);

    frame_summary.(['case', num2str(i)]).load_case   = lc;
    frame_summary.(['case', num2str(i)]).max_vm_MPa  = max(sigma_vm_all)/1e6;
    frame_summary.(['case', num2str(i)]).min_RF      = min(RF_all);
    frame_summary.(['case', num2str(i)]).max_disp_mm = max_disp*1e3;

    % Capture peak element for the governing LC2 case so we can hand it
    % off to the composite ply failure analysis later. We also keep the
    % full results array, displacement vector, and force vector so the
    % Phase 5 exports can write Nastran .bdf and Ansys .mac files of the
    % same case.
    if strcmp(lc, 'LC2_2g_maneuver')
        [~, peak_elem_idx_lc2] = max(sigma_vm_all);
        peak_elem_lc2          = results(peak_elem_idx_lc2);
        results_lc2            = results;
        U_lc2                  = U;
        F_lc2                  = F;
    end

    % Plots
    visualize_deformed(frame_nodes, frame_elements, U, 100, ...
        case_titles{i}, sprintf('../docs/figures/frame_%s_deformed.png', lc));
    plot_stress_contour(frame_nodes, frame_elements, results, ...
        sprintf('Frame Von Mises stress, %s', case_titles{i}), ...
        sprintf('../docs/figures/frame_%s_stress.png', lc));
end

%% Landing gear analysis
fprintf('\n============================================================\n');
fprintf('Landing gear analysis, LCG 3g hard landing\n');
fprintf('============================================================\n');

[lg_nodes, lg_elements, contacts] = build_landing_gear(params);
fprintf('Landing gear model: %d nodes, %d beam elements\n', ...
    size(lg_nodes,1), size(lg_elements,1));

K_lg = assemble_global_K(lg_nodes, lg_elements, lg_section, mat.al7075);

% BCs for LG: brake-locked clamped wheel patches. All 6 DOFs fixed at the
% three ground contacts. Translation-only BCs leave the nose strut free to
% rotate about the contact and the main subassembly free to spin about the
% line through the two main contacts, both of which produce a singular K.
% Brake-locked is the realistic condition for the spin-down phase of a hard
% landing and removes the rigid body modes.
bc_lg = { contacts.nose,       1:6;
          contacts.main_left,  1:6;
          contacts.main_right, 1:6 };

% Load: 3g vertical reaction distributed per static balance.
% Nose carries ~10% of MTOW, mains carry ~45% each (typical tricycle).
nz = params.nz_hard_landing;
W_total = nz * params.MTOW_kg * params.g;

F_lg = zeros(6 * size(lg_nodes, 1), 1);
F_lg(6*(contacts.attach_nose - 1) + 3)   = -0.10 * W_total;
F_lg(6*(contacts.attach_main_L - 1) + 3) = -0.45 * W_total;
F_lg(6*(contacts.attach_main_R - 1) + 3) = -0.45 * W_total;

% Horizontal drag from airframe forward inertia, mu = 0.5 of vertical
% reaction. Applied at the attachment nodes so it propagates through the
% struts; applied at clamped contact nodes it would short circuit straight
% into the reaction and produce no internal stress.
F_lg(6*(contacts.attach_nose - 1) + 1)   = -0.5 * 0.10 * W_total;
F_lg(6*(contacts.attach_main_L - 1) + 1) = -0.5 * 0.45 * W_total;
F_lg(6*(contacts.attach_main_R - 1) + 1) = -0.5 * 0.45 * W_total;

U_lg = solve_fea(K_lg, F_lg, bc_lg);
lg_results = post_process(lg_nodes, lg_elements, U_lg, lg_section, mat.al7075);

sigma_vm_lg = arrayfun(@(r) r.sigma_vm_Pa, lg_results);
RF_lg       = arrayfun(@(r) r.reserve_factor, lg_results);
max_disp_lg = max(abs(U_lg(1:6:end)) + abs(U_lg(2:6:end)) + abs(U_lg(3:6:end)));

fprintf('\nLanding gear results:\n');
for e = 1:size(lg_elements, 1)
    fprintf('   element %d: VM = %.1f MPa, RF = %.2f\n', ...
            e, sigma_vm_lg(e)/1e6, RF_lg(e));
end
fprintf('   max nodal disp = %.2f mm\n', max_disp_lg*1e3);

visualize_deformed(lg_nodes, lg_elements, U_lg, 50, ...
    'Landing gear, LCG 3g hard landing', ...
    '../docs/figures/landing_gear_deformed.png');
plot_stress_contour(lg_nodes, lg_elements, lg_results, ...
    'Landing gear Von Mises stress, LCG 3g hard landing', ...
    '../docs/figures/landing_gear_stress.png');

%% Modal analysis of the frame
fprintf('\n============================================================\n');
fprintf('Modal analysis of the frame\n');
fprintf('============================================================\n');

M_frame = assemble_global_M(frame_nodes, frame_elements, frame_section, mat.cfrp);

fprintf('Frame mass matrix assembled. Total frame mass = %.1f kg\n', ...
        full(sum(diag(M_frame(1:6:end, 1:6:end)))));

% Constrained modal analysis: wing attachment node fully fixed, matching
% the static load case BC.
fixed_dofs_modal = 6*(wing_attach_node-1) + (1:6);
n_modes_keep = 20;
[freq_Hz_constrained, modes_constrained] = ...
    modal_analysis(K_frame, M_frame, n_modes_keep, fixed_dofs_modal);

fprintf('\nFirst 10 elastic mode frequencies (Hz), wing attach node fixed:\n');
for i = 1:min(10, length(freq_Hz_constrained))
    fprintf('   Mode %2d: %7.2f Hz\n', i, freq_Hz_constrained(i));
end

% Rotor blade pass harmonics. Public estimates put eVTOL rotors at 5 blades
% per hub. Hover RPM is the higher-power regime, cruise tilt rotors run
% slower.
n_blades = 5;
rpm_hover_range  = [1500, 2000];
rpm_cruise_range = [1000, 1500];
harmonics = 1:6;   % 1P up to ~6P, brackets 5-blade pass and a margin

% Check each frequency against each harmonic at every RPM in the regime
% sweeps. The 15 percent margin is the helicopter-industry rule for primary
% resonance avoidance.
resonance_tol = 0.15;
resonance_flags = {};
all_regimes = {rpm_hover_range, 'hover'; rpm_cruise_range, 'cruise tilt'};

for m = 1:min(10, length(freq_Hz_constrained))
    f_mode = freq_Hz_constrained(m);
    if f_mode < 1.0
        continue   % skip near-zero modes (shouldn't occur with this BC)
    end
    for h = harmonics
        % Find the RPM at which harmonic h crosses this mode frequency.
        rpm_cross = 60 * f_mode / h;
        for r = 1:size(all_regimes, 1)
            rpm_lo = all_regimes{r, 1}(1);
            rpm_hi = all_regimes{r, 1}(2);
            regime_name = all_regimes{r, 2};
            % Resonance falls within the regime band if the crossing RPM is
            % within +/- 15 percent of the band edges.
            band_lo = rpm_lo * (1 - resonance_tol);
            band_hi = rpm_hi * (1 + resonance_tol);
            if rpm_cross >= band_lo && rpm_cross <= band_hi
                resonance_flags{end+1} = sprintf( ...
                    'Mode %d (%.1f Hz) intersects %dP in %s band at %.0f RPM', ...
                    m, f_mode, h, regime_name, rpm_cross); %#ok<AGROW>
            end
        end
    end
end

if isempty(resonance_flags)
    fprintf('\nNo airframe modes within %.0f%% of any blade-pass harmonic in the hover or cruise RPM bands.\n', resonance_tol*100);
else
    fprintf('\nResonance flags (%.0f%% margin):\n', resonance_tol*100);
    for i = 1:numel(resonance_flags)
        fprintf('  ! %s\n', resonance_flags{i});
    end
end

% Campbell diagram
campbell_fig = figure('Visible', 'off', 'Position', [100 100 900 650]);
hold on; grid on; box on;

rpm_axis = linspace(800, 2300, 200);
harmonic_colors = lines(numel(harmonics));
for h = harmonics
    plot(rpm_axis, h * rpm_axis / 60, '-', 'Color', harmonic_colors(h,:), ...
         'LineWidth', 1.6, 'DisplayName', sprintf('%dP', h));
end

% Airframe modes as horizontal dashed lines.
mode_colors = 0.4 * ones(min(10, length(freq_Hz_constrained)), 3);
for m = 1:min(10, length(freq_Hz_constrained))
    f_mode = freq_Hz_constrained(m);
    if f_mode < 1.0
        continue
    end
    plot(rpm_axis, f_mode * ones(size(rpm_axis)), '--', ...
         'Color', mode_colors(m,:), 'LineWidth', 1.0, 'HandleVisibility', 'off');
    text(rpm_axis(end), f_mode, sprintf(' M%d (%.1f Hz)', m, f_mode), ...
         'Color', mode_colors(m,:), 'FontSize', 8, ...
         'VerticalAlignment', 'middle');
end

% Shade hover and cruise RPM bands.
y_top = max(harmonics) * max(rpm_axis) / 60 * 1.02;
patch([rpm_hover_range(1) rpm_hover_range(2) rpm_hover_range(2) rpm_hover_range(1)], ...
      [0 0 y_top y_top], [0.4 0.4 1.0], ...
      'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
patch([rpm_cruise_range(1) rpm_cruise_range(2) rpm_cruise_range(2) rpm_cruise_range(1)], ...
      [0 0 y_top y_top], [1.0 0.4 0.4], ...
      'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(mean(rpm_hover_range), y_top*0.96, 'Hover RPM band', ...
     'HorizontalAlignment', 'center', 'Color', [0 0 0.6], 'FontWeight', 'bold');
text(mean(rpm_cruise_range), y_top*0.92, 'Cruise tilt RPM band', ...
     'HorizontalAlignment', 'center', 'Color', [0.6 0 0], 'FontWeight', 'bold');

xlabel('Rotor RPM');
ylabel('Frequency (Hz)');
title(sprintf('Campbell diagram, %d-blade rotors, first 10 airframe elastic modes', n_blades));
legend('Location', 'northwest');
xlim([rpm_axis(1), rpm_axis(end)]);
ylim([0, y_top]);

saveas(campbell_fig, '../docs/figures/campbell_diagram.png');
close(campbell_fig);
fprintf('\nCampbell diagram saved to docs/figures/campbell_diagram.png\n');

% Modal CSV summary
modal_csv = '../data/modal_summary.csv';
fid_m = fopen(modal_csv, 'w');
fprintf(fid_m, 'mode_index,frequency_Hz\n');
for i = 1:length(freq_Hz_constrained)
    fprintf(fid_m, '%d,%.4f\n', i, freq_Hz_constrained(i));
end
fclose(fid_m);
fprintf('Modal CSV written to %s\n', modal_csv);

%% Landing gear drop test dynamics, Newmark integration
fprintf('\n============================================================\n');
fprintf('Landing gear drop test dynamics (Newmark beta=0.25, gamma=0.5)\n');
fprintf('============================================================\n');

drop_results = drop_test(params, mat, lg_section);

% Plot 1: main strut axial force history
fig_force = figure('Visible', 'off', 'Position', [100 100 900 500]);
plot(drop_results.t*1000, drop_results.axial_history/1000, 'b-', 'LineWidth', 1.6);
hold on; grid on; box on;
% Mark the peak contact time
plot(drop_results.t(drop_results.peak_idx)*1000 * [1 1], ylim, ...
     'k--', 'LineWidth', 1.0);
text(drop_results.t(drop_results.peak_idx)*1000, 0, ...
     sprintf(' peak contact at %.1f ms', drop_results.t(drop_results.peak_idx)*1000), ...
     'VerticalAlignment', 'middle');
xlabel('Time (ms)');
ylabel('Main strut axial force (kN)');
title('Drop test: main strut axial force, FAR 23.473 sink rate 2.6 m/s');
saveas(fig_force, '../docs/figures/drop_test_strut_force.png');
close(fig_force);

% Plot 2: nodal vertical acceleration at wheel and at attachment
fig_accel = figure('Visible', 'off', 'Position', [100 100 900 500]);
plot(drop_results.t*1000, drop_results.accel_wheel_g,  'r-', 'LineWidth', 1.6, ...
     'DisplayName', 'Main wheel contact');
hold on; grid on; box on;
plot(drop_results.t*1000, drop_results.accel_attach_g, 'b-', 'LineWidth', 1.6, ...
     'DisplayName', 'Main strut attachment');
xlabel('Time (ms)');
ylabel('Vertical acceleration (g)');
title('Drop test: nodal vertical acceleration vs time');
legend('Location', 'northeast');
saveas(fig_accel, '../docs/figures/drop_test_accel.png');
close(fig_accel);
fprintf('\nDrop test figures saved to docs/figures/drop_test_*.png\n');

% Drop test CSV
drop_csv = '../data/drop_test_summary.csv';
fid_d = fopen(drop_csv, 'w');
fprintf(fid_d, 'quantity,value,unit\n');
fprintf(fid_d, 'sink_rate,%.2f,m/s\n', 2.6);
fprintf(fid_d, 'penalty_stiffness,%.2e,N/m\n', drop_results.k_penalty);
fprintf(fid_d, 'damping_ratio,%.3f,-\n', 0.03);
fprintf(fid_d, 'damping_alpha,%.4e,1/s\n', drop_results.damping_info.alpha);
fprintf(fid_d, 'damping_beta,%.4e,s\n',  drop_results.damping_info.beta);
fprintf(fid_d, 'peak_contact_force,%.0f,N\n', drop_results.peak_contact);
fprintf(fid_d, 'static_3g_reference,%.0f,N\n', drop_results.static_3g_ref);
fprintf(fid_d, 'dynamic_factor,%.3f,-\n', drop_results.dynamic_factor);
fprintf(fid_d, 'peak_strut_vm,%.2f,MPa\n', drop_results.peak_vm/1e6);
fprintf(fid_d, 'peak_strut_rf,%.2f,-\n', drop_results.min_rf);
fprintf(fid_d, 'peak_axial_force,%.0f,N\n', drop_results.peak_axial);
fprintf(fid_d, 'peak_bending_moment,%.1f,N.m\n', drop_results.peak_bending);
fprintf(fid_d, 'peak_accel_wheel,%.2f,g\n', drop_results.peak_accel_wheel);
fprintf(fid_d, 'peak_accel_attach,%.2f,g\n', drop_results.peak_accel_attach);
fclose(fid_d);
fprintf('Drop test CSV written to %s\n', drop_csv);

%% Boom composite ply failure analysis (Tsai-Wu + Hashin)
fprintf('\n============================================================\n');
fprintf('Boom composite ply failure analysis, IM7/8552 quasi-iso layup\n');
fprintf('============================================================\n');

comp_lamina = material_composite();
layup       = composite_layup(comp_lamina);   % default [0/45/-45/90]_s

fprintf('Layup: [%s]_s, per-ply %.3f mm, total %.3f mm\n', ...
        regexprep(num2str(layup.orientations_deg(1:end/2)), '\s+', '/'), ...
        layup.t_ply*1e3, layup.h_total*1e3);
fprintf('Effective laminate E_x = %.1f GPa, nu_xy = %.3f\n', ...
        layup.E_eff_x/1e9, layup.nu_eff_xy);

% Peak boom element from LC2 (governing flight case)
sigma_total_peak = peak_elem_lc2.sigma_total_Pa;
fprintf('Peak boom element (LC2) %d: sigma_axial = %.1f MPa, sigma_bend = %.1f MPa, |sigma_total| = %.1f MPa\n', ...
        peak_elem_idx_lc2, ...
        peak_elem_lc2.sigma_axial_Pa/1e6, ...
        peak_elem_lc2.sigma_bend_max_Pa/1e6, ...
        sigma_total_peak/1e6);

% CFRP has Xc (1590 MPa) lower than Xt (2850 MPa), so the compression case
% governs the 0 degree plies. We evaluate both signs and pick the worse.
ply_tens = boom_ply_analysis( sigma_total_peak, layup, comp_lamina);
ply_comp = boom_ply_analysis(-sigma_total_peak, layup, comp_lamina);

if ply_comp.critical_tsai_wu > ply_tens.critical_tsai_wu
    ply_result      = ply_comp;
    governing_sign  = 'compression';
    other_sign_name = 'tension';
    other_sign_tw   = ply_tens.critical_tsai_wu;
else
    ply_result      = ply_tens;
    governing_sign  = 'tension';
    other_sign_name = 'compression';
    other_sign_tw   = ply_comp.critical_tsai_wu;
end

fprintf('\nGoverning sign for the layup: %s (Tsai-Wu = %.4f; %s peak = %.4f)\n', ...
        governing_sign, ply_result.critical_tsai_wu, other_sign_name, other_sign_tw);
fprintf('Critical ply       : %d (orientation %d deg)\n', ply_result.critical_ply, ply_result.critical_orientation);
fprintf('Critical mode      : %s\n', ply_result.critical_hashin_mode);
fprintf('Peak Tsai-Wu       : %.4f\n', ply_result.critical_tsai_wu);
fprintf('Hashin fiber index : %.4f\n', ply_result.critical_hashin_fiber);
fprintf('Hashin matrix index: %.4f\n', ply_result.critical_hashin_matrix);

fprintf('\nPer-ply stress and failure indices (governing sign):\n');
fprintf('  %4s %6s %12s %12s %12s %10s %10s %10s\n', ...
        'ply', 'theta', 's11_MPa', 's22_MPa', 't12_MPa', 'TW', 'Hash_F', 'Hash_M');
for k = 1:length(ply_result.ply)
    p = ply_result.ply(k);
    fprintf('  %4d %6.0f %12.2f %12.2f %12.2f %10.4f %10.4f %10.4f\n', ...
            p.idx, p.theta_deg, p.sigma_11/1e6, p.sigma_22/1e6, p.tau_12/1e6, ...
            p.tsai_wu, p.hashin_fiber, p.hashin_matrix);
end

% CSV
ply_csv = '../data/boom_ply_summary.csv';
fid_p = fopen(ply_csv, 'w');
fprintf(fid_p, '# Boom ply failure analysis, %s layup, governing sign = %s, applied sigma_xx = %.1f MPa\n', ...
        'quasi-iso [0/45/-45/90]_s', governing_sign, ply_result.sigma_xx_applied/1e6);
fprintf(fid_p, 'ply_index,orientation_deg,sigma_11_MPa,sigma_22_MPa,tau_12_MPa,tsai_wu_index,hashin_fiber,hashin_matrix\n');
for k = 1:length(ply_result.ply)
    p = ply_result.ply(k);
    fprintf(fid_p, '%d,%d,%.2f,%.2f,%.2f,%.4f,%.4f,%.4f\n', ...
            p.idx, p.theta_deg, p.sigma_11/1e6, p.sigma_22/1e6, p.tau_12/1e6, ...
            p.tsai_wu, p.hashin_fiber, p.hashin_matrix);
end
fclose(fid_p);
fprintf('\nBoom ply CSV written to %s\n', ply_csv);

% Figure
fig_ply = figure('Visible', 'off', 'Position', [100 100 900 500]);
tw_all  = arrayfun(@(p) p.tsai_wu,       ply_result.ply);
hf_all  = arrayfun(@(p) p.hashin_fiber,  ply_result.ply);
hm_all  = arrayfun(@(p) p.hashin_matrix, ply_result.ply);
n_plies = length(tw_all);

bar_data = [tw_all(:), hf_all(:), hm_all(:)];
hb = bar(1:n_plies, bar_data, 'grouped');
hb(1).FaceColor = [0.20 0.40 0.80];   % Tsai-Wu blue
hb(2).FaceColor = [0.80 0.30 0.20];   % Hashin fiber red
hb(3).FaceColor = [0.20 0.70 0.30];   % Hashin matrix green
hold on; grid on; box on;
plot([0.4, n_plies+0.6], [1 1], 'k--', 'LineWidth', 1.5);
text(0.5, 1.02, ' Failure threshold (index = 1)', 'VerticalAlignment', 'bottom');

% Highlight critical ply with a star marker above its TW bar
plot(ply_result.critical_ply, tw_all(ply_result.critical_ply) + 0.02, 'kp', ...
     'MarkerSize', 14, 'MarkerFaceColor', 'y');

xlabel('Ply index (laminate bottom to top)');
ylabel('Failure index');
title(sprintf('Boom layup failure indices, LC2 sigma_{xx} = %.0f MPa (%s), critical ply %d (%d deg, %s)', ...
              abs(ply_result.sigma_xx_applied)/1e6, governing_sign, ...
              ply_result.critical_ply, ply_result.critical_orientation, ...
              strrep(ply_result.critical_hashin_mode, '_', ' ')));
legend({'Tsai-Wu', 'Hashin fiber', 'Hashin matrix'}, 'Location', 'best');

% Orientation labels under the bars
xticks(1:n_plies);
xtl = arrayfun(@(p) sprintf('%d°', p.theta_deg), ply_result.ply, 'UniformOutput', false);
xticklabels(xtl);

saveas(fig_ply, '../docs/figures/boom_layup_failure.png');
close(fig_ply);
fprintf('Boom layup failure figure saved to docs/figures/boom_layup_failure.png\n');

%% Parametric sizing sweep over boom and landing gear sections
fprintf('\n============================================================\n');
fprintf('Parametric sweep: boom and landing gear cross sections\n');
fprintf('============================================================\n');

sweep = parametric_sweep(params, mat);
T = sweep.table;
hdr = sweep.header;

% Find current design row (boom 300 mm, 10 mm wall, strut 100 mm, 8 mm wall).
current_row_mask = abs(T(:,1) - 300) < 1e-6 & abs(T(:,2) - 10) < 1e-6 ...
                 & abs(T(:,3) - 100) < 1e-6 & abs(T(:,4) -  8) < 1e-6;
current_row = T(current_row_mask, :);

% Compute the pre-Phase-0 design (60 mm x 5 mm strut) by re-running the LG
% analysis for that section against the same loads. The 60 mm strut is off
% the sweep grid (grid starts at 80 mm) so we evaluate it as a single point
% for the Pareto plot.
phase0_before_strut = tube_section(0.060, 0.005);
[lg_nodes_p0, lg_elements_p0, contacts_p0] = build_landing_gear(params);
K_lg_p0 = assemble_global_K(lg_nodes_p0, lg_elements_p0, phase0_before_strut, mat.al7075);
bc_lg_p0 = { contacts_p0.nose, 1:6; contacts_p0.main_left, 1:6; contacts_p0.main_right, 1:6 };
nz_p0 = params.nz_hard_landing;
W_p0  = nz_p0 * params.MTOW_kg * params.g;
F_lg_p0 = zeros(6 * size(lg_nodes_p0, 1), 1);
F_lg_p0(6*(contacts_p0.attach_nose   - 1) + 3) = -0.10 * W_p0;
F_lg_p0(6*(contacts_p0.attach_main_L - 1) + 3) = -0.45 * W_p0;
F_lg_p0(6*(contacts_p0.attach_main_R - 1) + 3) = -0.45 * W_p0;
F_lg_p0(6*(contacts_p0.attach_nose   - 1) + 1) = -0.5 * 0.10 * W_p0;
F_lg_p0(6*(contacts_p0.attach_main_L - 1) + 1) = -0.5 * 0.45 * W_p0;
F_lg_p0(6*(contacts_p0.attach_main_R - 1) + 1) = -0.5 * 0.45 * W_p0;
U_lg_p0 = solve_fea(K_lg_p0, F_lg_p0, bc_lg_p0);
res_lg_p0 = post_process(lg_nodes_p0, lg_elements_p0, U_lg_p0, phase0_before_strut, mat.al7075);
rf_lg_p0 = min(arrayfun(@(r) r.reserve_factor, res_lg_p0));
L_lg_total_p0 = sum(arrayfun(@(e) norm(lg_nodes_p0(lg_elements_p0(e,2),:) - lg_nodes_p0(lg_elements_p0(e,1),:)), 1:size(lg_elements_p0,1)));
mass_lg_p0 = mat.al7075.rho * phase0_before_strut.A * L_lg_total_p0;

% Pre-Phase-0 frame mass is identical to current (boom unchanged), so reuse it.
frame_mass_current = current_row(5);
phase0_before_total_mass = frame_mass_current + mass_lg_p0;
phase0_before_RF = rf_lg_p0;   % governing (frame RF 2.00 is higher)

fprintf('Current design (300 x 10 boom, 100 x 8 strut): mass = %.1f kg, min RF = %.2f\n', ...
        current_row(7), current_row(10));
fprintf('Pre-Phase-0 (300 x 10 boom, 60 x 5 strut)    : mass = %.1f kg, min RF = %.2f\n', ...
        phase0_before_total_mass, phase0_before_RF);

% Recommended optima at two RF targets
[opt15_mass, opt15_idx] = min(T(T(:,10) >= 1.5, 7));
feas15 = T(T(:,10) >= 1.5, :);
opt15_row = feas15(opt15_idx, :);

feas20_mask = T(:,10) >= 2.0;
if any(feas20_mask)
    feas20 = T(feas20_mask, :);
    [opt20_mass, opt20_idx] = min(feas20(:, 7));
    opt20_row = feas20(opt20_idx, :);
    have_opt20 = true;
else
    opt20_row = [];
    have_opt20 = false;
end

fprintf('\nRecommended optima from the sweep:\n');
fprintf('  Min-mass at RF >= 1.5: boom %.0f x %.1f mm, strut %.0f x %.0f mm, mass %.1f kg, min RF %.2f\n', ...
        opt15_row(1), opt15_row(2), opt15_row(3), opt15_row(4), opt15_row(7), opt15_row(10));
if have_opt20
    fprintf('  Min-mass at RF >= 2.0: boom %.0f x %.1f mm, strut %.0f x %.0f mm, mass %.1f kg, min RF %.2f\n', ...
            opt20_row(1), opt20_row(2), opt20_row(3), opt20_row(4), opt20_row(7), opt20_row(10));
else
    fprintf('  No design in the grid achieves RF >= 2.0. Tightest feasible RF is %.2f.\n', max(T(:,10)));
end

% CSV
sweep_csv = '../data/parametric_sweep.csv';
fid_s = fopen(sweep_csv, 'w');
fprintf(fid_s, '%s\n', strjoin(hdr, ','));
for i = 1:size(T, 1)
    fprintf(fid_s, '%.1f,%.2f,%.1f,%.1f,%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.2f,%.2f,%d\n', T(i, :));
end
fclose(fid_s);
fprintf('Parametric sweep CSV written to %s\n', sweep_csv);

% Pareto plot
fig_p = figure('Visible', 'off', 'Position', [100 100 1100 700]);
hold on; grid on; box on;

mass_all = T(:, 7);
rf_all   = T(:, 10);
feas_mask = T(:, 13) > 0.5;

scatter(mass_all(~feas_mask), rf_all(~feas_mask), 18, [0.65 0.65 0.65], 'filled', ...
        'MarkerFaceAlpha', 0.35, 'DisplayName', 'Infeasible (RF < 1.5)');
scatter(mass_all(feas_mask),  rf_all(feas_mask),  22, [0.20 0.65 0.30], 'filled', ...
        'MarkerFaceAlpha', 0.55, 'DisplayName', 'Feasible (RF >= 1.5)');

% Pareto frontier line
if ~isempty(sweep.pareto)
    plot(sweep.pareto(:, 7), sweep.pareto(:, 10), 'b-', 'LineWidth', 2, ...
         'DisplayName', 'Pareto frontier');
end

% Reference RF lines
xl = xlim;
plot(xl, [1.0 1.0], 'r--', 'LineWidth', 1.0, 'DisplayName', 'RF = 1.0 (failure)');
plot(xl, [1.5 1.5], 'm--', 'LineWidth', 1.0, 'DisplayName', 'RF = 1.5 (target)');
plot(xl, [2.0 2.0], 'k--', 'LineWidth', 1.0, 'DisplayName', 'RF = 2.0 (generous)');

% Mark current design
plot(current_row(7), current_row(10), 'kp', 'MarkerSize', 18, ...
     'MarkerFaceColor', 'y', 'LineWidth', 1.5, ...
     'DisplayName', sprintf('Current (300x10, 100x8, %.0f kg, RF %.2f)', current_row(7), current_row(10)));

% Mark pre-Phase-0 design (off the grid; the original 60x5 strut)
plot(phase0_before_total_mass, phase0_before_RF, 'kx', 'MarkerSize', 14, 'LineWidth', 2, ...
     'DisplayName', sprintf('Pre-Phase 0 (60x5 strut, RF %.2f)', phase0_before_RF));

% Mark optima
plot(opt15_row(7), opt15_row(10), 'ko', 'MarkerSize', 12, 'MarkerFaceColor', [0 0.7 0], ...
     'DisplayName', sprintf('Min-mass at RF>=1.5 (%.0f kg)', opt15_row(7)));
if have_opt20
    plot(opt20_row(7), opt20_row(10), 'ks', 'MarkerSize', 12, 'MarkerFaceColor', [0 0.3 0.8], ...
         'DisplayName', sprintf('Min-mass at RF>=2.0 (%.0f kg)', opt20_row(7)));
end

xlabel('Total structural mass, frame + landing gear (kg)');
ylabel('Minimum reserve factor (LC2 frame, LCG gear)');
title(sprintf('Parametric sweep, %d combinations of boom and strut sizes, %.1f s wallclock', ...
              sweep.n_cases, sweep.elapsed_s));
legend('Location', 'best');
ylim([0, max(6, max(rf_all)+0.2)]);
saveas(fig_p, '../docs/figures/pareto_mass_vs_rf.png');
close(fig_p);
fprintf('Pareto figure saved to docs/figures/pareto_mass_vs_rf.png\n');

%% Phase 5: Nastran / Ansys exports and shell submodel templates
fprintf('\n============================================================\n');
fprintf('Phase 5 exports: Nastran .bdf + Ansys .mac for cross-verification\n');
fprintf('============================================================\n');

export_dir = '../data/export';
if ~exist(export_dir, 'dir')
    mkdir(export_dir);
end

% Frame LC2 exports
mat_cfrp_with_name = mat.cfrp;   % already has .name field
export_bdf(fullfile(export_dir, 'frame_LC2.bdf'), ...
           frame_nodes, frame_elements, frame_section, mat_cfrp_with_name, ...
           wing_attach_node, F_lc2, 'Archer Midnight Frame, LC2 2g symmetric maneuver');

export_apdl(fullfile(export_dir, 'frame_LC2.mac'), ...
            frame_nodes, frame_elements, frame_section, mat_cfrp_with_name, ...
            wing_attach_node, F_lc2, 'Archer Midnight Frame, LC2 2g symmetric maneuver');

% Shell submodels with embedded LC2/LCG section forces
export_shell_submodels( ...
    fullfile(export_dir, 'joint_shell.mac'), ...
    fullfile(export_dir, 'strut_top_shell.mac'), ...
    frame_section, lg_section, mat, results_lc2, lg_results);

% Placeholder shell-screenshot PNGs
placeholder_dir = '../docs/figures';
make_placeholder_png(fullfile(placeholder_dir, 'joint_shell_screenshot.png'), ...
    'Wing-to-fuselage joint shell submodel', ...
    'Run data/export/joint_shell.mac in Ansys Mechanical APDL, then replace this image with the von Mises contour.');
make_placeholder_png(fullfile(placeholder_dir, 'strut_top_shell_screenshot.png'), ...
    'Landing gear strut top shell submodel', ...
    'Run data/export/strut_top_shell.mac in Ansys Mechanical APDL, then replace this image with the von Mises contour.');
fprintf('Placeholder shell screenshots saved to docs/figures/.\n');

%% Save summary
if ~exist('../data', 'dir')
    mkdir('../data');
end
save('../data/midnight_params.mat', 'params', 'mat', ...
     'frame_summary', 'lg_results', 'sigma_vm_lg', 'RF_lg', ...
     'freq_Hz_constrained', 'resonance_flags', 'drop_results', ...
     'ply_result', 'comp_lamina', 'layup', 'sweep');

% Also dump a flat CSV of the key results so the report regeneration step
% (Section 9 in VSCODE_PROMPT.md) can read structured data instead of scraping
% log lines.
csv_path = '../data/results_summary.csv';
fid = fopen(csv_path, 'w');
fprintf(fid, 'component,load_case,max_vm_MPa,min_RF,max_disp_mm,allowable_MPa\n');
case_names = fieldnames(frame_summary);
for i = 1:numel(case_names)
    s = frame_summary.(case_names{i});
    fprintf(fid, 'frame,%s,%.2f,%.2f,%.2f,%.0f\n', ...
        s.load_case, s.max_vm_MPa, s.min_RF, s.max_disp_mm, mat.cfrp.sigma_all/1e6);
end
fprintf(fid, 'landing_gear,LCG_3g_landing,%.2f,%.2f,%.2f,%.0f\n', ...
    max(sigma_vm_lg)/1e6, min(RF_lg), max_disp_lg*1e3, mat.al7075.sigma_y/1e6);
fclose(fid);
fprintf('Results CSV written to %s\n', csv_path);

fprintf('\n============================================================\n');
fprintf('Done. Figures in docs/figures/, summary in data/midnight_params.mat\n');
fprintf('============================================================\n');
