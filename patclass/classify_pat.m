function pat = classify_pat(pat, stat_name, varargin)
%CLASSIFY_PAT   Run a pattern classifier on a pattern.
%
%  pat = classify_pat(pat, stat_name, ...)
%
%  INPUTS:
%        pat:  a pattern object.
%
%  stat_name:  name of the stat object that will be created to hold
%              results of the analysis. Default: 'patclass'
%
%  OUTPUTS:
%        pat:  modified pattern object with an added stat object.
%
%  PARAMS:
%  These options may be specified using parameter, value pairs or by
%  passing a structure. Defaults are shown in parentheses.
%   regressor    - REQUIRED - input to make_event_index; used to create
%                  the regressor for classification.
%   selector     - REQUIRED - input to make_event_index; used to create
%                  indices for cross-validation.
%   iter_cell    - determines which dimensions to iterate over. See
%                  apply_by_group for details. Default is to classify
%                  all pattern features at once. ({[],[],[],[]})
%   iter_bins    - structure that dynamically determines bins to
%                  iterate over. See patBins for allowed fields.
%                  Specified binned dimensions will overwrite iter_cell.
%                  ([])
%   f_train      - function handle for a training function.
%                  (@train_logreg)
%   train_args   - struct with options for f_train. (struct)
%   train_sampling - how to deal with unequal N in the training set:
%                   'over'  - sample with replacement until each bin has
%                             as many observations as the largest bin.
%                   'under' - sample without replacement to get the same
%                             number of observations from each bin as
%                             the largest bin.
%                   ''      - use all the original samples. (default)
%   n_reps       - number of times to repeat sampling and classification
%                  to obtain a stable measure of classifier performance.
%                  (1000)
%   train_bins   - input to make_event_index; used to define
%                  groups of observations that must be equally
%                  represented in the training set. An equal number of
%                  observations will be randomly sampled from the
%                  members of each group to make the training set. ([])
%   n_reps       - number of times to repeat sampling and
%                  classification, if train_bins are defined. (1000)
%   f_test       - function handle for a testing function.
%                  (@test_logreg)
%   f_perfmet    - function handle for a function that calculates
%                  classifier performance. Can also pass a cell array
%                  of function handles, and all performance metrics will
%                  be calculated. ({@perfmet_maxclass})
%   perfmet_args - cell array of additional arguments to f_perfmet
%                  function(s). ({struct})
%   overwrite    - if true, if the stat file already exists, it will be
%                  overwritten. (true)
%   res_dir      - directory in which to save the classification
%                  results. Default is the pattern's stats directory.
%
%  EXAMPLES:
%   % classify a pattern by the "category" field of events, using
%   % cross-validation at the level of trials
%   params = [];
%   params.regressor = 'category'; % classify events by their category label
%   params.selector = {'session', 'trial'}; % leave-one-out by trial
%   pat = classify_pat(pat, 'patclass_cat', params);
%
%   % run the classification separately for each time bin
%   params.iter_cell = {[],[],'iter',[]};
%   pat = classify_pat(pat, 'patclass_cat_time', params);
%
%   % run seperately for each frequency band
%   params.iter_cell = struct('freqbins', freq_bands1);
%   pat = classify_pat(pat, 'patclass_cat_freq', params);

% input checks
if ~exist('pat', 'var') || ~isstruct(pat)
  error('You must pass a pattern object.')
end
if ~exist('stat_name', 'var')
  stat_name = 'patclass';
end

% default params
defaults.regressor = '';
defaults.test_regressor = '';
defaults.selector = '';
defaults.iter_cell = cell(1, 4);
defaults.iter_bins = [];
defaults.train_bins = [];
defaults.overwrite = true;
defaults.res_dir = get_pat_dir(pat, 'stats');

params = propval(varargin, defaults, 'strict', false);

if isempty(params.regressor)
  error('You must specify a regressor in params.')
elseif isempty(params.selector)
  error('You must specify a selector in params.')
end

% set where the results will be saved
stat_file = fullfile(params.res_dir, ...
                     objfilename('stat', stat_name, pat.source));

% check the output file
if ~params.overwrite && exist(stat_file, 'file')
  return
end

% dynamic grouping
% backwards compatibility
if isstruct(params.iter_cell)
  params.iter_bins = params.iter_cell;
  params.iter_cell = cell(1, 4);
end

if ~isempty(params.iter_bins)
  [temp, inds] = patBins(pat, params.iter_bins);
  to_change = ~cellfun(@isempty, inds);
  params.iter_cell(to_change) = inds(to_change);
end

if ~isempty(params.iter_cell{1})
  error('Iterating and grouping is not supported for the events dimension.')
end

% initialize the stat object
stat = init_stat(stat_name, stat_file, pat.name, params);
stat.subjid = pat.source;

% load the pattern and corresponding events
pattern = get_mat(pat);
events = get_dim(pat.dim, 'ev');

% get the regressor to use for classification
targets = create_targets(events, params.regressor)';

% create test regressors using different bin defs (unusual)
if ~isempty(params.test_regressor)
  params.test_targets = create_targets(events, params.test_regressor)';
end

% get the selector
selector = make_event_index(events, params.selector);

% define training groups that must be sampled equally
if ~isempty(params.train_bins)
  if iscell(params.train_bins)
    % multiple factors
    factors = {};
    levels = {};
    for i = 1:length(params.train_bins)
      [factors{i}, levels{i}] = make_event_index(events, params.train_bins{i});
    end
    params.train_index = make_index(factors{:});
  else
    params.train_index = make_event_index(events, params.train_bins);
  end
end

% run pattern classification separately for each value on the iter_dims
try
  res = apply_by_group(@xval, {pattern}, params.iter_cell, ...
                       {selector, targets, params}, ...
                       'uniform_output', false);
catch err
  fprintf('error thrown during classification:\n')
  disp(getReport(err))
  return
end

% fix the res structure
res_size = size(res);
res_fixed_size = [length(res{1}.iterations) res_size(2:end)];

cell_vec = [res{:}];
struct_vec = [cell_vec.iterations];
res_fixed.iterations = reshape(struct_vec, res_fixed_size);
res = res_fixed;

% save the results
set_stat(stat, 'res', res, 'stat', stat);

% add the stat object to the output pat object
pat = setobj(pat, 'stat', stat);

