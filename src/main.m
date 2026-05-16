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

%% Save summary
if ~exist('../data', 'dir')
    mkdir('../data');
end
save('../data/midnight_params.mat', 'params', 'mat', ...
     'frame_summary', 'lg_results', 'sigma_vm_lg', 'RF_lg');

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
