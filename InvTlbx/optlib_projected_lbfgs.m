function [flag,mfinal, usr_par]=optlib_projected_lbfgs(m0, options, usr_par)
%
%
options = optlib_init_default_parameters_lbfgs(options);

if (options.verbose)
    options
end

% options.grad_step_length

fid = fopen(options.output_file,'a+');
it=0;

model.m = m0;
model.name = optlib_generate_random_string(8);

[model.objective, model.gradient] = eval_objective_and_gradient(model.m, model.name, usr_par);

usr_par = new_iteration(it, model.m, model.name, model.objective, model.gradient, usr_par);

normg0=norm(model.gradient);
model.normg=normg0;

fprintf(fid,'it=%d   j=%e   ||g||=%e  \n',it,model.objective,model.normg);


% init data for LBFGS here
[previous_models, previous_gradients] = optlib_restore_lbfgs_information(usr_par);

if (size(previous_models,2) > 0)
    if (options.verbose)
        disp 'restoring previous models...'
    end
   l_history = size(previous_models,2);
   lmax = max(options.max_memory,l_history);
    
    P=zeros(size(m0,1),lmax);
    D=zeros(size(m0,1),lmax);
    ga=zeros(lmax,1);
    rho=zeros(lmax,1);
    
    for i=2:l_history
       P(:,i-1) = previous_models(:,i-1) - previous_models(:,i);
       D(:,i-1) = previous_gradients(:,i-1) - previous_gradients(:,i);
    end
    P(:,l_history) = previous_models(:,l_history) - model.m;
    D(:,l_history) = previous_gradients(:,l_history) - model.gradient;
    
    for i=1:l_history
        rho(i) = 1.0 / (D(:,i)' * P(:,i));
%        rho(i) = 1.0 / (P(:,i)' * D(:,i)); 
    end
%     gak = P(:,l_history)' * D(:,l_history) / norm(P(:,l_history));
    gak = D(:,l_history)' * P(:,l_history) / (norm(D(:,l_history))^2);
    l=min(lmax, l_history);
    ln=min(lmax, l_history);

else
    if (options.verbose)
        disp 'not restoring previous models...'
    end
    lmax=options.max_memory;
    P=zeros(size(m0,1),lmax);
    D=zeros(size(m0,1),lmax);
    ga=zeros(lmax,1);
    rho=zeros(lmax,1);
    l=0;
    ln=1;
    gak=1;
end


% ensure m0 is feasible
LBFGS_data.l=l;
LBFGS_data.ln=ln;
LBFGS_data.lmax = lmax;

LBFGS_data.P=P;
LBFGS_data.D=D;
LBFGS_data.rho = rho;
LBFGS_data.gak=gak;
[constraint_M, constraint_rhs] = init_constraints(usr_par);
mp = optlib_project_lbfgs(model.m, constraint_M, constraint_rhs, LBFGS_data );
norm(mp - model.m);
model.m = mp;

[model.objective, model.gradient] = eval_objective_and_gradient(model.m, model.name, usr_par);

mp = optlib_project_lbfgs(model.m -  model.gradient , constraint_M, constraint_rhs, LBFGS_data );
model.normpg = norm(model.m - mp);
normpg0=model.normpg;

fprintf(fid,'it=%d   j=%e   ||g||=%e  opt=%e   \n',it,model.objective,model.normg, model.normpg);

% main loop
while (model.normpg > options.tolerance *normpg0 && ...
       it < options.max_iterations)
    
    it=it+1;

    % compute BFGS-step s=B*g;
    g=model.gradient;
    
    LBFGS_data.l=l;
    LBFGS_data.ln=ln;
    LBFGS_data.lmax = lmax;

    LBFGS_data.P=P;
    LBFGS_data.D=D;
    LBFGS_data.rho = rho;
    LBFGS_data.gak=gak;
    
    s=optlib_apply_lbfgs_inverse_hessian(g,LBFGS_data);
    step='LBFGS';

    % check if BFGS-step provides sufficient decrease; else take gradient
    stg=s'*g;
    if ( stg / (model.normg*norm(s)) < options.sufficient_decrease_angle )
        %fprintf(fid, '\tWarning: Bad angle of search direction. Use steepest descent instead.\n');
        s=g;
        stg=s'*g;
        step='Grad';
    end

    % choose sigma by Powell-Wolfe stepsize rule
    if (it==1)
        % TODO: provide alternative guess of the initial step length based
        % on relative model perturbations
        sigma=options.init_step_length;
    elseif strcmp(step, 'Grad')
        sigma = options.grad_step_length;
    else
        sigma = 1.0;
    end

    % TODO: use quadratic approximation to compute step-length 
    % for iteration 1
    %[sigma,objective_new,gn]=optlib_wolfe(m,s,stg,objective,delta,theta,sigma,usr_par);
    [sigma,model_new]=optlib_projected_wolfe(model.m,s,stg, model.objective, ...
                                   options.wolfe_delta, ...
                                   options.wolfe_theta, ...
                                   sigma, ...
                                   LBFGS_data, ...
                                   options.verbose, ...
                                   usr_par);

    if (options.verbose)
        disp 'new model found.';
    end
    mn=model_new.m;
    gn=model_new.gradient;
    model_new.normg = norm(model_new.gradient);
     mp = optlib_project_lbfgs(model_new.m -  model_new.gradient , constraint_M, constraint_rhs, LBFGS_data );
    model_new.normpg = norm(model_new.m - mp);
   
%     mn=model.m-sigma*s;

    fprintf(fid,'it=%d   j=%e   ||g||=%e   ||opt||=%e   sigma=%6.5f ||s||=%e  step=%s\n', ...
            it, model_new.objective, model_new.normg, model_new.normpg,sigma,norm(s),step);
        
    % update BFGS-matrix
    d=g-gn;
    p=model.m-mn;
    dtp=d'*p;
    if dtp>=1e-8*norm(d)*norm(p)
        rho(ln)=1/dtp;
        D(:,ln)=d;
        P(:,ln)=p;
        l=min(l+1,lmax);
        ln=mod(ln,lmax)+1;
        
        % always scale initial guess
        %  if l==lmax
            gak=dtp/(d'*d);
        % end
    else
        fprintf(fid, '\tWarning: Bad angle of search direction. Update of BFGS curvature information skipped.\n');
    end
    
    model = model_new;
    usr_par = new_iteration(it, model.m, model.name, model.objective, model.gradient, usr_par);

end
flag=0;
if (model.normpg<=options.tolerance*normpg0)
    fprintf(fid,'Successful termination with ||g||<%e*min(1,||g0||):\n',options.tolerance);
    flag = 0;
elseif (flag == 2) % couldn't find Armijo step
    fprintf(fid,'Unsuccessful termination of iterations - couln''t find suitable step\n');
%     flag = 2;
else
    fprintf(fid,'Maximum number of iterations reached.\n');
    flag = 1;
end

% return final model and flag
mfinal=model.m;
fclose(fid);
