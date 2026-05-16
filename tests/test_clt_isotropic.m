function test_clt_isotropic()
% TEST_CLT_ISOTROPIC  Verify that a four-ply [0/0/0/0] layup made from an
% isotropic "lamina" (E1 = E2, G12 = E/2(1+nu)) recovers the closed-form
% isotropic in-plane stiffness response: A11 = A22 = E h / (1-nu^2),
% A12 = nu E h / (1-nu^2), A66 = G h, and B = 0.
%
%   Run: >> test_clt_isotropic
%
%   David Angelou, U-M ME, 2026.

    fprintf('Test: CLT of [0/0/0/0] isotropic lamina recovers isotropic ABD\n');

    addpath('../src');

    E  = 100e9;
    nu = 0.30;
    G  = E / (2*(1+nu));

    comp_iso.E1    = E;
    comp_iso.E2    = E;
    comp_iso.G12   = G;
    comp_iso.nu12  = nu;
    comp_iso.t_ply = 0.25e-3;

    layup = composite_layup(comp_iso, [0 0 0 0]);
    h     = layup.h_total;

    A11_expected = E/(1-nu^2) * h;
    A12_expected = nu*E/(1-nu^2) * h;
    A66_expected = G * h;

    err_A11 = abs(layup.A(1,1) - A11_expected) / A11_expected;
    err_A22 = abs(layup.A(2,2) - A11_expected) / A11_expected;
    err_A12 = abs(layup.A(1,2) - A12_expected) / A12_expected;
    err_A66 = abs(layup.A(3,3) - A66_expected) / A66_expected;
    err_B   = max(abs(layup.B(:)));

    fprintf('  A11: %12.4e expected %12.4e (rel err %.2e)\n', ...
            layup.A(1,1), A11_expected, err_A11);
    fprintf('  A22: %12.4e expected %12.4e (rel err %.2e)\n', ...
            layup.A(2,2), A11_expected, err_A22);
    fprintf('  A12: %12.4e expected %12.4e (rel err %.2e)\n', ...
            layup.A(1,2), A12_expected, err_A12);
    fprintf('  A66: %12.4e expected %12.4e (rel err %.2e)\n', ...
            layup.A(3,3), A66_expected, err_A66);
    fprintf('  max|B|: %.2e (expect ~0)\n', err_B);
    fprintf('  Effective E_x: %.2f GPa (expect %.2f GPa)\n', ...
            layup.E_eff_x/1e9, E/1e9);

    tol = 1e-10;
    if err_A11 > tol || err_A22 > tol || err_A12 > tol || err_A66 > tol
        error('test_clt_isotropic:abdMismatch', ...
              'CLT ABD does not recover isotropic response within %.0e.', tol);
    end
    if err_B > 1e-6
        error('test_clt_isotropic:nonzeroB', ...
              'B matrix should be zero, got max %.2e.', err_B);
    end
    if abs(layup.E_eff_x - E)/E > 1e-10
        error('test_clt_isotropic:effectiveE', ...
              'Effective E_x mismatch: %.4e vs %.4e.', layup.E_eff_x, E);
    end

    fprintf('  PASS\n');
end
