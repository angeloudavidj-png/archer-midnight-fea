function test_beam_cantilever()
% TEST_BEAM_CANTILEVER  Verify the 3D beam element against the closed-form
% Euler-Bernoulli cantilever tip deflection delta = P*L^3 / (3*E*I).
%
%   Run: >> test_beam_cantilever
%
%   David Angelou, U-M ME, 2026.

    fprintf('Test: cantilever beam tip deflection vs analytical\n');

    addpath('../src');

    % Geometry: 1 m beam along x with 5 elements
    L_total = 1.0;
    n_elem = 5;
    n_node = n_elem + 1;
    nodes = [linspace(0, L_total, n_node)', zeros(n_node, 1), zeros(n_node, 1)];
    elements = [(1:n_elem)', (2:n_node)'];

    % Section: solid circular, 10 mm radius
    r = 0.010;
    section.OD = 2*r; section.ID = 0;
    section.A  = pi * r^2;
    section.Iy = pi * r^4 / 4;
    section.Iz = section.Iy;
    section.J  = pi * r^4 / 2;

    % Material: steel for clean numbers
    material.E   = 200e9;
    material.G   = 77e9;
    material.nu  = 0.30;

    % Assemble
    K = assemble_global_K(nodes, elements, section, material);

    % BC: node 1 fully fixed
    bc = { 1, 1:6 };

    % Load: tip transverse force in z at node n_node
    P = 1000;  % N
    F = zeros(6 * n_node, 1);
    F(6 * (n_node - 1) + 3) = P;

    U = solve_fea(K, F, bc);

    delta_fea = U(6*(n_node-1) + 3);
    delta_analytical = P * L_total^3 / (3 * material.E * section.Iy);

    rel_error = abs(delta_fea - delta_analytical) / abs(delta_analytical);

    fprintf('   FEA tip deflection        = %.6e m\n', delta_fea);
    fprintf('   Analytical tip deflection = %.6e m\n', delta_analytical);
    fprintf('   Relative error            = %.2e\n', rel_error);

    if rel_error < 1e-6
        fprintf('   PASS\n');
    else
        error('Cantilever test FAILED: relative error %.2e exceeds 1e-6', rel_error);
    end

end
