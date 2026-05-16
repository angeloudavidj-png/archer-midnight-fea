function F = apply_loads(nodes, params, load_case)
% APPLY_LOADS  Build the global force vector for a given load case.
%
%   F = apply_loads(nodes, params, load_case)
%
%   load_case : string, one of
%     'LC1_hover_static'
%     'LC2_2g_maneuver'
%     'LC3_cruise'
%     'LC4_motor_out'
%     'LCG_hard_landing'
%
%   Force convention: Z positive up. Lift and thrust are +Z, weight is -Z.
%
%   David Angelou, U-M ME, 2026.

    N = size(nodes, 1);
    F = zeros(6 * N, 1);

    g = params.g;
    W = params.MTOW_kg * g;
    T_hover = params.hover_thrust_per_rotor_N;

    % Identify motor nodes by their y-coordinate offset from centerline.
    % Per build_frame_geometry, the motor nodes are the 12 boom-line nodes
    % with |y| > 0.5 m.
    motor_idx = find(abs(nodes(:, 2)) > 0.5);

    % Identify central spine nodes (carry the airframe weight)
    spine_idx = find(abs(nodes(:, 2)) < 1e-6);

    % Weight per spine node, distribute MTOW evenly
    W_per_spine = W / numel(spine_idx);

    switch load_case
        case 'LC1_hover_static'
            % 1g hover: each rotor produces T_hover upward, weight downward
            for k = motor_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) + T_hover;
            end
            for k = spine_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) - W_per_spine;
            end

        case 'LC2_2g_maneuver'
            % 2g pull-up: rotors generate 2x hover thrust, weight x2 effective
            nz = params.nz_maneuver;
            for k = motor_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) + nz * T_hover;
            end
            for k = spine_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) - nz * W_per_spine;
            end

        case 'LC3_cruise'
            % Cruise: wing carries total lift, distributed as a span loading.
            % Approximate elliptical lift distribution across the motor nodes.
            y_motors = nodes(motor_idx, 2);
            b = params.boom_half_span_m;
            % Elliptical weighting, normalized so sum = total lift
            w_elliptical = sqrt(1 - (y_motors / b).^2);
            w_elliptical = w_elliptical / sum(w_elliptical);
            L_total = params.cruise_total_lift_N;
            for j = 1:numel(motor_idx)
                k = motor_idx(j);
                F(6*(k-1) + 3) = F(6*(k-1) + 3) + L_total * w_elliptical(j);
            end
            for k = spine_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) - W_per_spine;
            end
            % Add forward thrust on the 6 tilt rotors, x-direction
            % Assume tilt rotors are the outboard 3 motor stations per side
            y_sorted = sort(unique(abs(y_motors)), 'descend');
            tilt_y_threshold = y_sorted(min(3, numel(y_sorted)));
            tilt_idx = motor_idx(abs(y_motors) >= tilt_y_threshold);
            % Cruise drag estimate, D = q * S * Cd, roughly 0.05 * W for eVTOL
            D_total = 0.05 * W;
            T_per_tilt = D_total / numel(tilt_idx);
            for k = tilt_idx'
                F(6*(k-1) + 1) = F(6*(k-1) + 1) + T_per_tilt;
            end

        case 'LC4_motor_out'
            % One outboard rotor fails, others throttle up by 1.5x to compensate
            nz = params.nz_motor_out;
            % Find the outboard-most starboard motor and zero it out
            y_motors = nodes(motor_idx, 2);
            [~, kill_local] = max(y_motors);
            killed_node = motor_idx(kill_local);
            for k = motor_idx'
                if k == killed_node
                    continue
                end
                F(6*(k-1) + 3) = F(6*(k-1) + 3) + nz * T_hover;
            end
            for k = spine_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) - W_per_spine;
            end

        case 'LCG_hard_landing'
            % Used only for the standalone landing gear analysis.
            % For the frame: 3g vertical reaction at the wing attachment.
            nz = params.nz_hard_landing;
            for k = motor_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) + 0;  % rotors off during impact
            end
            for k = spine_idx'
                F(6*(k-1) + 3) = F(6*(k-1) + 3) - nz * W_per_spine;
            end

        otherwise
            error('Unknown load case: %s', load_case);
    end

end
