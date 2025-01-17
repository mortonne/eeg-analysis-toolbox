function new_pattern = cont2seg(pattern, pat_size)

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

%reravel pattern back to its almost original size (eventsXtimeXchan)
new_pattern = reshape(pattern, pat_size(1), pat_size(3), pat_size(2));

%new_pattern = reshape(pattern, pat_size(3), pat_size(1), pat_size(2));

%make pattern eventsXchanXtime
new_pattern = permute(new_pattern, [1 3 2]);
%new_pattern = permute(new_pattern, [2 3 1]);

