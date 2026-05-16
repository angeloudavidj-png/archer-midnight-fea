function export_apdl(filename, nodes, elements, section, mat, bc_node, F, title_str)
% EXPORT_APDL  Write an Ansys APDL (.mac) script of the beam model, runnable
% in batch mode (ansysXXX -b -i frame_LC2.mac -o frame_LC2.out) or in the
% Mechanical APDL classic GUI.
%
%   export_apdl(filename, nodes, elements, section, mat, bc_node, F, title)
%
%   Same arguments as export_bdf, but produces an Ansys script.
%
%   Element type: BEAM188 (Timoshenko, quadratic shape functions in the
%   default KEYOPT, equivalent to Euler-Bernoulli for slender tubes).
%   Section: CTUBE built from inner and outer radius.
%   Orientation: a single auxiliary node placed far above the structure is
%   used as the K node for every element. For circular tubes Iy = Iz so the
%   orientation does not affect the stress field; the K node is only needed
%   to satisfy BEAM188's requirement of a defined orientation.
%
%   David Angelou, U-M ME, 2026.

    fid = fopen(filename, 'w');
    if fid < 0
        error('Could not open %s for write', filename);
    end

    fprintf(fid, '! Ansys APDL script, exported from MATLAB beam FEA toolkit\n');
    fprintf(fid, '! Material: %s\n', mat.name);
    fprintf(fid, '! Units: SI (m, N, Pa, kg)\n');
    fprintf(fid, '! Generated for cross-verification of MATLAB beam results.\n');
    fprintf(fid, '! Target agreement: peak VM stress within 10 percent, peak displacement within 5 percent.\n');
    fprintf(fid, '!\n/CLEAR\n');
    fprintf(fid, '/PREP7\n');
    fprintf(fid, '/TITLE,%s\n', title_str);

    fprintf(fid, '\n! Element type: 3D beam, BEAM188\n');
    fprintf(fid, 'ET,1,BEAM188\n');

    Ri = section.ID / 2;
    Ro = section.OD / 2;
    fprintf(fid, '\n! Section: hollow circular tube (CTUBE)\n');
    fprintf(fid, 'SECTYPE,1,BEAM,CTUBE,boom,0\n');
    fprintf(fid, 'SECDATA,%.6f,%.6f\n', Ri, Ro);

    fprintf(fid, '\n! Material card\n');
    fprintf(fid, 'MP,EX,1,%.6E\n', mat.E);
    fprintf(fid, 'MP,PRXY,1,%.4f\n', mat.nu);
    fprintf(fid, 'MP,DENS,1,%.2f\n', mat.rho);

    fprintf(fid, '\n! Nodes (%d total)\n', size(nodes, 1));
    for i = 1:size(nodes, 1)
        fprintf(fid, 'N,%d,%.6f,%.6f,%.6f\n', ...
                i, nodes(i,1), nodes(i,2), nodes(i,3));
    end

    % Auxiliary K node high above the structure for BEAM188 orientation.
    % Since the section is axisymmetric (Iy = Iz), the choice of orientation
    % does not affect stresses or displacements.
    z_aux       = max(nodes(:, 3)) + 100;
    aux_node_id = size(nodes, 1) + 1;
    fprintf(fid, '\n! Auxiliary K node for BEAM188 orientation\n');
    fprintf(fid, 'N,%d,0.0,0.0,%.2f\n', aux_node_id, z_aux);

    fprintf(fid, '\n! Element creation (TYPE, SECNUM, MAT inherited)\n');
    fprintf(fid, 'TYPE,1\n');
    fprintf(fid, 'SECNUM,1\n');
    fprintf(fid, 'MAT,1\n');
    for e = 1:size(elements, 1)
        n1 = elements(e, 1);
        n2 = elements(e, 2);
        fprintf(fid, 'E,%d,%d,%d\n', n1, n2, aux_node_id);
    end

    fprintf(fid, '\n! Boundary condition: fully fix node %d (all 6 DOFs)\n', bc_node);
    fprintf(fid, 'D,%d,ALL,0.0\n', bc_node);

    fprintf(fid, '\n! Applied loads\n');
    labels = {'FX', 'FY', 'FZ', 'MX', 'MY', 'MZ'};
    n_loads = 0;
    for i = 1:length(F)
        if abs(F(i)) > 1e-9
            node_id = floor((i-1)/6) + 1;
            dof     = mod(i-1, 6) + 1;
            fprintf(fid, 'F,%d,%s,%.6E\n', node_id, labels{dof}, F(i));
            n_loads = n_loads + 1;
        end
    end

    fprintf(fid, '\nFINISH\n');
    fprintf(fid, '\n/SOLU\n');
    fprintf(fid, 'ANTYPE,STATIC\n');
    fprintf(fid, 'SOLVE\n');
    fprintf(fid, 'FINISH\n');

    fprintf(fid, '\n/POST1\n');
    fprintf(fid, 'SET,LAST\n');

    fprintf(fid, '\n! Save displacement contour\n');
    fprintf(fid, 'PLNSOL,U,SUM\n');
    fprintf(fid, '/IMAGE,SAVE,frame_LC2_displacement,png\n');

    fprintf(fid, '\n! Save von Mises stress contour\n');
    fprintf(fid, 'PLNSOL,S,EQV\n');
    fprintf(fid, '/IMAGE,SAVE,frame_LC2_vm_stress,png\n');

    fprintf(fid, '\n! Extract peak values for cross-verification table\n');
    fprintf(fid, 'NSORT,S,EQV,0,1\n');
    fprintf(fid, '*GET,VM_MAX,SORT,,MAX\n');
    fprintf(fid, '*GET,U_MAX,NODE,,U,SUM,MAX\n');
    fprintf(fid, '/COM,*****************************************\n');
    fprintf(fid, '/COM,MATLAB FEA reference: VM_max = 175.4 MPa, U_max = 193.81 mm\n');
    fprintf(fid, '/COM,Ansys result        : VM_max = %%VM_MAX:F12.2%% Pa, U_max = %%U_MAX:F12.6%% m\n');
    fprintf(fid, '/COM,*****************************************\n');

    fprintf(fid, 'FINISH\n');
    fclose(fid);

    fprintf('Wrote Ansys APDL to %s (%d nodes, %d elements, %d loads).\n', ...
            filename, size(nodes,1), size(elements,1), n_loads);
end
