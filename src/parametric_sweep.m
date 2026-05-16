function results = parametric_sweep(params_base, mat, varargin)
% PARAMETRIC_SWEEP  Grid sweep over boom and landing gear cross sections.
%
%   results = parametric_sweep(params_base, mat)
%   results = parametric_sweep(params_base, mat, 'OptName', value, ...)
%
%   For each combination of (boom_OD, boom_wall, strut_OD, strut_wall) the
%   sweep runs:
%     - LC2 (2g symmetric maneuver) on the frame, computes peak von Mises
%       and reserve factor against the CFRP design allowable.
%     - LCG (3g hard landing + 0.5g forward drag) on the landing gear,
%       computes peak von Mises and reserve factor against the 7075-T6
%       yield.
%   Then records min RF (over the two), structural mass (frame + LG), and
%   a feasibility flag against an RF target (default 1.5).
%
%   Geometry node coordinates are fixed across the sweep; only the tube
%   section (A, Iy, Iz, J) varies. Force vectors are also pre-computed once
%   since they do not depend on cross section.
%
%   Options:
%     'BoomOD_m'   : vector of boom OD values, default 0.200:0.050:0.400 m
%     'BoomT_m'    : vector of boom wall values, default 0.005:0.0025:0.015 m
%     'StrutOD_m'  : vector of strut OD values, default 0.080:0.010:0.140 m
%     'StrutT_m'   : vector of strut wall values, default 0.005:0.001:0.012 m
%     'RFTarget'   : minimum acceptable reserve factor, default 1.5
%
%   Returns a struct with:
%     table   : (n_cases x 13) matrix, columns documented below
%     header  : cell array of column names
%     n_cases : number of combinations evaluated
%     elapsed_s : wallclock seconds for the sweep
%     pareto    : (n_pareto x 13) Pareto-optimal feasible subset
%
%   Column layout of results.table:
%     1  boom_OD_mm        OD of the frame boom, mm
%     2  boom_wall_mm      wall thickness of the boom, mm
%     3  strut_OD_mm       OD of the LG strut, mm
%     4  strut_wall_mm     wall thickness of the strut, mm
%     5  frame_mass_kg     total mass of the frame structure (sum rho*A*L)
%     6  lg_mass_kg        total mass of the LG structure
%     7  total_mass_kg     frame_mass + lg_mass
%     8  frame_RF          min RF over LC2 frame elements
%     9  lg_RF             min RF over LCG strut elements
%    10  min_RF            min of the above two
%    11  frame_VM_MPa      peak frame VM stress, LC2, MPa
%    12  lg_VM_MPa         peak LG VM stress, LCG, MPa
%    13  feasible          1 if min_RF >= rf_target, 0 otherwise
%
%   David Angelou, U-M ME, 2026.

    p = inputParser;
    addParameter(p, 'BoomOD_m',  0.200:0.050:0.400);
    addParameter(p, 'BoomT_m',   0.005:0.0025:0.015);
    addParameter(p, 'StrutOD_m', 0.080:0.010:0.140);
    addParameter(p, 'StrutT_m',  0.005:0.001:0.012);
    addParameter(p, 'RFTarget',  1.5);
    parse(p, varargin{:});

    boom_OD_vals  = p.Results.BoomOD_m;
    boom_t_vals   = p.Results.BoomT_m;
    strut_OD_vals = p.Results.StrutOD_m;
    strut_t_vals  = p.Results.StrutT_m;
    rf_target     = p.Results.RFTarget;

    % Build geometries and force vectors once (cross-section invariant).
    [frame_nodes, frame_elements] = build_frame_geometry(params_base);
    [lg_nodes, lg_elements, contacts] = build_landing_gear(params_base);

    F_lc2 = apply_loads(frame_nodes, params_base, 'LC2_2g_maneuver');

    wing_attach_node = 3;
    bc_frame = { wing_attach_node, 1:6 };

    bc_lg = { contacts.nose,       1:6;
              contacts.main_left,  1:6;
              contacts.main_right, 1:6 };

    nz = params_base.nz_hard_landing;
    W_total = nz * params_base.MTOW_kg * params_base.g;
    F_lg = zeros(6 * size(lg_nodes, 1), 1);
    F_lg(6*(contacts.attach_nose   - 1) + 3) = -0.10 * W_total;
    F_lg(6*(contacts.attach_main_L - 1) + 3) = -0.45 * W_total;
    F_lg(6*(contacts.attach_main_R - 1) + 3) = -0.45 * W_total;
    F_lg(6*(contacts.attach_nose   - 1) + 1) = -0.5 * 0.10 * W_total;
    F_lg(6*(contacts.attach_main_L - 1) + 1) = -0.5 * 0.45 * W_total;
    F_lg(6*(contacts.attach_main_R - 1) + 1) = -0.5 * 0.45 * W_total;

    % Pre-compute element lengths for fast mass evaluation.
    frame_elem_len = zeros(size(frame_elements, 1), 1);
    for e = 1:size(frame_elements, 1)
        frame_elem_len(e) = norm(frame_nodes(frame_elements(e,2),:) ...
                               - frame_nodes(frame_elements(e,1),:));
    end
    L_frame_total = sum(frame_elem_len);

    lg_elem_len = zeros(size(lg_elements, 1), 1);
    for e = 1:size(lg_elements, 1)
        lg_elem_len(e) = norm(lg_nodes(lg_elements(e,2),:) ...
                            - lg_nodes(lg_elements(e,1),:));
    end
    L_lg_total = sum(lg_elem_len);

    sigma_all_cfrp = mat.cfrp.sigma_all;
    sigma_y_al     = mat.al7075.sigma_y;

    n_cases = numel(boom_OD_vals) * numel(boom_t_vals) ...
            * numel(strut_OD_vals) * numel(strut_t_vals);
    fprintf('Parametric sweep: %d combinations to evaluate.\n', n_cases);
    fprintf('  Boom OD  : [%s] mm\n', num2str(boom_OD_vals*1e3, '%g '));
    fprintf('  Boom t   : [%s] mm\n', num2str(boom_t_vals*1e3, '%g '));
    fprintf('  Strut OD : [%s] mm\n', num2str(strut_OD_vals*1e3, '%g '));
    fprintf('  Strut t  : [%s] mm\n', num2str(strut_t_vals*1e3, '%g '));

    table = zeros(n_cases, 13);
    idx = 0;

    tic;
    for i_bo = 1:numel(boom_OD_vals)
        boom_OD = boom_OD_vals(i_bo);
        for i_bt = 1:numel(boom_t_vals)
            boom_t = boom_t_vals(i_bt);
            if 2*boom_t >= boom_OD
                % Skip non-physical (wall too thick for OD).
                continue;
            end
            frame_section = tube_section(boom_OD, boom_t);
            % Frame K depends only on the (constant) boom section, assemble once
            % per outer two loops.
            K_frame_iter = assemble_global_K(frame_nodes, frame_elements, frame_section, mat.cfrp);
            U_frame      = solve_fea(K_frame_iter, F_lc2, bc_frame);
            res_frame    = post_process(frame_nodes, frame_elements, U_frame, frame_section, mat.cfrp);
            sigma_vm_frame_all = arrayfun(@(r) r.sigma_vm_Pa, res_frame);
            frame_VM = max(sigma_vm_frame_all);
            frame_RF = sigma_all_cfrp / max(frame_VM, 1);
            frame_mass = mat.cfrp.rho * frame_section.A * L_frame_total;

            for i_so = 1:numel(strut_OD_vals)
                strut_OD = strut_OD_vals(i_so);
                for i_st = 1:numel(strut_t_vals)
                    strut_t = strut_t_vals(i_st);
                    if 2*strut_t >= strut_OD
                        continue;
                    end
                    lg_section = tube_section(strut_OD, strut_t);

                    K_lg = assemble_global_K(lg_nodes, lg_elements, lg_section, mat.al7075);
                    U_lg = solve_fea(K_lg, F_lg, bc_lg);
                    res_lg = post_process(lg_nodes, lg_elements, U_lg, lg_section, mat.al7075);
                    sigma_vm_lg_all = arrayfun(@(r) r.sigma_vm_Pa, res_lg);
                    lg_VM = max(sigma_vm_lg_all);
                    lg_RF = sigma_y_al / max(lg_VM, 1);
                    lg_mass = mat.al7075.rho * lg_section.A * L_lg_total;

                    min_RF = min(frame_RF, lg_RF);
                    total_mass = frame_mass + lg_mass;
                    feasible = double(min_RF >= rf_target);

                    idx = idx + 1;
                    table(idx, :) = [boom_OD*1e3, boom_t*1e3, strut_OD*1e3, strut_t*1e3, ...
                                     frame_mass, lg_mass, total_mass, ...
                                     frame_RF, lg_RF, min_RF, ...
                                     frame_VM/1e6, lg_VM/1e6, feasible];
                end
            end
        end
    end
    elapsed = toc;

    % Trim if any combinations were skipped for non-physical walls.
    table = table(1:idx, :);

    % Compute Pareto frontier: among feasible designs, find non-dominated
    % set in (mass, -RF) plane (low mass, high RF both desirable).
    feasible_mask = table(:, 13) > 0.5;
    feasible_set = table(feasible_mask, :);

    if ~isempty(feasible_set)
        [~, sort_idx] = sort(feasible_set(:, 7));  % sort by mass ascending
        sorted_feas   = feasible_set(sort_idx, :);
        pareto        = sorted_feas(1, :);
        for i = 2:size(sorted_feas, 1)
            if sorted_feas(i, 10) > pareto(end, 10)   % strictly higher RF than any lower-mass feasible
                pareto(end+1, :) = sorted_feas(i, :); %#ok<AGROW>
            end
        end
    else
        pareto = zeros(0, 13);
    end

    results.header = {'boom_OD_mm', 'boom_wall_mm', 'strut_OD_mm', 'strut_wall_mm', ...
                      'frame_mass_kg', 'lg_mass_kg', 'total_mass_kg', ...
                      'frame_RF', 'lg_RF', 'min_RF', ...
                      'frame_VM_MPa', 'lg_VM_MPa', 'feasible'};
    results.table     = table;
    results.n_cases   = idx;
    results.elapsed_s = elapsed;
    results.pareto    = pareto;
    results.rf_target = rf_target;

    fprintf('Parametric sweep done: %d cases in %.2f s, %d feasible (RF >= %.2f).\n', ...
            idx, elapsed, size(feasible_set, 1), rf_target);
end
