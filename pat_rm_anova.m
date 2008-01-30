function eeg = pat_rm_anova(eeg, params, resDir, patname)
%
%PAT_RM_ANOVA - calculates a 2-way ANOVA across subjects, using two
%fields from the events struct as regressors
%
% FUNCTION: eeg = pat_rm_anova(eeg, params, resDir, patname)
%
% INPUT: eeg - struct created by init_iEEG or init_scalp
%        params - required fields: patname (specifies the name of
%                 which pattern in the eeg struct to use), fields
%                 (specifies which fields of the events struct to
%                 use as regressors)
%
%                 optional fields: eventFilter (specify subset of
%                 events to use), masks (cell array containing
%                 names of masks to apply to pattern)
%        resDir - 'stat' files are saved in resDir/data
%        patname - analysis name to save under in the eeg struct
%
% OUTPUT: new eeg struct with ana object added, which contains file
% info and parameters of the analysis
%

if ~exist('patname', 'var')
  patname = 'RMAOV2';
end
if ~isfield(params, 'fields')
  error('You must specify two fields to use as regressors');
end

params = structDefaults(params, 'eventFilter', '',  'masks', {});

if ~exist(fullfile(resDir, 'data'), 'dir')
  mkdir(fullfile(resDir, 'data'));
end

tot_events = 0;
for s=1:length(eeg.subj)
  subjpat(s) = getobj(eeg.subj(s), 'pat', params.patname);
  tot_events = tot_events + subjpat(s).dim.event.num;
end

% write all file info
pat.name = patname;
pat.file = {};

pat.dim.event.num = 4;
pat.dim.event.file = subjpat(1).dim.event.file;
pat.dim.event.label = {params.fields{1} params.fields{2} [params.fields{1} 'X' params.fields{2}] 'subject'};
pat.dim.chan = subjpat(1).dim.chan;
pat.dim.time = subjpat(1).dim.time;
pat.dim.freq = subjpat(1).dim.freq;
for c=1:length(chan)
  pat.file{c} = fullfile(resDir, 'data', [patname '_chan' num2str(chan(c).number) '.mat']);
end
pat.params = params;

% update the eeg struct
eeg = setobj(eeg, 'pat', pat);
save(fullfile(eeg.resDir, 'eeg.mat'), 'eeg');

fprintf(['\nStarting Repeated Measures ANOVA:\n']);

% step through channels
for c=1:length(chan(c).number)
  fprintf('\nLoading patterns for channel %d: ', chan(c).number);
  
  if ~lockFile(pat.file{c})
    continue
  end
  
  chan_pats = NaN(tot_events, length(pat.dim.time), length(pat.dim.freq));
  tempsubj_reg = [];
  tempgroup = cell(1,length(params.fields));
  
  % concatenate subjects
  for s=1:length(eeg.subj)
    fprintf('%s ', eeg.subj(s).id);
    
    [pattern, events] = loadPat(subjpat.file, params.masks, subjpat.dim.event.file, params.eventFilter);
    
    for i=1:length(params.fields)
      tempgroup{i} = [tempgroup{i}; getStructField(events, params.fields{i})'];
    end
    
    tempsubj_reg = [tempsubj_reg; ones(size(pattern,1),1)*s];
    chan_pats = cat(1, chan_pats, squeeze(pattern(:,c,:,:)));
  end
  fprintf('\n');
  
  % initialize the stat struct
  fprintf('ANOVA: ');
  pattern = NaN(tot_events, length(pat.dim.time), length(pat.dim.freq));
  
  for t=1:size(chan_pats,2)
    fprintf(' %s ', subjpat.dim.time(t).label);
    
    for f=1:size(chan_pats,3)
      if ~isempty(pat.dim.freq)
	fprintf('%s ', subjpat.dim.freq(f).label);
      end
      
      % remove NaNs
      thispat = squeeze(chan_pats(:,t,f));
      good = ~isnan(thispat);
      if length(good)==0
	continue
      end
      thispat = thispat(good);
      for i=1:length(tempgroup)
	group{i} = tempgroup{i}(good);
	vals = unique(group{i});
	for j=1:length(vals)
	  group{i}(group{i}==vals(j)) = j;
	end
      end
      subj_reg = tempsubj_reg(good);
      
      % fix the subject regressor numbers
      subjs = unique(subj_reg);
      for s=1:length(subjs)
	subj_reg(subj_reg==subjs(s)) = s;
      end
      
      % do a two-way rm anova
      p = RMAOV2_mod([thispat group{1} group{2} subj_reg], 0.05, 0);
      for e=1:length(p)
	pattern(e,1,t,f) = p(e);
      end
      
      % if two cats, get the direction of the effect
      for e=1:2
	cats = unique(group{e});
	if length(cats)==2
	  if mean(thispat(group{e}==cats(1))) < mean(thispat(group{e}==cats(2)))
	    pattern(e,1,t,f) = -pattern(e,1,t,f);
	  end
	end
      end
      
    end % freq
    if ~isempty(pat.dim.freq)
      fprintf('\n');
    end
  end % bin
  fprintf('\n');
  
  save(pat.file{c}, 'pattern');
  releaseFile(pat.file{c});
end % channel


