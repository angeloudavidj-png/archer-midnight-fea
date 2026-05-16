function export_bdf(filename, nodes, elements, section, mat, bc_node, F, title_str)
% EXPORT_BDF  Write a Nastran linear-static bulk data file (.bdf) of the
% beam model, suitable for cross-verifying the MATLAB FEA results in any
% MSC Nastran, NX Nastran, or compatible solver.
%
%   export_bdf(filename, nodes, elements, section, mat, bc_node, F, title)
%
%   Inputs:
%     filename : output .bdf path
%     nodes    : (N x 3) nodal coordinates in meters
%     elements : (M x 2) element connectivity (1-based node ids)
%     section  : tube_section struct with fields OD, ID, A, Iy, Iz, J
%     mat      : material struct with fields E (Pa), nu, rho (kg/m^3), name
%     bc_node  : id of node fully fixed (123456) for the static case
%     F        : (6N x 1) force vector. Entries in DOF order
%                [Fx Fy Fz Mx My Mz] per node.
%     title    : SUBCASE title string
%
%   Format: SI units (m, N, Pa, kg). Free-field Nastran bulk data.
%
%   Card map:
%     SOL 101       linear static
%     MAT1          isotropic material
%     PBARL TUBE    hollow circular section (uses OD, ID)
%     GRID          one per node
%     CBAR          one per element, with orientation vector
%     SPC           single node, all 6 DOFs fixed
%     FORCE/MOMENT  one per non-zero F vector entry
%
%   David Angelou, U-M ME, 2026.

    fid = fopen(filename, 'w');
    if fid < 0
        error('Could not open %s for write', filename);
    end

    fprintf(fid, '$ Nastran bulk data, exported from MATLAB beam FEA toolkit\n');
    fprintf(fid, '$ Material: %s\n', mat.name);
    fprintf(fid, '$ Units: SI (m, N, Pa, kg)\n');
    fprintf(fid, '$ Generated for cross-verification of MATLAB beam results.\n');
    fprintf(fid, '$ Target agreement: peak VM stress within 10 percent, peak displacement within 5 percent.\n');
    fprintf(fid, 'SOL 101\n');
    fprintf(fid, 'CEND\n');
    fprintf(fid, 'TITLE = %s\n', title_str);
    fprintf(fid, 'SUBCASE 1\n');
    fprintf(fid, '  LOAD = 1\n');
    fprintf(fid, '  SPC  = 1\n');
    fprintf(fid, '  DISPLACEMENT(SORT1,REAL) = ALL\n');
    fprintf(fid, '  STRESS(SORT1,REAL) = ALL\n');
    fprintf(fid, '  FORCE(SORT1,REAL) = ALL\n');
    fprintf(fid, '  SPCFORCES(SORT1,REAL) = ALL\n');
    fprintf(fid, 'BEGIN BULK\n');
    fprintf(fid, '$\n$ Material card\n');
    fprintf(fid, 'MAT1,1,%.6E,,%.4f,%.2f\n', mat.E, mat.nu, mat.rho);

    fprintf(fid, '$\n$ Property: hollow circular tube\n');
    fprintf(fid, 'PBARL,1,1,,TUBE\n');
    fprintf(fid, ',%.6f,%.6f\n', section.OD, section.ID);

    fprintf(fid, '$\n$ Grid points (%d nodes)\n', size(nodes, 1));
    for i = 1:size(nodes, 1)
        fprintf(fid, 'GRID,%d,,%.6f,%.6f,%.6f\n', ...
                i, nodes(i,1), nodes(i,2), nodes(i,3));
    end

    fprintf(fid, '$\n$ Beam elements with orientation vectors (%d elements)\n', size(elements, 1));
    for e = 1:size(elements, 1)
        n1 = elements(e, 1);
        n2 = elements(e, 2);
        L_vec = nodes(n2,:) - nodes(n1,:);
        L     = norm(L_vec);
        ex    = L_vec / L;
        if abs(ex(3)) < 0.999
            v = [0 0 1];
        else
            v = [0 1 0];
        end
        fprintf(fid, 'CBAR,%d,1,%d,%d,%.4f,%.4f,%.4f\n', ...
                e, n1, n2, v(1), v(2), v(3));
    end

    fprintf(fid, '$\n$ Boundary condition: node %d fully fixed\n', bc_node);
    fprintf(fid, 'SPC,1,%d,123456,0.0\n', bc_node);

    fprintf(fid, '$\n$ Applied loads\n');
    n_loads = 0;
    for i = 1:length(F)
        if abs(F(i)) > 1e-9
            node_id = floor((i-1)/6) + 1;
            dof     = mod(i-1, 6) + 1;
            if dof <= 3
                dir = zeros(1, 3); dir(dof) = 1;
                fprintf(fid, 'FORCE,1,%d,0,%.6E,%g,%g,%g\n', ...
                        node_id, F(i), dir(1), dir(2), dir(3));
            else
                dir = zeros(1, 3); dir(dof - 3) = 1;
                fprintf(fid, 'MOMENT,1,%d,0,%.6E,%g,%g,%g\n', ...
                        node_id, F(i), dir(1), dir(2), dir(3));
            end
            n_loads = n_loads + 1;
        end
    end

    fprintf(fid, 'ENDDATA\n');
    fclose(fid);

    fprintf('Wrote Nastran .bdf to %s (%d nodes, %d elements, %d loads).\n', ...
            filename, size(nodes,1), size(elements,1), n_loads);
end
