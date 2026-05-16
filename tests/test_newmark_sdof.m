function test_newmark_sdof()
% TEST_NEWMARK_SDOF  Verify the Newmark integrator against the analytical
% free-decay solution of an underdamped single-DOF spring-mass-damper.
%
%   Run: >> test_newmark_sdof
%
%   System: m ddu + c du + k u = 0,  u(0) = 1, du(0) = 0
%   Analytical for zeta < 1:
%       u(t) = exp(-zeta omega_n t) [cos(omega_d t) + (zeta omega_n / omega_d) sin(omega_d t)]
%
%   David Angelou, U-M ME, 2026.

    fprintf('Test: Newmark integrator vs SDOF analytical free decay\n');

    addpath('../src');

    m    = 1.0;     % kg
    k    = 100.0;   % N/m
    zeta = 0.02;    % 2% damping
    c    = 2 * zeta * sqrt(k*m);

    omega_n = sqrt(k/m);
    omega_d = omega_n * sqrt(1 - zeta^2);

    M = sparse(m);
    C = sparse(c);
    K = sparse(k);

    U0 = 1.0;
    V0 = 0.0;
    A0 = -(k*U0 + c*V0) / m;

    dt      = 1e-3;
    t_end   = 2.0;
    n_steps = round(t_end / dt);

    F_zero = @(t, U) 0;

    [U_hist, ~, ~, t_hist] = newmark_integrator(M, C, K, U0, V0, A0, dt, n_steps, F_zero);

    U_analytical = exp(-zeta*omega_n*t_hist) .* ...
        (cos(omega_d*t_hist) + (zeta*omega_n/omega_d)*sin(omega_d*t_hist));

    abs_err = max(abs(U_hist - U_analytical));
    rel_err = abs_err / max(abs(U_analytical));

    fprintf('  Parameters: m = %.2f, k = %.2f, zeta = %.3f\n', m, k, zeta);
    fprintf('  omega_n = %.4f rad/s, omega_d = %.4f rad/s\n', omega_n, omega_d);
    fprintf('  Integrated %d steps at dt = %.0e s, t_end = %.2f s\n', n_steps, dt, t_end);
    fprintf('  Max absolute error: %.4e\n', abs_err);
    fprintf('  Max relative error: %.4e\n', rel_err);

    % Average-acceleration Newmark is 2nd-order accurate. With dt = 1e-3 and
    % omega_n = 10 rad/s, omega_n*dt = 0.01, so error scales as ~(omega dt)^2
    % per period times number of periods. Setting a generous 1e-3 bound.
    if rel_err > 1e-3
        error('test_newmark_sdof:lowAccuracy', ...
              'Newmark SDOF rel err %.4e exceeds 1e-3.', rel_err);
    end
    fprintf('  PASS\n');
end
