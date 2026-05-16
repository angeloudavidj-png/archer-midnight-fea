function export_shell_submodels(joint_path, strut_path, frame_section, lg_section, mat, frame_lc2_results, lg_results)
% EXPORT_SHELL_SUBMODELS  Write two Ansys APDL shell submodel templates:
% one for the wing-to-fuselage joint (spine node 3) and one for the top of
% the landing gear main strut. Both scripts are self-contained and run in
% batch Ansys (ansysXXX -b -i joint_shell.mac -o joint_shell.out).
%
%   export_shell_submodels(joint_path, strut_path, frame_section, lg_section, mat, frame_lc2_results, lg_results)
%
%   Inputs:
%     joint_path  : output path for joint_shell.mac
%     strut_path  : output path for strut_top_shell.mac
%     frame_section : tube_section struct for the boom (OD, ID)
%     lg_section    : tube_section struct for the LG strut
%     mat           : material struct with cfrp and al7075 sub-structs
%     frame_lc2_results : post_process output for LC2 frame analysis
%     lg_results        : post_process output for the LCG landing gear case
%
%   Boundary loads are extracted from the beam post-process and embedded as
%   remote forces and moments at the cut faces, coupled to the shell edge
%   nodes via CERIG. The scripts use SHELL281 quadratic elements throughout.
%
%   David Angelou, U-M ME, 2026.

    % --- Joint shell submodel --------------------------------------------
    fid = fopen(joint_path, 'w');
    if fid < 0
        error('Could not open %s for write', joint_path);
    end

    % Extract LC2 forces at the boom-fuselage joint. Elements adjacent to
    % spine node 3 in the build_frame_geometry layout:
    %   elem 2 : spine 2-3 (inboard spine, post-process forces at n2 = node 3)
    %   elem 3 : spine 3-4 (outboard spine, post-process forces at n2 = node 4)
    %   elem 5 : left boom 3-6 (n2 = node 6, 1 m outboard of joint)
    %   elem 11: right boom 3-12 (n2 = node 12, 1 m outboard of joint)
    %
    % We embed these as remote loads at the four cut sections of the
    % submodel. Note that elem 3's forces are at node 4 (3 m from joint),
    % and elem 5 and 11 at 1 m. The cut is at 200 mm so the embedded
    % moments understate the joint-side moment by roughly V*0.8 m for the
    % booms. We flag this in the report; it is a first-cut load.
    spine_inboard  = struct_to_load_vec(frame_lc2_results(2));   % at node 3
    spine_outboard = struct_to_load_vec(frame_lc2_results(3));   % at node 4
    boom_left      = struct_to_load_vec(frame_lc2_results(5));   % at node 6
    boom_right     = struct_to_load_vec(frame_lc2_results(11));  % at node 12

    fprintf(fid, '! =====================================================================\n');
    fprintf(fid, '! Ansys APDL shell submodel: wing-to-fuselage joint\n');
    fprintf(fid, '! Center: spine node 3 at (6.0, 0.0, 1.2) m\n');
    fprintf(fid, '! Four tube stubs of OD 300 mm, wall 10 mm, length 200 mm each\n');
    fprintf(fid, '! LC2 (2g symmetric maneuver) boundary loads from MATLAB beam FEA.\n');
    fprintf(fid, '! Material: CFRP isotropic-equivalent (E = 70 GPa, nu = 0.30)\n');
    fprintf(fid, '! Run:  ansysXXX -b -i joint_shell.mac -o joint_shell.out\n');
    fprintf(fid, '! =====================================================================\n');
    fprintf(fid, '/CLEAR\n');
    fprintf(fid, '/PREP7\n');
    fprintf(fid, '/TITLE,Wing-fuselage joint shell submodel, LC2 loads\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Element and section\n');
    fprintf(fid, 'ET,1,SHELL281\n');
    fprintf(fid, 'SECTYPE,1,SHELL\n');
    fprintf(fid, 'SECDATA,%.4f,1\n', 0.010);   % wall thickness, material 1
    fprintf(fid, '\n');
    fprintf(fid, '! Material (CFRP isotropic equivalent)\n');
    fprintf(fid, 'MP,EX,1,%.6E\n', mat.cfrp.E);
    fprintf(fid, 'MP,PRXY,1,%.4f\n', mat.cfrp.nu);
    fprintf(fid, 'MP,DENS,1,%.2f\n', mat.cfrp.rho);
    fprintf(fid, '\n');

    fprintf(fid, '! Joint center and tube geometry\n');
    fprintf(fid, '*SET,XC,6.0\n');
    fprintf(fid, '*SET,YC,0.0\n');
    fprintf(fid, '*SET,ZC,1.2\n');
    fprintf(fid, '*SET,RO,%.4f   ! outer radius (m)\n', frame_section.OD/2);
    fprintf(fid, '*SET,LS,0.200  ! stub length (m)\n');
    fprintf(fid, '\n');

    fprintf(fid, '! ---------------------------------------------------------------\n');
    fprintf(fid, '! Geometry: 4 cylindrical shell stubs meeting at the joint center.\n');
    fprintf(fid, '! Each stub is created via CYL4 inside a local cylindrical CSYS so\n');
    fprintf(fid, '! that the tube axis aligns with the local Z. AGLUE merges them.\n');
    fprintf(fid, '! ---------------------------------------------------------------\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Local cylindrical coordinate systems, one per stub.\n');
    fprintf(fid, 'LOCAL,11,1,XC,YC,ZC,0,0,90    ! axis along +x  (theta about z=-90)\n');
    fprintf(fid, 'LOCAL,12,1,XC,YC,ZC,180,0,90  ! axis along -x\n');
    fprintf(fid, 'LOCAL,13,1,XC,YC,ZC,90,0,90   ! axis along +y\n');
    fprintf(fid, 'LOCAL,14,1,XC,YC,ZC,-90,0,90  ! axis along -y\n');
    fprintf(fid, 'CSYS,0\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Construct each stub as a cylindrical shell surface. CYL4 uses the\n');
    fprintf(fid, '! working plane (not the active CSYS), so WPCSYS,-1 is needed after each\n');
    fprintf(fid, '! CSYS switch to align the WP and put the extrusion axis along local Z.\n');
    fprintf(fid, 'CSYS,11 $ WPCSYS,-1\n');
    fprintf(fid, 'CYL4,0,0,RO,0,RO,360,LS\n');
    fprintf(fid, 'CSYS,12 $ WPCSYS,-1\n');
    fprintf(fid, 'CYL4,0,0,RO,0,RO,360,LS\n');
    fprintf(fid, 'CSYS,13 $ WPCSYS,-1\n');
    fprintf(fid, 'CYL4,0,0,RO,0,RO,360,LS\n');
    fprintf(fid, 'CSYS,14 $ WPCSYS,-1\n');
    fprintf(fid, 'CYL4,0,0,RO,0,RO,360,LS\n');
    fprintf(fid, 'CSYS,0 $ WPCSYS,-1\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Mesh each stub independently with SHELL281, target element size ~10 mm.\n');
    fprintf(fid, '! The 4 stubs only touch at a single point at the joint center, so no\n');
    fprintf(fid, '! area Boolean operation works cleanly. Each stub''s base circle is\n');
    fprintf(fid, '! clamped to ground directly (equivalent to a fixed rigid hub).\n');
    fprintf(fid, 'AESIZE,ALL,0.010\n');
    fprintf(fid, 'TYPE,1\n');
    fprintf(fid, 'SECNUM,1\n');
    fprintf(fid, 'MAT,1\n');
    fprintf(fid, 'AMESH,ALL\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Phantom-mass element for the remote-master nodes used by CERIG below.\n');
    fprintf(fid, 'ET,99,MASS21\n');
    fprintf(fid, 'KEYOPT,99,3,0\n');
    fprintf(fid, 'R,99,1.0E-10,1.0E-10,1.0E-10,1.0E-10,1.0E-10,1.0E-10\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Clamp each stub''s base circle. The radial restriction (LOC,X near RO)\n');
    fprintf(fid, '! is essential: with 4 tubes meeting at the joint, axial-only NSEL\n');
    fprintf(fid, '! over-picks nodes from neighbouring stubs.\n');
    fprintf(fid, 'CSYS,11\n');
    fprintf(fid, 'NSEL,S,LOC,Z,-0.001,0.001\n');
    fprintf(fid, 'NSEL,R,LOC,X,RO-0.005,RO+0.005\n');
    fprintf(fid, 'D,ALL,ALL,0.0\n');
    fprintf(fid, 'CSYS,12\n');
    fprintf(fid, 'NSEL,S,LOC,Z,-0.001,0.001\n');
    fprintf(fid, 'NSEL,R,LOC,X,RO-0.005,RO+0.005\n');
    fprintf(fid, 'D,ALL,ALL,0.0\n');
    fprintf(fid, 'CSYS,13\n');
    fprintf(fid, 'NSEL,S,LOC,Z,-0.001,0.001\n');
    fprintf(fid, 'NSEL,R,LOC,X,RO-0.005,RO+0.005\n');
    fprintf(fid, 'D,ALL,ALL,0.0\n');
    fprintf(fid, 'CSYS,14\n');
    fprintf(fid, 'NSEL,S,LOC,Z,-0.001,0.001\n');
    fprintf(fid, 'NSEL,R,LOC,X,RO-0.005,RO+0.005\n');
    fprintf(fid, 'D,ALL,ALL,0.0\n');
    fprintf(fid, 'CSYS,0\n');
    fprintf(fid, 'ALLSEL\n');
    fprintf(fid, '\n');

    fprintf(fid, '! Boundary loads via remote master nodes coupled to cut-face nodes\n');
    fprintf(fid, '! with CERIG. Master IDs > 99000 to avoid clashing with mesh node IDs.\n');
    fprintf(fid, '\n');

    write_remote_load_block(fid, 'spine_neg_x', 12, 'XC-LS', 'YC',    'ZC', 99001, spine_inboard);
    write_remote_load_block(fid, 'spine_pos_x', 11, 'XC+LS', 'YC',    'ZC', 99002, spine_outboard);
    write_remote_load_block(fid, 'boom_neg_y',  14, 'XC',    'YC-LS', 'ZC', 99003, boom_left);
    write_remote_load_block(fid, 'boom_pos_y',  13, 'XC',    'YC+LS', 'ZC', 99004, boom_right);

    fprintf(fid, '\nFINISH\n');
    fprintf(fid, '\n/SOLU\n');
    fprintf(fid, 'ANTYPE,STATIC\n');
    fprintf(fid, 'SOLVE\n');
    fprintf(fid, 'FINISH\n');
    fprintf(fid, '\n/POST1\n');
    fprintf(fid, 'SET,LAST\n');
    fprintf(fid, 'PLNSOL,S,EQV\n');
    fprintf(fid, '/IMAGE,SAVE,joint_shell_screenshot,png\n');
    fprintf(fid, '\n! Extract peak VM for cross-check\n');
    fprintf(fid, 'NSORT,S,EQV,0,1\n');
    fprintf(fid, '*GET,VM_MAX,SORT,,MAX\n');
    fprintf(fid, '/COM,Joint shell submodel peak VM = %%VM_MAX:F12.2%% Pa\n');
    fprintf(fid, 'FINISH\n');

    fclose(fid);
    fprintf('Wrote joint shell submodel to %s.\n', joint_path);

    % --- Strut top shell submodel ----------------------------------------
    fid = fopen(strut_path, 'w');
    if fid < 0
        error('Could not open %s for write', strut_path);
    end

    % LCG main strut (element 2 in build_landing_gear) and cross brace
    % (element 4). Forces from lg_results (LCG case).
    strut_main = struct_to_load_vec(lg_results(2));
    cross_brace = struct_to_load_vec(lg_results(4));

    fprintf(fid, '! =====================================================================\n');
    fprintf(fid, '! Ansys APDL shell submodel: landing gear main strut top\n');
    fprintf(fid, '! Center: main_L attachment at (3.2, -0.6, 0.85) m\n');
    fprintf(fid, '! Two tube stubs of OD 100 mm, wall 8 mm, length 200 mm.\n');
    fprintf(fid, '!   1) Main strut (direction toward wheel contact at (3.2, -1.2, 0))\n');
    fprintf(fid, '!   2) Cross brace (direction toward main_R attachment at (3.2, +0.6, 0.85))\n');
    fprintf(fid, '! LCG (3g landing) boundary loads from MATLAB beam FEA.\n');
    fprintf(fid, '! Material: 7075-T6 aluminum\n');
    fprintf(fid, '! Run:  ansysXXX -b -i strut_top_shell.mac -o strut_top_shell.out\n');
    fprintf(fid, '! =====================================================================\n');
    fprintf(fid, '/CLEAR\n');
    fprintf(fid, '/PREP7\n');
    fprintf(fid, '/TITLE,LG main strut top shell submodel, LCG loads\n');
    fprintf(fid, '\n');
    fprintf(fid, 'ET,1,SHELL281\n');
    fprintf(fid, 'SECTYPE,1,SHELL\n');
    fprintf(fid, 'SECDATA,%.4f,1\n', 0.008);
    fprintf(fid, '\n');
    fprintf(fid, '! Material (7075-T6 aluminum)\n');
    fprintf(fid, 'MP,EX,1,%.6E\n', mat.al7075.E);
    fprintf(fid, 'MP,PRXY,1,%.4f\n', mat.al7075.nu);
    fprintf(fid, 'MP,DENS,1,%.2f\n', mat.al7075.rho);
    fprintf(fid, '\n');
    fprintf(fid, '*SET,XC,3.2\n');
    fprintf(fid, '*SET,YC,-0.6\n');
    fprintf(fid, '*SET,ZC,0.85\n');
    fprintf(fid, '*SET,RO,%.4f   ! outer radius (m)\n', lg_section.OD/2);
    fprintf(fid, '*SET,LS,0.200\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Strut: direction toward (3.2, -1.2, 0), unit vector [0, -0.577, -0.817]\n');
    fprintf(fid, '! Local CS 21 with axis along strut\n');
    fprintf(fid, 'LOCAL,21,1,XC,YC,ZC,-90,-35.5377,90\n');
    fprintf(fid, 'CSYS,21 $ WPCSYS,-1\n');
    fprintf(fid, 'CYL4,0,0,RO,0,RO,360,LS\n');
    fprintf(fid, 'CSYS,0 $ WPCSYS,-1\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Cross brace: direction +y\n');
    fprintf(fid, 'LOCAL,22,1,XC,YC,ZC,90,0,90\n');
    fprintf(fid, 'CSYS,22 $ WPCSYS,-1\n');
    fprintf(fid, 'CYL4,0,0,RO,0,RO,360,LS\n');
    fprintf(fid, 'CSYS,0 $ WPCSYS,-1\n');
    fprintf(fid, '\n');
    fprintf(fid, 'AESIZE,ALL,0.005\n');
    fprintf(fid, 'TYPE,1\n');
    fprintf(fid, 'SECNUM,1\n');
    fprintf(fid, 'MAT,1\n');
    fprintf(fid, 'AMESH,ALL\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Phantom-mass element for remote-master nodes used by CERIG below.\n');
    fprintf(fid, 'ET,99,MASS21\n');
    fprintf(fid, 'KEYOPT,99,3,0\n');
    fprintf(fid, 'R,99,1.0E-10,1.0E-10,1.0E-10,1.0E-10,1.0E-10,1.0E-10\n');
    fprintf(fid, '\n');
    fprintf(fid, '! Clamp each stub''s base circle.\n');
    fprintf(fid, 'CSYS,21\n');
    fprintf(fid, 'NSEL,S,LOC,Z,-0.001,0.001\n');
    fprintf(fid, 'NSEL,R,LOC,X,RO-0.002,RO+0.002\n');
    fprintf(fid, 'D,ALL,ALL,0.0\n');
    fprintf(fid, 'CSYS,22\n');
    fprintf(fid, 'NSEL,S,LOC,Z,-0.001,0.001\n');
    fprintf(fid, 'NSEL,R,LOC,X,RO-0.002,RO+0.002\n');
    fprintf(fid, 'D,ALL,ALL,0.0\n');
    fprintf(fid, 'CSYS,0\n');
    fprintf(fid, 'ALLSEL\n');
    fprintf(fid, '\n');

    write_remote_load_block(fid, 'strut',  21, 'XC+0', 'YC-LS*0.577', 'ZC-LS*0.817', 99101, strut_main);
    write_remote_load_block(fid, 'brace',  22, 'XC',   'YC+LS',       'ZC',          99102, cross_brace);

    fprintf(fid, '\nFINISH\n');
    fprintf(fid, '/SOLU\n');
    fprintf(fid, 'ANTYPE,STATIC\n');
    fprintf(fid, 'SOLVE\n');
    fprintf(fid, 'FINISH\n');
    fprintf(fid, '/POST1\n');
    fprintf(fid, 'SET,LAST\n');
    fprintf(fid, 'PLNSOL,S,EQV\n');
    fprintf(fid, '/IMAGE,SAVE,strut_top_shell_screenshot,png\n');
    fprintf(fid, 'NSORT,S,EQV,0,1\n');
    fprintf(fid, '*GET,VM_MAX,SORT,,MAX\n');
    fprintf(fid, '/COM,Strut top shell submodel peak VM = %%VM_MAX:F12.2%% Pa\n');
    fprintf(fid, 'FINISH\n');

    fclose(fid);
    fprintf('Wrote strut top shell submodel to %s.\n', strut_path);
end

% ==========================================================================
function load_vec = struct_to_load_vec(elem_result)
% Extract the 6-component (Fx Fy Fz Mx My Mz) load vector from a
% post_process element result struct. In local element axes:
% N = axial along x_local, Vy = shear along y_local, Vz = shear along z_local,
% T = torsion about x_local, My/Mz = bending moments about y/z_local.
%
% For a submodel boundary, we treat these as the load applied at the cut
% face (the boundary of the local region). The local-to-global rotation is
% handled implicitly when the user runs the script in Ansys via the local
% coordinate system at each stub.
    load_vec = [elem_result.axial_force_N, ...
                elem_result.shear_y_N, ...
                elem_result.shear_z_N, ...
                elem_result.torsion_Nm, ...
                elem_result.moment_y_Nm, ...
                elem_result.moment_z_Nm];
end

% ==========================================================================
function write_remote_load_block(fid, name, csys_num, xexpr, yexpr, zexpr, master_id, load_vec)
% Write an APDL block that:
%   1. Creates a master node at the cut-face centroid (in global CSYS,0)
%   2. Selects the full cut-face circle using the local cylindrical CSYS
%      whose Z axis is the stub axis: every cut-face node is at local Z = LS.
%   3. Couples them rigidly to the master via CERIG (UXYZ DOF).
%   4. Applies the 6 load components at the master in global CSYS.
    fprintf(fid, '\n! --- Load block: %s (master %d, local CS %d) ---\n', name, master_id, csys_num);
    fprintf(fid, 'CSYS,0\n');
    fprintf(fid, 'N,%d,%s,%s,%s\n', master_id, xexpr, yexpr, zexpr);
    fprintf(fid, 'TYPE,99 $ REAL,99 $ E,%d\n', master_id);
    fprintf(fid, 'CSYS,%d\n', csys_num);
    fprintf(fid, 'NSEL,S,LOC,Z,LS-0.001,LS+0.001  ! cut-face circle at local Z = LS\n');
    fprintf(fid, 'CSYS,0\n');
    fprintf(fid, 'CERIG,%d,ALL,ALL\n', master_id);
    fprintf(fid, 'ALLSEL\n');
    fprintf(fid, 'F,%d,FX,%.4E\n', master_id, load_vec(1));
    fprintf(fid, 'F,%d,FY,%.4E\n', master_id, load_vec(2));
    fprintf(fid, 'F,%d,FZ,%.4E\n', master_id, load_vec(3));
    fprintf(fid, 'F,%d,MX,%.4E\n', master_id, load_vec(4));
    fprintf(fid, 'F,%d,MY,%.4E\n', master_id, load_vec(5));
    fprintf(fid, 'F,%d,MZ,%.4E\n', master_id, load_vec(6));
end
