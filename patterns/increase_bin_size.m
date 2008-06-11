function exp = increase_bin_size(exp, params, patname, resDir)
%
%INCREASE_BIN_SIZE - average over adjacent time or frequency bins
%to decrease the size of patterns, or average over channels for ROI
%analyses; new patterns will be saved in a new directory
%
% FUNCTION: exp = increase_bin_size(exp, params, patname, resDir)
%
% INPUT: exp - struct created by init_iEEG or init_scalp
%        params - required fields: patname (specifies the name of
%                 which pattern in the exp struct to use)
%
%                 optional fields: eventFilter (specify subset of
%                 events to use), masks (cell array containing
%                 names of masks to apply to pattern)
%        resDir - 'pattern' files are saved in resDir/data
%        patname - name of new pattern to save under in the exp struct
%
% OUTPUT: exp struct with a new pat object added, which contains file
% info and parameters of the analysis
%
% params.chanbins = {{'Fp1', 'LFp'}, {'Fp2', 'RFp'}, {'F3', 'F7', ...
% 'LF'}, {'F4', 'F7', 'RF'}, 'LFT', 'RFT', {'T3', 'T5', 'LT'}, ...
% {'T4', 'T6', 'RT'}, {'P3', 'LP'}, {'P4', 'RP'}, {'O1', 'LO'}, ...
% {'O2', 'RO'}};
% params.chanbinlabels = {'LFp', 'RFp', 'LF', 'RF', 'LFT', 'RFT', ...
% 'LT', 'RT', 'LP', 'RP', 'LO', 'RO'};
%

if ~exist('resDir', 'var')
  resDir = fullfile(exp.resDir, 'eeg', patname);
end

params = structDefaults(params, 'patname', '',  'eventFilter', '',  'masks', {},  'nComp', []);

if ~exist('patname', 'var')
  patname = [params.patname '_mod'];
end

% create the new pattern for each subject
for s=1:length(exp.subj)
  fprintf('\n%s\n', exp.subj(s).id);
  
  % set where the pattern will be saved
  patfile = fullfile(resDir, 'patterns', [exp.subj(s).id '_' patname '.mat']);
  
  % get the pat obj for the original pattern
  pat1 = getobj(exp.subj(s), 'pat', params.patname);  
  
  % check input files and prepare output files
  if prepFiles(pat1.file, patfile, params)~=0
    continue
  end
  
  % do the binning
  [pat, pattern, events] = patBins(pat1, params);

	if ~isempty(params.nComp)
		% run PCA on the pattern
		[pat, pattern, coeff] = patPCA(pat, params, pattern);
	end

	pat.name = patname;
  pat.file = patfile;
  pat.params = params;
  fprintf('Pattern "%s" created.\n', pat.name)
  
  if pat.dim.ev.len<pat1.dim.ev.len 
    if ~exist(fullfile(resDir, 'events'), 'dir')
      mkdir(fullfile(resDir, 'events'));
    end
    
    % we need to save a new events struct
    pat.dim.ev.file = fullfile(resDir, 'events', [exp.subj(s).id '_' patname '_events.mat']);
    save(pat.dim.ev.file, 'events');
  end

  % update exp with the new pat object
  exp = update_exp(exp, 'subj', exp.subj(s).id, 'pat', pat);
  
  % save the new pattern
	if exist('coeff','var')
		save(pat.file, 'pattern', 'coeff');
		else
  	save(pat.file, 'pattern');
	end
  closeFile(pat.file);
end % subj
