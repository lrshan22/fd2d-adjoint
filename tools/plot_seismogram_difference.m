function fig_seisdif = plot_seismogram_difference(v_obs, v_rec, t, varargin)

% This function is (just like @ make_adjoint_sources) to plot the observed
% and recorded seismograms, and the difference between them.
%
% SYNTAX:
% fig_seisdif = plot_seismogram_difference(v_obs, v_rec, t)
%           and plot_seismogram_difference(v_obs, v_rec, t, 'yesdiff')
%               [plots seismograms from all stations obs, rec and diff]
% fig_seisdif = plot_seismogram_difference(v_obs, v_rec, t, 'nodiff')
%               [plots seismograms from all stations obs, rec - NO DIFF]
% fig_seisdif = plot_seismogram_difference(v_obs, v_rec, t, [recs])
%           and plot_seismogram_difference(v_obs, v_rec, t, [recs], 'yesdiff')
%               [plots seismograms obs, rec and diff for stations defined in [recs] ]
% fig_seisdif = plot_seismogram_difference(v_obs, v_rec, t, [recs], 'nodiff')
%               [plots seismograms obs, rec for stations defined in [recs] - NO DIFF]
%
% INPUT:
% - v_obs:  struct containing x and/or y and/or z traces of seismograms
% - v_rec:  struct containing x and/or y and/or z traces of seismograms. At
%           the very least, the same components as are present in v_obs
%           must be present in this struct, else errors will ensue.
% - t:      time axis.
%
% OUTPUT:
% - figure  plotting both sets of seismograms, plus the difference traces of
%   (v_rec - v_obs).
% - seisdif: figure handle of this figure

fig_seisdif = figure;
set_figure_properties_bothmachines;
set(fig_seisdif, 'OuterPosition', pos_seis);
if (feature('showfigurewindows') == 0)
    set(fig_seisdif, 'PaperUnits', 'points');
    set(fig_seisdif, 'PaperPosition', pos_seis);
end
[recs_given, recs_in, plot_diff] = check_args(varargin(:));


% number of components (x,y,z) for which seismograms have been recorded
ncomp = size(fieldnames(v_obs{1}), 1);

switch recs_given
    case 'yes'
        nrec = length(recs_in);
        recs = recs_in;
    case 'no'
        % number of receivers for which we have seismograms
        nrec = length(v_obs);
        recs = 1:nrec;
    otherwise
        error('wrong recs');
end

iplot = 0;
maks = 0;
for irows = 1:nrec;
    irec = recs(irows);
    comp = fieldnames(v_obs{irec});
    for icomp = 1:ncomp;
        
%         subplot(ncomp,1,icomp);
        iplot = iplot+1;
        subfiguur(iplot) = subplot(nrec,ncomp,(irows-1)*ncomp + icomp);
        vrec = v_rec{irec}.(comp{icomp});
        vobs = v_obs{irec}.(comp{icomp});
        hold on
        plot(t,vobs,'-k', 'LineWidth', 1.0);
        plot(t,vrec,'-r', 'LineWidth', 0.5);
         if strcmp(plot_diff, 'yesdiff')
             plot(t,10*(vrec - vobs), 'b');
             % plot(t,vrec - vobs, 'b', 'LineWidth',2)
         end
         
        if ~(max(vobs) == 0 && max(vrec) == 0)
            maks = max(maks, max(ylim(subfiguur(iplot))));
           %maks = max(maks, max(subfiguur(iplot).YLim));
        end
        
        
        if irows==1
            if strcmp(plot_diff, 'yesdiff')
                title({[comp{icomp},' component:']; 'synth - red, obs - black, 10*(synth-obs) - blue'})
            else
                title({[comp{icomp},' component:']; 'synth - red, obs - black'})
            end
        end
        if irec==nrec
        xlabel('t [s]')
        end
        ylabel('v [m/s]')
        xlim([0 t(end)]);
        
        text(0.01, 0.9, ['rec. ',num2str(irec)], ...
                        'Units', 'normalized');
%                         'HorizontalAlignment','right', ...
        
    end
end

linkaxes(subfiguur, 'y');
ylim(subfiguur(iplot), [-maks maks]);
%subfiguur(iplot).YLim = [-maks maks];

end

function [recs_given, recs, plot_diff] = check_args(args)

nargs = length(args);

switch nargs
    case 0
        plot_diff = 'yesdiff';
        recs_given = 'no';
        recs = NaN;
    case 1
        if ischar(args{1})
            plot_diff = args{1};
            recs_given = 'no';
            recs = NaN;
        else
            plot_diff = 'yesdiff';
            recs_given = 'yes';
            recs = args{1};
        end
    case 2
        recs_given = 'yes';
        recs = args{1};
        plot_diff = args{2};
    otherwise
%         tekstje = ['unknown number of input args: ', num2str(nargs)];
        error(['unknown number of input args: ', num2str(nargs)])
end

end