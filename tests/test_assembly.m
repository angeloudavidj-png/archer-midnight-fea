function test_assembly()
% TEST_ASSEMBLY  Verify the assembled global stiffness matrix is symmetric
% and has the expected rank deficiency (6 rigid body modes in 3D).
%
%   Run: >> test_assembly
%
%   David Angelou, U-M ME, 2026.

    fprintf('Test: global stiffness symmetry and rank\n');

    addpath('../src');
    params = aircraft_parameters();
    mat    = material_properties();
    section = tube_section(params.boom_OD_m, params.boom_t_m);

    [nodes, elements] = build_frame_geometry(params);
    K = assemble_global_K(nodes, elements, section, mat.cfrp);

    % Symmetry check
    sym_error = full(max(max(abs(K - K'))));
    fprintf('   Max |K - K^T|         = %.2e\n', sym_error);
    if sym_error > 1e-6
        error('Stiffness is not symmetric: max asymmetry %.2e', sym_error);
    end

    % Rank deficiency: an unconstrained 3D frame should have 6 zero eigenvalues
    % Use absolute threshold to separate numerical zeros from real stiffness
    K_full = full(K);
    eigvals = sort(abs(eig(K_full)));
    % There is a large gap between rigid body modes (~1e-9) and the first real
    % mode (~10^2 or higher), use a midpoint threshold of 1e-3 to separate.
    n_zero = sum(eigvals < 1.0);
    fprintf('   Number of near-zero eigenvalues (expect 6) = %d\n', n_zero);
    fprintf('   First non-zero eigenvalue                  = %.2e\n', ...
            eigvals(n_zero + 1));
    if n_zero ~= 6
        error('Unexpected number of rigid body modes: %d (expected 6)', n_zero);
    end

    fprintf('   PASS\n');

end
