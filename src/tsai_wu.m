function [F_index, contributions] = tsai_wu(sigma_material, comp)
% TSAI_WU  Plane-stress Tsai-Wu failure index for a single ply.
%
%   [F_index, contributions] = tsai_wu(sigma_material, comp)
%
%   sigma_material : 3x1 stress vector in ply material axes,
%                    [sigma_11; sigma_22; tau_12] in Pa.
%   comp           : composite material struct (material_composite output).
%
%   Returns the scalar failure index F. Failure when F >= 1.
%
%   F = F1 s1 + F2 s2 + F11 s1^2 + F22 s2^2 + F66 t12^2 + 2 F12 s1 s2
%
%   With the standard Tsai-Wu assumption F12 = -1/2 sqrt(F11 F22), which
%   produces the right failure envelope for most CFRP without requiring a
%   separate biaxial test datapoint.
%
%   David Angelou, U-M ME, 2026.

    s1  = sigma_material(1);
    s2  = sigma_material(2);
    t12 = sigma_material(3);

    F1  = 1/comp.Xt - 1/comp.Xc;
    F2  = 1/comp.Yt - 1/comp.Yc;
    F11 = 1/(comp.Xt * comp.Xc);
    F22 = 1/(comp.Yt * comp.Yc);
    F66 = 1/comp.S^2;
    F12 = -0.5 * sqrt(F11 * F22);

    F_index = F1*s1 + F2*s2 ...
            + F11*s1^2 + F22*s2^2 + F66*t12^2 ...
            + 2*F12*s1*s2;

    contributions.linear            = F1*s1 + F2*s2;
    contributions.fiber_quadratic   = F11*s1^2;
    contributions.matrix_quadratic  = F22*s2^2;
    contributions.shear_quadratic   = F66*t12^2;
    contributions.interaction       = 2*F12*s1*s2;
end
