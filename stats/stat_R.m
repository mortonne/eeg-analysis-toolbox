function [p, statistic, res] = stat_R(data, group, f, varargin)
%Run a statistical test in R.
%
%  [p, statistic, res] = stat_R(data, group, f, ...)
%
%  INPUTS:
%     data:  vector of numeric data.
%
%    group:  cell array of factors. Each factor may be numeric or a cell
%            array of strings.
%
%        f:  name of the R file to call.

% get temporary files to write to
tempdir = '~/.Rtemp';
if ~exist(tempdir, 'dir')
  mkdir(tempdir)
end
infile = fullfile(tempdir, 'in.txt');
outfile = fullfile(tempdir, 'out.txt');

% fix regressors to standard format
for i = 1:length(group)
  group{i} = make_index(group{i});
end

% write data to a text file
export_R(data, group, infile)

% run the ANOVA in R
res.output = run_R(f, infile, outfile);
delete(infile)

if exist(outfile, 'file')
  % we just have to read in the output table
  % read the results (assumed to be just two columns of numbers:
  % statistic, then p)
  fid = fopen(outfile, 'r');
  c = textscan(fid, '%n%n');
  fclose(fid);

  statistic = c{1};
  p = c{2};

  delete(outfile)
elseif strcmp(f, 'rmaov1.R')
  % assume using the CAR package, which doesn't give machine-
  % readable output; must parse the printed summary instead

  % get the univariate test statistic
  table = regexp(res.output, 'Univariate([^\n]*\n){7}', 'match');
  factor = regexp(table{1}, 'rm\.factor[^\n]*', 'match');
  spl = regexp(factor{1}, '\s*', 'split');
  statistic = str2num(spl{6});
  if isempty(statistic)
    error('could not find output statistic')
  end
  
  % get the Greenhouse-Geisser corrected p-value
  table = regexp(res.output, 'GG\seps([^\n]*\n){2}', 'match');
  factor = regexp(table{1}, 'rm\.factor[^\n]*', 'match');
  spl = regexp(factor{1}, '\s*', 'split');
  if strcmp(spl{3}, '<')
    p = str2num(spl{4});
  else
    p = str2num(spl{3});
  end
  if isempty(p)
    error('could not find output p-value')
  end
  
elseif strcmp(f, 'rmaov2.R')
  
  
end
