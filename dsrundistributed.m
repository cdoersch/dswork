% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
%
% run a matlab command in parallel. I.e. maps jobs to processors and
% collects the results back on disk, to be read by the main thread.
%
% mapvars specifies variables within dswork whose data should be mapped to
% workers, or it can simply be a number specifying the number of jobs to
% run.  Each variable specified as a map variable must contain the
% same number of elements n, and the code specified in command will be
% then run n times. There are no restrictions on what this code can be;
% the workers are independent matlab processes that do not share workspaces
% with the main thread. The only sharing that happens with the main thread
% happens through disk, and is automated by the dswork abstraction.  When
% a worker begins working on a job, its workspace will contain two things:
% 
%   - dsidx: a variable specifying which of then indexes in the mapvars the
%            worker should work on.  By default it is just a single number.
%
%   - ds: a clone of the ds struct from the main thread, pointing to the
%         same working directory as the main thread.
%
% The ds has a copy of the savestate from the main workspace--thus, it knows
% what variables are on disk and their types, and so dsload should allow you
% to load anything that's in the ds of the main workspace.  Some things are
% loaded automatically:
%
%    - ds.conf and all subfields.  Note that this path is relative; if you are
%      dscd'd into another directory, that directory's conf gets loaded.
%
%    - all variables specified in mapvars; if any variable specified in mapvars
%      is a cell array, these variables are only loaded for the index(es) specified
%      in dsidx; for ordinary arrays, the entire array is loaded.
%
% Upon completion of the job, the mapvars get cleared, as well as any variables that
% were created in the ds structure (after they've been saved, of course).  Any
% variables loaded during the job will stay in memory on that machine until you clear 
% them explicitly, or until the entire session is complete.
%
% Any variables saved from the workers are mirrored in the main workspace
% after dsrundistributed returns.  
%
% Input args:
%
% command: a command to be run.
%
% mapvars: a string or cell array of strings where each string is the absolute or 
%          relative path to a variable, or an integer.  The dswork variables that
%          these strings point to can be either a cell array or an
%          ordinary array.  command will be run once for every element of
%          these arrays (so the arrays must all have the same length), or if
%          mapvaris is an integer, it will be run the number of times specified.
%
% conf: a struct specifying additional configuration information.  Possible
%       fields can include:
%
%       noloadresults: do not load results in the main thread as they are 
%                      created (note that the internal savestate in the
%                      main thread will still be updated)
%
%       allatonce: if not present or set to 0, dsrundistributed will only assign
%                  a subset of jobs to workers at any given time, and dsidx
%                  will be a single number for each execution of command.  This
%                  allows dsrundistributed to dynamically balance the load--workers that
%                  finish jobs faster will be assigned more work.  setting allatonce=1
%                  means that all jobs are allocated simultaneously (each processor gets
%                  ceil(#jobs/#workers).  Each worker will execute the command exactly once,
%                  and dsidx will be an array containing every index assigned to that
%                  node.  Assignment is sequential; i.e. each node gets all of the jobs
%                  between some lower bound and some upper bound.
%
%       maxperhost: The maximum number of jobs that can be run concurrently on a single
%                   machine. 
%
%       forcerunset: use exactly this set of worker id's to run this job.
%
%
% 
% dsrundistributed displays progress during the execution: it displays the currently executing
% command followed by numbers formatted like x+y/z, where x is the number of complete jobs,
% y is the number of jobs that have been assigned but are not complete, and z is the total
% number of jobs to be assigned.  Finally, "working procs" is a list of workers that have
% jobs assigned to them.
%
% dsrundistributed makes some attempt at fault tolerance.  If a worker thread throws an exception,
% the exception will be reported in the main thread, and the job will be reassigned to a
% different worker.  Workers will be blacklisted if a job is assigned to them but they go for
% a very long time without accepting the job.  There is currently no mechanism to detect
% when a worker dies during the execution of a command.  
%
% Logfiles for each worker are stored in [ds.sys.outdir '/sys/distproc/output*.log'].  
%
% If you interrupt the execution, you will be prompted with options to stop execution,
% roll back the mapreduce, and to drop to a command line and run jobs locally.  This
% feature is experimental.
%
function dsrundist(command,mapvars,conf)
  global ds;
  if(~exist('conf','var'))
    conf=struct();
  end
  dsdistprocconf(conf);;
  dsdistprocmapvars(mapvars);

  ds.sys.distproc.command=command;
  dsresetdistproc;
  if(dsfield(conf,'forcerunset'))
     ds.sys.distproc.forcerunset=conf.forcerunset;
  end
  dsdistprocmgr(1);
end
