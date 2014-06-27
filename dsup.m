% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
%
% Update a variable in the ds struct, and force it to be saved
% the next time dssave is called.  
%
% Ideally, any piece of code of the following form:
%
% ds.[expr1] = [expr2]
%
% where [expr1] references a variable in dswork, saved or not, the 
% following code will have exactly the same effect, except the changes 
% will be written to disk at the next call to dssave:
%
% dsup('ds.[expr1]',[expr2]);
%
% In practice, there are restrictions on the form of [expr1] because
% this code was written in a limited amount of time.  [expr1] is
% expected to be a simple struct reference (i.e. 'ds.[expr3]') or a simple
% struct reference followed by a cell index (i.e. 'ds.[expr3]{[expr4]}'), where [expr3] is
% a series of valid variable names separated by dots (to designate a field of
% a struct), and [expr4] must evaluate to an array of integers.  
% it may reference variables in the caller workspace, but the end keyword 
% is not supported. Note that extra whitespace is not handled outside of expr4, nor 
% is 2d array indexing.
%
% You should usually avoid using this function in your code; it's more provided
% as a convenience for manipulating the state of dswork from the command line.
% In distributed code, it's usually a bad idea to ever update variables on disk
% (especially if they're small enough to fit in memory), since it will prevent
% you from re-running things when they fail.
%
function dsup(ds_matchstr,ds_src)
global ds
evalin('caller',[ds_matchstr '=ds_src;']);
if(sum(ds_matchstr=='{')>0)
  ds_brakpos=find(ds_matchstr=='{');
  ds_idxstr=ds_matchstr((ds_brakpos(1)+1):(end-1));
  ds_matchstr=ds_matchstr(1:(ds_brakpos-1));
  ds_brakidx=evalin('caller',['[' ds_idxstr ']']);
else
  ds_brakidx=[];
end

%dssplitmatchstrscript;
%[ds_targ ds_brakidx]=dssplitmatchstr(ds_targ);
ds_dotpos=find(ds_matchstr=='.');
ds_pfx=ds_matchstr(1:(ds_dotpos(1)-1));
ds_sfx=[ds.sys.currpath ds_matchstr((ds_dotpos(1)):end)];
ds_toks=regexp(ds_matchstr,'\.','split');
ds_toks=ds_toks(2:end);
if(dsfield(ds,ds_toks{:}))
  if((~isempty(ds_brakidx))&&dsfield(ds,[ds_pfx '.sys.savestate' ds_sfx])&&(~isempty(eval([ds_pfx '.sys.savestate' ds_sfx]))))
    eval([ds_pfx '.sys.savestate' ds_sfx '{2}(ds_brakidx)=false;']);
  else
    if(dsfield(ds,['sys.savestate',ds_sfx]))
      if(eval(['iscell(' ds_pfx '.sys.savestate' ds_sfx ')']))
        eval([ds_pfx '.sys.savestate' ds_sfx '={};']);
      else
        eval([ds_pfx '.sys.savestate' ds_sfx '=[];']);
      end
    end
  end
end
