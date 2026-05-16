function [U_hist, V_hist, A_hist, t_hist] = newmark_integrator( ...
        M, C, K, U0, V0, A0, dt, n_steps, F_func)
% NEWMARK_INTEGRATOR  Newmark beta time integration of linear structural
% dynamics with a possibly nonlinear external force.
%
%   [U_hist, V_hist, A_hist, t_hist] = newmark_integrator( ...
%       M, C, K, U0, V0, A0, dt, n_steps, F_func)
%
%   Solves  M ddU + C dU + K U = F(t, U)
%   using beta = 0.25, gamma = 0.5 (average-acceleration / constant-average
%   acceleration scheme: unconditionally stable for linear systems, no
%   numerical damping). The (M, C, K) operators are linear and constant;
%   F_func is a function handle F = F_func(t, U) that lets the caller plug
%   in nonlinear forces such as penalty contact.
%
%   Inputs:
%     M, C, K  : (n_dof x n_dof) sparse or dense system matrices
%     U0       : (n_dof x 1) initial displacement
%     V0       : (n_dof x 1) initial velocity
%     A0       : (n_dof x 1) initial acceleration. Caller is responsible
%                for ensuring this is consistent with M A0 = F0 - C V0 - K U0.
%     dt       : time step (s)
%     n_steps  : number of steps to integrate
%     F_func   : @(t, U) returning (n_dof x 1) force vector at time t and
%                tentative displacement U. If F is independent of U, just
%                ignore the U argument.
%
%   Outputs:
%     U_hist, V_hist, A_hist : (n_dof x n_steps+1) time histories,
%                              column 1 holds the initial state.
%     t_hist                 : (1 x n_steps+1) time vector starting at 0.
%
%   Implementation notes:
%     - F is evaluated at the predicted displacement at step n+1, which is
%       a Picard linearization that converges in one pass for the stiff
%       penalty contacts used here, given dt much smaller than the contact
%       natural period.
%     - The effective stiffness K_eff = K + (1/(beta dt^2)) M + (gamma/(beta dt)) C
%       is dominated by M for small dt, so its inverse is well-conditioned
%       even when K is singular (rigid body modes present).
%     - The factorization is cached via `decomposition` so all n_steps
%       linear solves reuse one LU factor.
%
%   Reference: Hughes, The Finite Element Method (Dover ed.), Ch. 9.
%
%   David Angelou, U-M ME, 2026.

    beta  = 0.25;
    gamma = 0.5;

    n_dof = length(U0);

    % Effective stiffness, factored once for the entire run.
    K_eff = K + (1/(beta*dt^2)) * M + (gamma/(beta*dt)) * C;
    dK = decomposition(K_eff);

    % Precompute constant coefficients for the RHS update.
    c1 = 1/(beta*dt^2);
    c2 = 1/(beta*dt);
    c3 = (1/(2*beta)) - 1;
    c4 = gamma/(beta*dt);
    c5 = (gamma/beta) - 1;
    c6 = dt * ((gamma/(2*beta)) - 1);

    U_hist = zeros(n_dof, n_steps + 1);
    V_hist = zeros(n_dof, n_steps + 1);
    A_hist = zeros(n_dof, n_steps + 1);
    t_hist = (0:n_steps) * dt;

    U_hist(:, 1) = U0;
    V_hist(:, 1) = V0;
    A_hist(:, 1) = A0;

    U_n = U0; V_n = V0; A_n = A0;

    for n = 1:n_steps
        t_np1 = n * dt;

        % Predict U(n+1) so F_func can react to the upcoming state.
        U_pred = U_n + dt*V_n + dt^2*(0.5 - beta)*A_n;
        F_np1  = F_func(t_np1, U_pred);

        % Effective load. The M and C contributions are the "internal
        % equivalents" of the past-state terms that bring the Newmark
        % update into a linear solve in U(n+1).
        RHS = F_np1 ...
            + M * (c1*U_n + c2*V_n + c3*A_n) ...
            + C * (c4*U_n + c5*V_n + c6*A_n);

        U_np1 = dK \ RHS;

        % Recover acceleration and velocity from Newmark updates.
        A_np1 = c1*(U_np1 - U_n) - c2*V_n - c3*A_n;
        V_np1 = V_n + dt*((1 - gamma)*A_n + gamma*A_np1);

        U_hist(:, n + 1) = U_np1;
        V_hist(:, n + 1) = V_np1;
        A_hist(:, n + 1) = A_np1;

        U_n = U_np1;
        V_n = V_np1;
        A_n = A_np1;
    end
end
