function params = aircraft_parameters()
% AIRCRAFT_PARAMETERS  Return public-domain estimates for Archer Midnight.
%
%   All values are reasonable engineering approximations sourced from
%   Archer's published renderings, FAA Type Certification filings, press
%   releases, and standard eVTOL design heuristics. No proprietary data.
%
%   Returns a struct with fields:
%       MTOW_kg          Maximum takeoff weight
%       g                Gravity (m/s^2)
%       n_motors_tilt    Number of forward tilt rotors
%       n_motors_lift    Number of fixed lift rotors
%       wingspan_m       Tip-to-tip span
%       fuselage_len_m   Nose-to-tail length
%       boom_half_span_m Distance from centerline to outboard motor
%       boom_OD_m        Boom outer diameter
%       boom_t_m         Boom wall thickness
%       lg_OD_m          Landing gear strut outer diameter
%       lg_t_m           Landing gear strut wall thickness
%       lg_track_m       Main gear lateral spacing
%       lg_wheelbase_m   Nose to main gear distance
%       lg_height_m      Ground to attachment height
%       load_factor_*    Limit load factors for each case
%
%   David Angelou, U-M ME, 2026.

    params.MTOW_kg          = 3175;       % ~7,000 lb, Archer published target
    params.g                = 9.81;
    params.n_motors_tilt    = 6;
    params.n_motors_lift    = 6;
    params.wingspan_m       = 15.24;      % ~50 ft estimate
    params.fuselage_len_m   = 12.00;      % ~40 ft cabin + tail
    params.boom_half_span_m = 6.50;       % outboard motor station
    params.boom_inner_m     = 2.20;       % inboard motor station from CL

    % Frame member cross sections, hollow circular CFRP tube.
    % NOTE: In the real Midnight, the wing provides the primary spanwise
    % moment-carrying structure. Since this beam idealization does not include
    % the wing skin and spar caps as separate members, the "boom" section here
    % represents the EQUIVALENT integrated wing+boom moment of inertia at
    % each station. This gives a reasonable cantilever bending response
    % without overcomplicating the model.
    params.boom_OD_m = 0.300;     % 300 mm equivalent OD
    params.boom_t_m  = 0.010;     % 10 mm wall

    % Landing gear, hollow circular 7075-T6 aluminum tube.
    % Phase 0 design iteration: original 60 mm OD with 5 mm wall failed the
    % LCG case (RF 0.27, 1881 MPa peak). Resized to 100 mm OD with 8 mm wall
    % to raise the second moment of area roughly 7x and bring the strut into
    % positive margin. See "Design iteration" subsection of the report.
    params.lg_OD_m       = 0.100;
    params.lg_t_m        = 0.008;
    params.lg_track_m    = 2.40;
    params.lg_wheelbase_m = 3.20;
    params.lg_height_m   = 0.85;

    % Load factors per FAR Part 23 inspired envelope
    params.nz_static       = 1.0;
    params.nz_maneuver     = 2.0;
    params.nz_hard_landing = 3.0;
    params.nz_motor_out    = 1.5;

    % Per-rotor hover thrust trim, total = MTOW * g distributed across all 12
    params.hover_thrust_per_rotor_N = params.MTOW_kg * params.g / ...
        (params.n_motors_tilt + params.n_motors_lift);

    % Cruise wing lift, total = MTOW * g (steady level flight)
    params.cruise_total_lift_N = params.MTOW_kg * params.g;

end
