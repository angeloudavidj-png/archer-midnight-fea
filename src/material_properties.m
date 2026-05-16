function mat = material_properties()
% MATERIAL_PROPERTIES  Properties for CFRP frame and 7075-T6 landing gear.
%
%   Returns a struct with two sub-structs:
%       mat.cfrp   Carbon fiber reinforced polymer, quasi-isotropic layup
%       mat.al7075 7075-T6 aluminum
%
%   David Angelou, U-M ME, 2026.

    % Carbon Fiber Reinforced Polymer, quasi-isotropic [0/45/-45/90]_s
    mat.cfrp.name      = 'CFRP quasi-isotropic';
    mat.cfrp.E         = 70e9;     % Pa, in-plane effective modulus
    mat.cfrp.G         = 27e9;     % Pa, in-plane shear modulus estimate
    mat.cfrp.nu        = 0.30;
    mat.cfrp.rho       = 1600;     % kg/m^3
    mat.cfrp.sigma_ult = 600e6;    % Pa, conservative tensile allowable
    mat.cfrp.sigma_all = 350e6;    % Pa, design allowable with knockdown

    % 7075-T6 Aluminum, landing gear strut
    mat.al7075.name      = '7075-T6 Aluminum';
    mat.al7075.E         = 71.7e9;   % Pa
    mat.al7075.G         = 26.9e9;   % Pa
    mat.al7075.nu        = 0.33;
    mat.al7075.rho       = 2810;     % kg/m^3
    mat.al7075.sigma_y   = 503e6;    % Pa, yield
    mat.al7075.sigma_ult = 572e6;    % Pa, ultimate

end
