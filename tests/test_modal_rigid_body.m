function test_modal_rigid_body()
% TEST_MODAL_RIGID_BODY  Verify that the unconstrained airframe returns
% exactly 6 modes at zero frequency (3 translation, 3 rotation rigid body
% modes) and that the first elastic mode is well above zero.
%
%   Run: >> test_modal_rigid_body
%
%   David Angelou, U-M ME, 2026.

    fprintf('Test: unconstrained modal analysis returns 6 rigid body modes\n');

    addpath('../src');
    params = aircraft_parameters();
    mat    = material_properties();
    section = tube_section(params.boom_OD_m, params.boom_t_m);

    [nodes, elements] = build_frame_geometry(params);
    K = assemble_global_K(nodes, elements, section, mat.cfrp);
    M = assemble_global_M(nodes, elements, section, mat.cfrp);

    % Unconstrained, full pencil. Request 12 lowest modes so we see both the
    % 6 rigid body modes and the first 6 elastic modes for context.
    [freq_Hz, ~, ~] = modal_analysis(K, M, 12, []);

    fprintf('  First 12 modes (Hz):\n');
    for i = 1:length(freq_Hz)
        fprintf('    Mode %2d: %12.6e\n', i, freq_Hz(i));
    end

    % Rigid body modes should be at numerical zero. The pencil is well
    % scaled (K asymmetry was 1e-9, M is PD), so a 0.01 Hz threshold is
    % roughly 6 orders of magnitude above the largest plausible numerical
    % zero and well below any elastic mode of an airframe this size.
    rigid_threshold_Hz = 0.01;
    n_rigid = sum(freq_Hz < rigid_threshold_Hz);

    fprintf('  Number of modes below %.2f Hz: %d (expect 6)\n', ...
            rigid_threshold_Hz, n_rigid);

    if n_rigid ~= 6
        error('test_modal_rigid_body:wrongCount', ...
              'Expected 6 rigid body modes, got %d', n_rigid);
    end

    first_elastic = freq_Hz(7);
    if first_elastic < 0.5
        error('test_modal_rigid_body:firstElastic', ...
              'First elastic mode below 0.5 Hz (%.4f Hz), unexpected', ...
              first_elastic);
    end

    fprintf('  First elastic mode (mode 7): %.2f Hz\n', first_elastic);
    fprintf('  PASS\n');

end
