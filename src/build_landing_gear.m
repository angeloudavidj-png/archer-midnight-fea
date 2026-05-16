function [nodes, elements, contact_nodes] = build_landing_gear(params)
% BUILD_LANDING_GEAR  Generate nodes and beam elements for a tricycle
% landing gear assembly, analyzed independently of the frame.
%
%   Topology, all dimensions in meters:
%     - Nose strut, vertical from attachment to nose wheel contact
%     - Two main struts angled outboard to main wheel contacts
%     - Cross brace between main strut attachments for redundancy
%
%   Returns:
%     nodes         : Nx3 array of [x y z] coordinates
%     elements      : Mx2 array of [n1 n2] node indices
%     contact_nodes : struct with .nose, .main_left, .main_right node indices
%
%   David Angelou, U-M ME, 2026.

    h    = params.lg_height_m;
    wb   = params.lg_wheelbase_m;
    trk  = params.lg_track_m;

    % Attachment points on fuselage belly (z = h, flat in y-z for simplicity)
    % Nose attachment at x = 0, main at x = wb
    A_nose_attach   = [0,        0,      h];
    A_main_attach_L = [wb,      -trk/4,  h];
    A_main_attach_R = [wb,       trk/4,  h];

    % Wheel contact points on ground (z = 0)
    C_nose          = [0,        0,      0];
    C_main_L        = [wb,      -trk/2,  0];
    C_main_R        = [wb,       trk/2,  0];

    nodes = [A_nose_attach;
             A_main_attach_L;
             A_main_attach_R;
             C_nose;
             C_main_L;
             C_main_R];

    % Element connectivity:
    %   1: nose strut (attach -> contact)
    %   2: main strut left
    %   3: main strut right
    %   4: cross brace between main attachments
    elements = [1 4;   % nose strut
                2 5;   % left main strut
                3 6;   % right main strut
                2 3];  % cross brace

    contact_nodes.nose       = 4;
    contact_nodes.main_left  = 5;
    contact_nodes.main_right = 6;

    contact_nodes.attach_nose   = 1;
    contact_nodes.attach_main_L = 2;
    contact_nodes.attach_main_R = 3;

end
