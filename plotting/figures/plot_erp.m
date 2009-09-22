function h = plot_erp(data, time, params)
%PLOT_ERP   Plot an event-related potential.
%
%  h = plot_erp(data, time, params)
%
%  INPUTS:
%     data:  array of voltage values to plot. If data is a matrix, each
%            row will be plotted as a separate line.
%
%     time:  time values corresponding to each column of data.
%
%   params:  a structure specifying options for plotting. See below.
%
%  OUTPUTS:
%        h:  vector of handles for each line plotted.
%
%  PARAMS:
%   x_lim      - limits of the time axis in [min, max] form
%   time_units - units of the time axis. ('ms')
%   x_label    - label for the x-axis. ('Time (time_units)' if time
%                vector given, otherwise 'Time (samples)')
%   y_lim      - limits of the voltage axis in [min, max] form
%   volt_units - units of the voltage axis. ('\muV')
%   y_label    - label for the y-axis. ('Voltage (volt_units)')
%   colors     - cell array indicating the order of colors to use 
%                for the lines. ({})
%   mark       - boolean vector indicating samples to be marked
%                (e.g., significant samples). Shading will be put
%                just below the plot. ([])
%   fill_color - [1 X 3] array giving the color to use for marks.
%                ([.8 .8 .8])

% input checks
if ~exist('data','var')
  error('You must pass a matrix of values to plot.')
end
if ~exist('time','var')
  time = [];
end
if ~exist('params','var')
  params = [];
end

% set default parameters
params = structDefaults(params, ...
                        'time_units',       'ms',     ...
                        'volt_units',       '\muV',   ...
                        'colors',           {},       ...
                        'x_lim',            [],       ...
                        'y_lim',            [],       ...
                        'x_label',          '',       ...
                        'y_label',          '',       ...
                        'mark',             [],       ...
                        'fill_color',       [.8 .8 .8]);

publishfig

% x-axis values
if ~isempty(time)
  x = time;
else
  x = 1:size(data,2);
end

% x-axis label
if ~isempty(params.x_label)
  xlabel(params.x_label)
elseif ~isempty(time)
  xlabel(sprintf('Time (%s)', params.time_units))
else
  xlabel('Time (samples)')
end

% set the x-limits
if ~isempty(params.x_lim)
  x_lim = params.x_lim;
else
  x_lim = [x(1) x(end)];
end

% y-axis
if ~isempty(params.y_label)
  ylabel(params.y_label)
else
  ylabel(sprintf('Voltage (%s)', params.volt_units))
end

% min and max of the data
y_min = min(data(:));
if isnan(y_min)
  y_min = -1;
end
y_max = max(data(:));
if isnan(y_max)
  y_max = 1;
end

% set the y-limits
if ~isempty(params.y_lim)
  % use standard y-limits
  y_lim = params.y_lim;
else
  % buffer from top and bottom
  buffer = (y_max-y_min)*0.2;
  y_lim = [y_min-buffer y_max+buffer];
end

% mark samples
hold on
if ~isempty(params.mark)
  if ~isvector(params.mark)
    error('params.mark must be a vector.')
  elseif length(params.mark)~=length(x)
    error('params.mark must be the same length as data.')
  end
  
  offset = diff(y_lim)*0.07;
  bar_y = y_min - offset;
  bar_y_lim = [(bar_y - offset/2) bar_y];
  shade_regions(x, params.mark, bar_y_lim, params.fill_color);
end

% make the plot
h = plot(x, data, 'LineWidth', 2);

% change line colors from their defaults
if ~isempty(params.colors)
  for i=1:length(h)
    set(h(i), 'Color', params.colors{mod(i-1,length(params.colors))+1})
  end
end

% set limits
set(gca, 'YLimMode','manual')
set(gca, 'XLim',x_lim, 'YLim',y_lim)

% plot axes
plot(get(gca,'XLim'), [0 0], '--k');
plot([0 0], y_lim, '--k');
hold off

function shade_regions(x, mark, y_lim, fill_color)
  %SHADE_REGIONS   Shade in multiple rectangles.
  %
  %  shade_regions(x, mark, y_lim, fill_color)
  %
  %  INPUTS:
  %           x:  vector of x values.
  %
  %        mark:  boolean vector where indices to shade are true.
  %               Must correspond to x.
  %
  %       y_lim:  two-element array of the form [y_min y_max],
  %               indicating the y-limits of each shaded region.
  %
  %  fill_color:  color to use when shading each region.
  
  % pad x so we can count start and end right
  diff_vec = diff([0 mark(:)' 0]);

  % get the start and end of each region
  starts = find(diff_vec(1:end-1)==1);
  ends = find(diff_vec(2:end)==-1);

  nRegions = length(starts);
  for i=1:nRegions
    % start end end start
    l2r = [starts(i) ends(i)];
    r2l = fliplr(l2r);

    % x and y coords of this polygon
    region_x = [x(l2r) x(r2l)];
    region_y = [y_lim(1) y_lim(1) y_lim(2) y_lim(2)];

    % fill the region
    h = fill(region_x, region_y, fill_color);
    set(h, 'edgecolor', fill_color)
    hold on
  end
%endfunction
