function fig_mod = plot_model(varargin)


% function that plots the model in rho mu lambda parametrisation.
% NOTE: Currenly this is a rather ugly function and I could make it much
% nicer by putting the plotting commands within a for loop over rho mu
% lambda.
%
% - fig_mod = plot_model(Model);
% - fig_mod = plot_model(Model, outparam);
% - fig_mod = plot_model(Model, middle);
% - fig_mod = plot_model(Model, middle, outparam);
%
% INPUT:
% Model:    struct containing .rho .mu .lambda
% outparam: string, 'rhomulambda', 'rhovsvp' (future: 'rhomukappa'?)
%           parametrisation of output plot (also parametrisation of middle)
% middle:   1x3 array w/ colour scale centre values for [param1, param2, param3]; 
%
% OUTPUT:   
% - figure with the model plotted. Colour scale are defined by middle (if 
%   given) -- otherwise, it is the actual max and min of the parameter 
%   values, not some standard deviation.

% format long

[Model, middle] = checkargs(varargin);


input_parameters;
[X,Z,dx,dz]=define_computational_domain(Lx,Lz,nx,nz);
set_figure_properties_maggi;

load 'propagation/cm_model.mat';

fig_mod = figure;
set(fig_mod,'OuterPosition',pos_mod) 
% set(gca,'FontSize',14)

j=1;
for params = fieldnames(Model)';
    

    param = Model.(params{1});

    g = subplot(2,3,j);
    
    p = get(g,'position');
%     p(4) = p(4)*1.50;  % Add 10 percent to height
    set(g, 'position', p);
    
    hold on
    pcolor(X,Z,param');
    
    % difference_mumax_mumin = max(mu(:)) - min(mu(:));
    
    %- colour scale
    if (isnan(middle(j)))
        
        if all(abs(param-mode(param(:))) <= 1e-14*mode(param(1)))
            cmax = param(1) + 0.01*param(1);
            cmin = param(1) - 0.01*param(1);
            %     disp 'bips!!! all param are the same!'
        else
            % max and min are calculated in this way so that the most common value
            % (i.e. the background value) is white, and that the extreme coulours
            % are determined by whichever of max and min is farthest off from the
            % background colour.
            %     cmid = mode(param(:))
            [bincounts, centre] = hist(param(:),100);
            [~,ix]=max(bincounts);
            cmid = centre(ix);
            cmax = cmid + max(abs(param(:) - cmid));
            cmin = cmid - max(abs(param(:) - cmid));
            %     cmax = max(param(:));
            %     cmin = 2*cmid - cmax;
            %     disp 'the param are not all the same'
        end
        
    else
        
        % max and min are calculated in this way so that the most common value
        % (i.e. the background value) is white, and that the extreme coulours
        % are determined by whichever of max and min is farthest off from the
        % background colour.
        cmid = middle(j);
        cmax = cmid + max(abs(param(:) - cmid));
        cmin = cmid - max(abs(param(:) - cmid));
        
    end
    
    caxis([cmin cmax]);
    
    
    for k=1:length(src_x)
        plot(src_x(k),src_z(k),'kx')
    end
    
    for k=1:length(rec_x)
        plot(rec_x(k),rec_z(k),'ko')
    end
    colormap(cm_model);
    axis image
    shading flat
    switch params{1}
        case 'rho'
        title([params{1}, ' [kg/m^3]'])
        case {'vs', 'vp'}
            title([params{1}, ' [m/s]'])
        case {'mu', 'lambda'}
            title([params{1}, ' [N/m^2]'])
        otherwise
            title([params{1}, ' [unit??]'])
    end
    xlabel('x [m]');
    ylabel('z [m]');
    colorbar
    hold off;
    
%     subplot(4,3,6+j)
%     
%      hist(Model.(params{1})(:),100)
%      h = findobj(gca,'Type','patch');
%      set(h,'FaceColor',[.9 .9 .9],'EdgeColor',[.9 .9 .9])
    
    j = j+1;
end

end

function [Model, middle, outparam] = checkargs(arg)

% checks the input argument and defines the fields to be plotted, the
% middle of the plot colour (in all three) and 

narg = length(arg);



switch narg
    
    case 1
        % disp '1 argument'
        Model = arg{1};
        middle = [NaN NaN NaN];
        
    case 2
        % disp '2 arguments'
        Model = arg{1};

        if ischar(arg{2})
            
            outparam = arg{2};
            Model = change_parametrisation('rhomulambda',outparam,Model);
            
            middle = [NaN NaN NaN];
            
        elseif isnumeric(arg{2})
            middle = arg{2};
%             teststruct.mu = 1;
%             teststruct.lambda = 2;
%             teststruct.rho = 3;
%             Model = orderfields(Model, teststruct);
        else
            error('the var type of input argument {2} was not recognised')
        end
        
    case 3
        % disp '3 arguments'
        Model = arg{1};
        middle = arg{2};
        outparam = arg{3};
        Model = change_parametrisation('rhomulambda',outparam,Model);
        

    otherwise
        error('wrong number of variable arguments')
end

end