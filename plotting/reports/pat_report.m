function pdf_file = pat_report(pat, dim, fig_names, varargin)
%PAT_REPORT   Create a report from pattern figures.
%
%  pdf_file = pat_report(pat, dim, fig_names, ...)
%
%  INPUTS:
%        pat:  a pattern object.
%
%        dim:  name or number of the dimension to plot along rows.
%
%  fig_names:  cell array of strings giving figure object names.
%
%  PARAMS:
%   fig_labels     - cell array of strings labeling each column of the
%                    report. ({})
%   eval_fig_labels - statement to evaluate to give labels to each
%                     row of the report ('')
%   title          - string title for the report. ('')
%   landscape      - if true, PDF will be in landscape orientation.
%                    (true)
%   compile_method - specifies how to compile the LaTeX file. See
%                    pdflatex for options. ('latexdvipdf')
%   report_file    - path to the report file to create (without file
%                    extension). Default: saved in the pattern's
%                    default reports directory as [pat.name]_report.pdf

% Copyright 2007-2011 Neal Morton, Sean Polyn, Zachary Cohen, Matthew Mollison.
%
% This file is part of EEG Analysis Toolbox.
%
% EEG Analysis Toolbox is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% EEG Analysis Toolbox is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
%
% You should have received a copy of the GNU Lesser General Public License
% along with EEG Analysis Toolbox.  If not, see <http://www.gnu.org/licenses/>.

% set options
defaults.fig_labels = {};
defaults.eval_fig_labels = '';
defaults.title = '';
defaults.landscape = true;
defaults.compile_method = 'latexdvipdf';
defaults.landscape = true;
defaults.report_file = '';
params = propval(varargin, defaults);

if ~isempty(params.eval_fig_labels)
  params.fig_labels = eval(params.eval_fig_labels);
end

if isempty(params.report_file)
  report_dir = get_pat_dir(pat, 'reports');
  basename = pat.name;
  for i = 1:length(fig_names)
    basename = [basename '_' fig_names{i}];
  end
  report_file = fullfile(report_dir, get_next_file([basename '_report']));
else
  report_file = params.report_file;
end

[table, header] = create_pat_report(pat, dim, fig_names, params.fig_labels);

longtable(table, header, report_file, params.title, params.landscape);
pdf_file = pdflatex(report_file, params.compile_method);
