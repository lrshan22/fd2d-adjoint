 
function [jm, gm] = eval_objective_and_gradient(m, ModRandString, usr_par)
% EVAL_OBJECTIVE_AND_GRADIENT function to evaluate the objective function and
% to evaluate the gradient at a given model m.
%
% Input:
% m : model
% usr_par : auxiliary user defined parameters (optional)
%
% Output:
% jm : objective value (double)
% gm : gradient (vector of same size as m)
%
% See also EVAL_OBJECTIVE and EVAL_GRAD_OBJECTIVE.

% disp ' ';
% disp('----evaluating objective AND gradient');
% disp ' ';

%% initialise stuff
input_parameters;

% misfit stuff & observed values
misfit_init = usr_par.misfit_init;
whichFrq    = usr_par.whichFrq;
g_obs       = usr_par.g_obs;
sEventInfo  = usr_par.sEventInfo;
sEventObs   = usr_par.sEventObs;
Model_bg    = usr_par.Model_bg;
% InvProps    = usr_par.InvProps;
% iter        = usr_par.iter;

% inversion stuff
output_path     = usr_par.output_path;
% parametrisation = usr_par.parametrisation;
% use_grav        = usr_par.use_grav;
% smoothgwid      = usr_par.smoothgwid;


%% convert variable structures InvTbx -> my structures
[Model] = map_m_to_parameters(m, usr_par);


%% calculate misfits
disp(['calculating current misfit']);

[misfit_total, misfit_seis, misfit_grav, ...
        g_recIter, g_src, sEventRecIter, sEventAdstfIter] = calc_misfits(Model, ...
                  g_obs, misfit_init(whichFrq).grav , ...
                  sEventInfo, sEventObs, misfit_init(whichFrq).seis, ...
                  'yessavefields','noplot','yessaveplots');

% save model and forward field info to file
TempFolder = [output_path,'/fwd_temp/'];
ModFolder = [output_path,'/fwd_temp/',ModRandString,'/'];
mkdir(ModFolder)
save([ModFolder,'model-adstf.mat'], ...
    'ModRandString', 'Model', 'sEventAdstfIter', 'g_src', '-v6');
save([ModFolder,'iter-rec.mat'], ...
    'ModRandString', 'Model', 'sEventRecIter', 'g_recIter', '-v6');



%% calculate gradients

% gravity
if strcmp(use_grav,'yes')
    %- calculate gravity kernels
    disp ' ';
    disp(['calculating gravity kernel']);
    
    % calculating the gravity kernel
    [Kg_temp] = compute_kernels_gravity(g_src,rec_g,which_grav,'noplot'); % 'noplot' is for plotting gravity kernel update

    % normalising the gravity kernel
    Kg = norm_kernel(Kg_temp, normalise_misfits, ...
        misfit_init(whichFrq).grav);
    clearvars Kg_temp;

end

% seismic
if strcmp(use_seis, 'yesseis')
    disp ' ';
    disp(['calculating seismic kernels']);
    [Kseis_temp, ~] = run_adjoint_persource(Model, sEventAdstfIter);
    
    % normalise kernels
    Kseis = norm_kernel(Kseis_temp, normalise_misfits, ...
        misfit_init(whichFrq).seis);
end

%% combine gradients to Ktotal

if strcmp(use_grav,'yes') && strcmp(use_seis, 'yesseis')
    % determine weight of respective kernels
    w_Kseis = 1;
    w_Kg = 1;
    
    % combine seismic and gravity kernels
    disp ' '; disp('combining gravity and seismic kernels');
    
    % add kernels in appropriate parametrisation
    Ktest = change_parametrisation_kernels('rhomulambda',parametrisation,Kseis,Model);
    switch parametrisation
        case 'rhomulambda'
            Ktest.rho.total = w_Kseis * Ktest.rho.total + w_Kg * Kg;
        case 'rhovsvp'
            Ktest.rho2.total = w_Kseis * Ktest.rho2.total  +  w_Kg * Kg;
        otherwise
            error('the parametrisation in which kernels are added was unknown');
    end 

elseif ~strcmp(use_grav,'yes') && strcmp(use_seis, 'yesseis')
    Ktest = Kseis;
%     if strcmp(parametrisation, 'rhovsvp')
%         Ktotal = change_parametrisation_kernels('rhovsvp', 'rhomulambda', Kseis, Model_bg);
%     end
elseif strcmp(use_grav,'yes') && ~strcmp(use_seis, 'yesseis')
    switch parametrisation
        case 'rhomulambda'
            Ktest.rho.total = Kg;
            Ktest.mu.total = zeros(size(Kg));
            Ktest.lambda.total = zeros(size(Kg));
        case 'rhovsvp'
            Ktest.rho2.total = Kg;
            Ktest.vs2.total = zeros(size(Kg));
            Ktest.vp2.total = zeros(size(Kg));
    end
else
    error('help, NO data?!');
end

% saving the total kernel in rho-mu-lambda
K_total = change_parametrisation_kernels(parametrisation,'rhomulambda', Ktest,Model_bg);
% clear dummy variables
clearvars('Ktest', 'Ktest1');


%% OUTPUT to Inversion Toolbox structure

jm = misfit_total;

usr_par.Mod_current = Model;
gm = map_gradparameters_to_gradm(K_total, usr_par);

%% save variables of current iteration to file
currentMisfits.misfit      = misfit_total;
currentMisfits.misfit_seis = misfit_seis;
currentMisfits.misfit_grav = misfit_grav;
if strcmp(use_seis, 'yesseis');
    currentKnls.Kseis       = Kseis;
end
if strcmp(use_grav, 'yes')
    currentKnls.Kg          = Kg;
end
currentKnls.K_total     = K_total;
save([ModFolder,'currentIter.misfits.mat'], 'currentMisfits', '-v6');
save([ModFolder,'currentIter.kernels.mat'], 'currentKnls', '-v6');


%% move saved matfiles to model specific folder

blips = dir([TempFolder,'*.mat']);
for ii = 1:numel(blips)
    bestand = blips(ii).name;
    oldfile = [TempFolder,bestand];
    newfile = [ModFolder,bestand];
    movefile(oldfile,newfile);
end; clearvars blips;

end