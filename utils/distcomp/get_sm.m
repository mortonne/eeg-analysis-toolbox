function sm = get_sm(data_loc)
%GET_SM   Get the schedule manager.
%
%  Returns the scheduler used to scheduler toolbox jobs.
%
%  sm = get_sm(data_loc)

if nargin < 1
  data_loc = '~/runs';
end

% set up a scheduler
sm = findResource('scheduler', 'type', 'generic');
if ~exist(data_loc, 'dir')
  mkdir(data_loc);
end
set(sm, 'DataLocation', data_loc)

