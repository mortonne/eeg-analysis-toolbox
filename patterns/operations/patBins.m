function [pat, bins] = patBins(pat, varargin)
%PATBINS   Apply bins to dimensions of a pat object.
%
%  [pat, bins] = patBins(pat, ...)
%
%  Bin dimensions of a pattern. Determines the indices of the pattern
%  for each bin, and updates the dimension information in the pat
%  object. The pattern matrix is not modified.
%
%  INPUTS:
%      pat:  a pattern object.
%
%  OUTPUTS:
%      pat:  the modified pattern object.
%
%     bins:  a cell array with one cell for each dimension of the
%            pattern. Each cell contains a cell array with one cell for
%            each bin, which contains the indices in the pattern that
%            correspond to the bin. If a dimension is not being binned,
%            the cell for that dimension will be empty.
%
%  PARAMS:
%  Options may be specified using parameter, value pairs or a structure.
%  Default values are shown in parentheses.
%   eventbins      - cell array specifying event bins. Each cell is
%                    input to make_event_bins to create indices. ([])
%   eventbinlabels - cell array of strings giving a label for each event
%                    bin. ({})
%   chanbins       - cell array specifying channel bins. Each cell can
%                    be a vector of channel numbers, a cell array of
%                    regions, or a string to be passed into
%                    filterStruct. ([])
%   chanbinlabels  - cell array of string labels for each channel bin.
%                    ({})
%   MSbins         - [nbins X 2] array specifying time bins. MSbins(i,:)
%                    gives the range of millisecond values for bin i.
%                    ([])
%   MSbinlabels    - cell array of string labels for each time bin. ({})
%   freqbins       - [nbins X 2] array specifying frequency bins.
%                    freqbins(i,:) gives the range of frequencies for
%                    bin i. ([])
%   freqbinlabels  - cell array of string labels for each frequency bin.
%                    ({})
%
%  All *bins fields may also be set to:
%   ':'    - place all indices of the dimension in one bin
%   'iter' - place each index in its own bin
%  NOTE: THE ':' and 'iter' OPTIONS WILL NOT GROUP THE PAT OBJECT, ONLY
%        THE BINS. Support for modifying the pat will be added later.
%
%  EXAMPLE:
%   sample pattern with three sessions; want to get average for each
%   session and average over 0-1000 ms
%   >> patsize(pat.dim)
%      253   129    90    18
%   >> [pat, bins] = patBins(pat, 'eventbins', 'session', ...
%                                 'MSbins', [0 1000]);
%   >> patsize(pat.dim)
%      3     129    1     18
%   >> bins
%      {1x3 cell}     []    {1x1 cell}     []
%
%  See also make_bins, patMeans, modify_pattern, patFilt.

% input checks
if ~exist('pat', 'var') || ~isstruct(pat)
  error('You must pass a pattern object.')
end
if ~isfield(pat.dim.ev, 'modified')
  pat.dim.ev.modified = false;
end

% default parameters
defaults.eventbins = [];
defaults.eventbinlabels = {};
defaults.chanbins = [];
defaults.chanbinlabels = {};
defaults.MSbins = [];
defaults.MSbinlabels = {};
defaults.freqbins = [];
defaults.freqbinlabels = {};

[params, unused] = propval(varargin, defaults);

% initialize
bins = cell(1, 4);

% translate : indexes to bin format
all_bin_fields = {'eventbins' 'chanbins' 'MSbins' 'freqbins'};
for i=1:length(all_bin_fields)
  bin_input = params.(all_bin_fields{i});
  if ischar(bin_input) && ismember(bin_input, {':', 'iter'})
    switch bin_input
     case ':'
      bins{i} = {1:patsize(pat.dim, i)};
     case 'iter'
      bins{i} = num2cell(1:patsize(pat.dim, i));
    end
    params.(all_bin_fields{i}) = [];
  end      
end

% events
if ~isempty(params.eventbins)
  % load events
  events = get_dim(pat.dim, 'ev');
  [events, bins{1}] = event_bins(events, params.eventbins, ...
                                 params.eventbinlabels);
  
  % save the events to the new ev object
  pat.dim.ev = set_mat(pat.dim.ev, events, 'ws');
  pat.dim.ev.modified = true;
end

% channels
if ~isempty(params.chanbins)
  [chan, bins{2}] = chan_bins(get_dim(pat.dim, 'chan'), params.chanbins, ...
                              params.chanbinlabels);
  pat.dim = set_dim(pat.dim, 'chan', chan);
end

% time
if ~isempty(params.MSbins)
  [pat.dim.time, bins{3}] = time_bins(pat.dim.time, params.MSbins, ...
                                      params.MSbinlabels);
end

% frequency
if ~isempty(params.freqbins)
  [pat.dim.freq, bins{4}] = freq_bins(pat.dim.freq, params.freqbins, ...
                                      params.freqbinlabels);
end

% check the dimensions
psize = patsize(pat.dim);
if any(~psize)
  error('A dimension of pattern %s was binned into oblivion.', pat.name);
end


function [events2, bins] = event_bins(events1, bin_defs, labels)
  %EVENT_BINS   Apply bins to an events dimension.
  %
  %  [ev, bins] = event_bins(ev, bin_defs, labels)
  %
  %  INPUTS:
  %        ev:  an ev object.
  %
  %  bin_defs:  a cell array with one cell per bin. See make_event_bins
  %             for possible values of each cell.
  %
  %    labels:  a cell array of strings indicating a label for each bin.
  %
  %  OUTPUTS:
  %        ev:  a modified ev object. The events structure is also
  %             modified and stored in ev.mat. There will be one event
  %             for each bin.
  %
  %      bins:  a cell array with one cell per bin, where each cell
  %             contains indices for the events in that bin.

  % input checks
  if ~exist('events1', 'var') || ~isstruct(events1)
    error('You must pass an event structure.')
  elseif ~exist('bin_defs', 'var')
    error('You must define the bins.')
  end
  if ~exist('labels', 'var')
    labels = {};
  end

  % load the events
  fnames = fieldnames(events1);
  
  % generate a new events field, one value per bin
  vec = make_event_bins(events1, bin_defs);
  if ~(isnumeric(vec) || iscellstr(vec))
    error('The labels returned by make_event_bins have an invalid type.')
  end
  
  % get values that correspond to bins; NaNs are not included anywhere
  vals = unique(vec);
  if isnumeric(vals)
    vals = vals(~isnan(vals));
  end

  % set the labels field for the new events
  if isempty(labels)
    if iscellstr(vals)
      labels = vals;
    else
      labels = num2cell(vals);
    end
  end

  events2 = [];
  for i=1:length(vals)
    bins{i} = find(ismember(vec, vals(i)));
    
    % salvage fields that have the same value for this whole bin
    bin_event = collapse_struct(events1(bins{i}));
    events2 = cat_structs(events2, bin_event);
  end
  [events2.label] = labels{:};


function [chan2, bins] = chan_bins(chan1, bin_defs, labels)
  %CHAN_BINS   Apply binning to a channel dimension.
  %
  %  [chan, bins] = chan_bins(chan, bin_defs, labels)
  %
  %  INPUTS:
  %      chan:  a channels structure.
  %
  %  bin_defs:  a cell array, where each cell defines one bin.
  %             Each cell may contain:
  %              [c1 c2 c2 ...] - an array of channel numbers
  %              {'r1' 'r2' 'r3' ...} - a cell array of labels
  %              'filter'       - a string to be input to filterStruct
  %
  %    labels:  a cell array of strings giving a label for each
  %             bin.  If not specified, and each bin contains a unique
  %             region, region labels will be used as labels for each
  %             bin.  Otherwise, channel numbers will be used as labels.
  %
  %  OUTPUTS:
  %     chan:  the modified channels structure.
  %
  %     bins:  cell array where each cell contains the indices for
  %            the corresponding bin in the original channels dimension.
  %
  %  NOTES:
  %   To assume and maintain in the output chan structure:
  %   number is defined and unique. It contains a numeric scalar.
  %   label is defined and unique. It contains a string.
  %   there may be other fields, which will be kept if possible.
  
  % input checks
  if ~exist('chan1', 'var') || ~isstruct(chan1)
    error('You must pass a channels structure to bin.')
  elseif ~exist('bin_defs', 'var')
    error('You must pass bin definitions.')
  end
  if ~iscell(bin_defs)
    bin_defs = {bin_defs};
  end
  if ~exist('labels', 'var')
    labels = {};
  elseif ~iscellstr(labels)
    error('labels must be a cell array of strings.')
  elseif ~isempty(labels) && length(labels) ~= length(bin_defs)
    error('labels must be the same length as bin_defs.')
  end

  % get numbers and regions from the old channels struct
  c = bin_defs;
  dim.chan = chan1;
  chan_numbers = get_dim_vals(dim, 'chan');
  chan_labels = get_dim_labels(dim, 'chan');
  
  % define each channel bin
  n_bins = length(c);
  bins = cell(1, n_bins);
  chan2 = [];
  for i = 1:n_bins
    if isnumeric(c{i})
      % channel numbers
      bins{i} = find(ismember(chan_numbers, c{i}));
    elseif iscellstr(c{i})
      % channel labels
      bins{i} = find(ismember(chan_labels, c{i}));
    elseif ischar(c{i})
      % filter string
      bins{i} = find(inStruct(chan1, c{i}));
    else
      error('Channel bin %d definition is invalid', i)
    end
    
    % remove fields that vary between elements
    bin_chan = collapse_struct(chan1(bins{i}));
    
    % if multiple channels in bin, mark for assignment
    % of a new number (will be unique)
    if ~isfield(bin_chan, 'number')
      bin_chan.number = NaN;
    end
    
    if ~isempty(labels)
      % user-defined label
      bin_chan.label = labels{i};
    elseif ~isfield(bin_chan, 'label')
      % combine the labels of included channels
      bin_chan.label = strtrim(sprintf('%s ', chan1(bins{i}).label));
    end
    
    % add this bin
    chan2 = cat_structs(chan2, bin_chan);
  end
  
  % assign new channel numbers where needed
  bad = isnan([chan2.number]);
  if any(bad)
    % use only unused numbers
    new = num2cell(setdiff(1:n_bins, [chan2(~bad).number]));
    [chan2(bad).number] = new{:};
  end

  
function [time2, bins] = time_bins(time1, bin_defs, labels)
  %TIME_BINS   Apply binning to a time dimension.
  %
  %  [time, bins] = time_bins(time, bin_defs, labels)
  %
  %  INPUTS:
  %      time:  a time structure.
  %
  %  bin_defs:  
  %
  %    labels:  a cell array of strings for each bin.
  %
  %  OUTPUTS:
  %      time:  a modified time structure.
  %
  %      bins:  a cell array where each cell contains the indices for
  %             that bin.

  % input checks
  if ~exist('time1','var') || ~isstruct(time1)
    error('You must pass a time structure to bin.')
  elseif ~exist('bin_defs','var')
    error('You must pass bin definitions.')
  end
  if ~exist('labels','var')
    labels = {};
  elseif ~iscellstr(labels)
    error('labels must be a cell array of strings.')
  elseif ~isempty(labels) && length(labels)~=size(bin_defs, 1)
    error('labels must be the same length as bin_defs.')
  end

  % get the indices corresponding to each bin
  bins = apply_bins([time1.avg], bin_defs);
  
  % create the new time structure
  time2 = struct('MSvals', cell(size(bins)), 'avg', [], 'label', '');
  for i=1:length(bins)
    % min and max vals for this bin
    if ~isempty(bins{i})
      start_val = time1(bins{i}(1)).MSvals(1);
      last_val = time1(bins{i}(end)).MSvals(end);
      time2(i).MSvals = [start_val last_val];
    else
      time2(i).MSvals = NaN(1, 2);
    end
    
    % average for this bin
    time2(i).avg = nanmean(time2(i).MSvals);
  end

  % update the labels
  if isempty(labels)
    f = @(x)sprintf('%d to %d ms', x(1), x(end));
    labels = cellfun(f, {time2.MSvals}, 'UniformOutput', false);
  end
  [time2.label] = labels{:};
%endfunction

function [freq2, bins] = freq_bins(freq1, bin_defs, labels)
  %FREQ_BINS   Apply binning to a frequency dimension.
  %
  %  [freq, bins] = freq_bins(freq, bin_defs, labels)
  %
  %  INPUTS:
  %      freq:  a frequency structure.
  %
  %  bin_defs:  
  %
  %    labels:  a cell array of strings for each bin.
  %
  %  OUTPUTS:
  %      freq:  a modified frequency structure.
  %
  %      bins:  a cell array where each cell contains the indices for
  %             that bin.

  % input checks
  if ~exist('freq1','var') || ~isstruct(freq1)
    error('You must pass a freq structure to bin.')
  elseif ~exist('bin_defs','var')
    error('You must pass bin definitions.')
  end
  if ~exist('labels','var')
    labels = {};
  elseif ~iscellstr(labels)
    error('labels must be a cell array of strings.')
  elseif ~isempty(labels) && length(labels)~=size(bin_defs, 1)
    error('labels must be the same length as bin_defs.')
  end

  % get the indices corresponding to each bin
  bins = apply_bins([freq1.avg], bin_defs);
  
  % create the new time structure
  freq2 = struct('vals', cell(size(bins)), 'avg', [], 'label', '');
  for i=1:length(bins)
    % min and max vals for this bin
    if ~isempty(bins{i})
      start_val = freq1(bins{i}(1)).vals(1);
      last_val = freq1(bins{i}(end)).vals(end);
      freq2(i).vals = [start_val last_val];
    else
      freq2(i).vals = NaN(1, 2);
    end
    
    % average for this bin
    freq2(i).avg = nanmean(freq2(i).vals);
  end
  
  % update the labels
  if isempty(labels)
    f = @(x)sprintf('%d to %d Hz', round(x(1)), round(x(end)));
    labels = cellfun(f, {freq2.vals}, 'UniformOutput', false);
  end
  [freq2.label] = labels{:};
%endfunction
