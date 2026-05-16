function comp = material_composite()
% MATERIAL_COMPOSITE  IM7/8552 unidirectional CFRP lamina properties.
%
%   Returns a struct with per-ply elastic constants, strength allowables,
%   and a default ply thickness for use with composite_layup.m and the
%   ply-failure routines.
%
%   Reference values:
%     - Hexcel Composites, "HexPly 8552 Product Data" (matrix-system datasheet)
%     - CMH-17 Volume 2 Revision G, Chapter 4 IM7/8552 statistical allowables
%     - Camanho & Davila, "A damage model for the simulation of delamination
%       in advanced composites", NASA/TM-2002-211737 (table 1)
%
%   The numbers below are room-temperature, dry, mean-property values for
%   IM7/8552 unidirectional tape with nominal 60% fiber volume fraction.
%   They are widely used in published CFRP failure benchmarks.
%
%   David Angelou, U-M ME, 2026.

    comp.name = 'IM7/8552 unidirectional CFRP';

    % Lamina elastic constants (in material axes 1 = fiber, 2 = transverse).
    comp.E1   = 161e9;     % Pa, longitudinal modulus
    comp.E2   = 11.4e9;    % Pa, transverse modulus
    comp.G12  = 5.17e9;    % Pa, in-plane shear modulus
    comp.nu12 = 0.32;      % major Poisson ratio
    comp.rho  = 1580;      % kg/m^3 (cured laminate density)

    % Strength allowables (Pa). Tension and compression differ markedly.
    comp.Xt = 2850e6;      % longitudinal tensile strength
    comp.Xc = 1590e6;      % longitudinal compressive strength
    comp.Yt = 73e6;        % transverse tensile strength
    comp.Yc = 286e6;       % transverse compressive strength
    comp.S  = 73e6;        % in-plane shear strength

    % Default per-ply thickness (m). Industry standard prepreg is 0.125 mm.
    comp.t_ply = 0.125e-3;
end
