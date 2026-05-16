function sec = tube_section(OD, t)
% TUBE_SECTION  Section properties of a thin-walled hollow circular tube.
%
%   sec = tube_section(OD, t)
%
%   OD : outer diameter (m)
%   t  : wall thickness (m)
%
%   Returns struct with OD, ID, A, Iy, Iz, J.
%
%   David Angelou, U-M ME, 2026.

    ID = OD - 2*t;
    sec.OD = OD;
    sec.ID = ID;
    sec.A  = pi/4 * (OD^2 - ID^2);
    sec.Iy = pi/64 * (OD^4 - ID^4);
    sec.Iz = sec.Iy;
    sec.J  = pi/32 * (OD^4 - ID^4);

end
