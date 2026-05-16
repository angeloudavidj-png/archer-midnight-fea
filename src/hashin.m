function [indices, mode] = hashin(sigma_material, comp)
% HASHIN  Plane-stress Hashin 2D failure indices distinguishing fiber and
% matrix failure modes in tension and compression.
%
%   [indices, mode] = hashin(sigma_material, comp)
%
%   sigma_material : 3x1 stress vector in ply material axes,
%                    [sigma_11; sigma_22; tau_12] in Pa.
%   comp           : composite material struct.
%
%   Returns:
%     indices : struct with fields fiber_tension, fiber_compression,
%               matrix_tension, matrix_compression, fiber, matrix.
%               The fiber/matrix summaries take the max of tension and
%               compression (only one will be non-zero based on stress sign).
%     mode    : char string describing the dominant failure mode for this
%               stress state ('fiber_tension', 'fiber_compression',
%               'matrix_tension', 'matrix_compression').
%
%   Hashin 2D forms used:
%     Fiber tension     (s1 >= 0):  (s1/Xt)^2 + (t12/S)^2
%     Fiber compression (s1 < 0):   (s1/Xc)^2
%     Matrix tension    (s2 >= 0):  (s2/Yt)^2 + (t12/S)^2
%     Matrix compression(s2 < 0):   (s2/Yc)^2 + (t12/S)^2
%
%   References: Hashin, "Failure criteria for unidirectional fiber composites",
%   J. Appl. Mech., 47:329-334 (1980).
%
%   David Angelou, U-M ME, 2026.

    s1  = sigma_material(1);
    s2  = sigma_material(2);
    t12 = sigma_material(3);

    if s1 >= 0
        indices.fiber_tension     = (s1/comp.Xt)^2 + (t12/comp.S)^2;
        indices.fiber_compression = 0;
        fiber_mode = 'fiber_tension';
    else
        indices.fiber_tension     = 0;
        indices.fiber_compression = (abs(s1)/comp.Xc)^2;
        fiber_mode = 'fiber_compression';
    end

    if s2 >= 0
        indices.matrix_tension     = (s2/comp.Yt)^2 + (t12/comp.S)^2;
        indices.matrix_compression = 0;
        matrix_mode = 'matrix_tension';
    else
        indices.matrix_tension     = 0;
        indices.matrix_compression = (s2/comp.Yc)^2 + (t12/comp.S)^2;
        matrix_mode = 'matrix_compression';
    end

    indices.fiber  = max(indices.fiber_tension,  indices.fiber_compression);
    indices.matrix = max(indices.matrix_tension, indices.matrix_compression);

    if indices.fiber > indices.matrix
        mode = fiber_mode;
    else
        mode = matrix_mode;
    end
end
