function exp = update_exp(exp, varargin)
%exp = update_exp(exp, 'subj', exp.subj(s).id, 'pat', pat);

tic
loading = 1;
while loading
  loading = 0;
  if ~lockFile(exp.file,1)
    loading = 1;
  else
    fprintf('SUCCESS!!!11!');
  end
  
  if toc>100
    error('Could not lock exp.')
    break
  end
end

% get the latest version of exp
load(exp.file);

% make a backup of exp with a timestamp
bk_dir = fullfile(exp.resDir, 'exp_bk');
if ~exist(bk_dir)
  mkdir(bk_dir);
end
timestamp = datestr(now, 'ddmmmyy_HHMM');
bk_file = fullfile(bk_dir, ['exp_' timestamp '.mat']);
save(bk_file, 'exp');

% add the object in place specified
exp = recursive_setobj(exp, varargin);
save(exp.file, 'exp');
releaseFile(exp.file);
