function [nodes, elements] = build_frame_geometry(params)
% BUILD_FRAME_GEOMETRY  Generate nodal coordinates and beam connectivity
% for a simplified Archer Midnight airframe.
%
%   Topology, all dimensions in meters:
%     - Central fuselage spine along x from nose to tail
%     - Two booms running spanwise along y at fuselage station Y_wing
%     - 12 motor stations attached to the booms (6 tilt + 6 lift)
%     - V-tail booms at aft fuselage
%
%   Returns:
%     nodes    : Nx3 array of [x y z] coordinates
%     elements : Mx2 array of [n1 n2] node indices defining each beam
%
%   David Angelou, U-M ME, 2026.

    nodes = [];
    elements = [];

    % --- Central fuselage spine, 5 nodes from nose (x=0) to tail (x=L)
    L = params.fuselage_len_m;
    n_spine = 5;
    spine_x = linspace(0, L, n_spine);
    spine_z = 1.20 * ones(1, n_spine);
    spine_y = zeros(1, n_spine);
    spine_nodes = (size(nodes,1) + 1) : (size(nodes,1) + n_spine);
    nodes = [nodes; [spine_x', spine_y', spine_z']];

    % Spine beam elements
    for i = 1:n_spine-1
        elements = [elements; spine_nodes(i), spine_nodes(i+1)];
    end

    % --- Wing/boom attachment is at spine node 3 (mid-fuselage)
    wing_node = spine_nodes(3);
    wing_x    = spine_x(3);
    wing_z    = spine_z(3);

    % --- Booms, one per side, each holds 3 tilt rotors + 3 lift rotors
    %     We use a single boom per side with 6 motor stations along it.
    %     The boom runs from inboard root to outboard tip.
    s_root = 0;
    s_tip  = params.boom_half_span_m;
    motor_stations = linspace(s_root + 1.0, s_tip, 6);  % 6 motors per side

    for side = [-1, 1]
        % Root node at wing attachment (re-use wing_node for inboard)
        prev_node = wing_node;
        for k = 1:numel(motor_stations)
            y_k = side * motor_stations(k);
            z_k = wing_z;
            x_k = wing_x;
            nodes = [nodes; [x_k, y_k, z_k]];
            this_node = size(nodes, 1);
            elements = [elements; prev_node, this_node];
            prev_node = this_node;
        end
    end

    % --- Tail boom and V-tail
    tail_node = spine_nodes(end);
    % Two V-tail tip nodes, swept up and out
    vtail_dx = -0.5;  % swept aft, but spine_x already at tail, use small dx
    vtail_dy = 1.50;
    vtail_dz = 1.20;
    nodes = [nodes; spine_x(end) + vtail_dx,  vtail_dy, spine_z(end) + vtail_dz];
    nodes = [nodes; spine_x(end) + vtail_dx, -vtail_dy, spine_z(end) + vtail_dz];
    vtail_right = size(nodes, 1) - 1;
    vtail_left  = size(nodes, 1);
    elements = [elements; tail_node, vtail_right];
    elements = [elements; tail_node, vtail_left];

    % --- Landing gear attachment nodes on fuselage (used by build_landing_gear)
    %     Stored as last two entries by convention: nose gear and main gear.
    %     We do not add LG elements here; build_landing_gear does that.

end
