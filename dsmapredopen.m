% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
%
% Spawn a set of parallel workers.  njobs is the number of separate
% workers.  target is either the hostname of a machine where
% qsub may be run (this machine must have the output
% directory of dswork mounted), or it may be the string
% 'local', in which case the workers will be run on the current
% machine.  
%
% conf may include the following:
%
%   - qsubopts: any additional flags to pass to qsub.
%
%   - singleCompThread: a flag to tell matlab distributed workers to use
%                       only a single thread for computation.  Note
%                       that without this flag, each matlab can start a large number of
%                       threads, so running many of them at once can
%                       make you run out of threads in your userspace.
%
%   - runcompiled: a highly experimental flag allowing you to run with compiled
%                  code and an MCR.  This has worked in the past, but it has
%                  not been maintained.  Contact me if you would like to get
%                  it running again.
%
% You may need to rewrite this function to work on your cluster.
% The assumptions are (1) that ds.sys.outdir will point to a directory
% accessible to both the main thread and the distributed worker
% threads, (2) that filesystem should support sequential, close-to-open,
% or an equivalently strong consistency model, (3) that your filesystem supports
% fifo's (that only have to work within a single machine; most unix
% filesystems do) and (4) that it supports bash or an equivalent shell.  
% This function simply generates shell scripts and then qsub's them.
%
function dsmapredopen(njobs,target,conf)
  if(nargin<3)
    conf=struct();
  end
  %general setup; should not need to be modified.
  if(strcmp(target,'local'))
    submitlocal=1;
  else
    submitlocal=0;
  end
  if(dsfield(conf,'qsubopts'))
    qsubopts=conf.qsubopts;
  else
    qsubopts='';;
  end
  if(dsfield(conf,'runcompiled'))
    iscompiled=conf.runcompiled
  else
    %try
    %  dummy = which(mfilename)
    iscompiled=isdeployed;
    %  iscompiled=0;
    %catch
   %   iscompiled=1;
    %end
  end
  if(dsfield(conf,'chunksize'))
    chunksize=conf.chunksize;
  else
    chunksize=1;
  end
  if(~iscompiled)
    dsworkpath=mfilename('fullpath');
    dotpos=find(dsworkpath=='/');
    dsworkpath=dsworkpath(1:(dotpos(end)-1));
  end
  global ds;
  sysdir=[ds.sys.outdir 'ds/sys/'];
  mymkdir(sysdir);
  distprocdir=[ds.sys.outdir 'ds/sys/distproc/'];
  mymkdir(distprocdir);
  unix(['rm ' distprocdir '*']);
  ds.sys.distproc.nmapreducers=njobs;
  ds.sys.distproc.hostname=num2cell(char(ones(njobs,1,'uint8').*uint8('?')))';
  ds.sys.distproc.commlinkmaster=cell(njobs,1);
  ds.sys.distproc.commlinkslave=cell(njobs,1);
  ds.sys.distproc.progresslink=cell(njobs,1);
  ds.sys.distproc.allslaves=[];
  ds.sys.distproc.availslaves=[];
  ds.sys.distproc.possibleslaves=1:njobs;
  ds.sys.distproc.commfailures=zeros(ds.sys.distproc.nmapreducers,1);
  ds.sys.distproc.notresponding=[];
  ds.sys.distproc.nextserial=0;
  ds.sys.distproc.slavefinishedserial=zeros(ds.sys.distproc.nmapreducers,1)-1;
  dsgeninterruptor([distprocdir 'interruptor.sh'])

  for(i=1:njobs)
    ds.sys.distproc.commlinkmaster{i}=[distprocdir 'master' num2str(i) '.mat'];
    ds.sys.distproc.commlinkslave{i}=[distprocdir 'slave' num2str(i) '.mat'];
    ds.sys.distproc.progresslink{i}=[distprocdir 'progress' num2str(i)];
    ds.sys.distproc.commlinkinterrupt{i}=[distprocdir 'interrupt' num2str(i) '.mat'];
  end
  dssave();
  currchunk={};
  nchunks=1;
  for(i=1:njobs)
     %generate the script.
     disp(['submitting job ' num2str(i)]);
     tmpOutFName = [distprocdir 'qsubfile' num2str(i) '.sh'];
     fid = fopen(tmpOutFName, 'w');
     [~,nm]=unix('hostname');
     if(numel(strfind(nm,'teragrid'))>0&&dsfield(ds,'dispoutpath'))
       logfile=[ds.dispoutpath '/output' num2str(i) '.log']
     else
       %this should point to the matlab binary accessible on worker nodes.
       logfile=[distprocdir 'output' num2str(i) '.log'];
     end
     % begin writing the script that will be run via qsub. 
     mlpipe=[distprocdir '/mlpipe' num2str(i)];
     fprintf(fid, '%s\n',['#!/bin/bash'] );
     fprintf(fid, '%s\n',['cd "' pwd '";'] );
     fprintf(fid, '%s\n',['runtail=1;']);
     fprintf(fid, '%s\n',['if [[ ! -p ' mlpipe ' ]]; then']);
     fprintf(fid, '%s\n',['   if mkfifo "' mlpipe '"; then']);
     fprintf(fid, '%s\n',['     runtail=1']);
     fprintf(fid, '%s\n',['   else']);
     fprintf(fid, '%s\n',['     runtail=0']);
     fprintf(fid, '%s\n',['   fi']);
     fprintf(fid, '%s\n',['fi']);
     % on each worker, matlab is run with the fifo (mlpipe) as the STDIN that it reads commands from; this is the magic
     % that lets dscmd work.  Output is sent to a logfile.  
     if(iscompiled) % iscompiled is for running compiled in a particular mpi environment.  
       runnable = ['dplace -c ' num2str(i) ' ./dsmapreducerwrap ' num2str(i) ' "' ds.sys.outdir '" 1'];
       if(submitlocal)
         runnable = ['nice -n 15 ' runnable];
       end
     else
       if(submitlocal)
         matlabbin='nice -n 15 matlab';
       else
         %this should point to the matlab binary accessible on worker nodes.
         [~,matlabbin]=unix('which matlab');
         matlabbin=matlabbin(1:end-1);
       end
       sct='-nojvm';
       sct='-nojvm';
       if(dsbool(conf,'singleCompThread'))
         sct=['-singleCompThread ' sct];
       end
       %the actual command run in matlab once everything is set up.
       matlabcmd=['addpath(''' dsworkpath ''');dsmapreducerwrap(' num2str(i) ',''' ds.sys.outdir ''',1);']
       runnable = [matlabbin ' -nodesktop -nosplash ' sct ' -r "' matlabcmd '"'];
     end
     if(exist(mlpipe,'file'))
     else
       inputpipe=[];
     end
     fullcmd=[' ' runnable ' 2>&1 >> "' logfile '" &' ];
     fullcmd2=[' ' runnable ' 2>&1 < ' mlpipe ' >> "' logfile '" &' ];
     % note that this sh file is responsiible for dealing with dsmapredrestart
     % (as well as dealing with matlab crashing badly/segfaulting).  This while
     % loop simply runs matlab and, if its return code is nonzero, restart matlab.
     fprintf(fid, '%s\n',['rm ' logfile ]);
     fprintf(fid, '%s\n',['false;']);
     fprintf(fid, '%s\n',['while [ $? -gt 0 ]; do']);
     fprintf(fid, '%s\n',['if [ $runtail ]; then']);
     fprintf(fid, '%s\n',['   ' fullcmd2]);
     fprintf(fid, '%s\n',['   mypid=$!']);
     fprintf(fid, '%s\n',['   echo "a" > ' mlpipe]);
     fprintf(fid, '%s\n',['else']);
     fprintf(fid, '%s\n',['   ' fullcmd]);
     fprintf(fid, '%s\n',['   mypid=$!']);
     fprintf(fid, '%s\n',['fi']);
     %if(~iscompiled)
       fprintf(fid, '%s\n',['echo $mypid > ' distprocdir 'matpid' num2str(i) ]);
       fprintf(fid, '%s\n',['wait $mypid' ]);
       fprintf(fid, '%s\n',['done' ]);
       
       %fprintf(fid, '%s\n',['while kill -0 $mypid' ]);
       %fprintf(fid, '%s\n',['do' ]);
       %fprintf(fid, '%s\n',['  sleep 2s' ]);
       %fprintf(fid, '%s\n',['done' ]);

     fclose(fid);
     unix(['chmod 755 ' tmpOutFName]);
     % actually submit the jobs.  tmoOutFName is the actual script that needs to be run on each node.  In my case,
     % warp.hpc1.cs.cmu.edu was the root node of the cluster, which handled handled queueing for the cluster via
     % torque.
     if(submitlocal)
       unix(['sleep ' num2str(floor(i/2)) ' && ' tmpOutFName ' &']);
     else
       currchunk{end+1}=tmpOutFName;
       if(numel(currchunk)>=chunksize)
         submitchunk(currchunk,qsubopts,nchunks,target);
         nchunks=nchunks+1;
         currchunk={};
       end
     end
  end
  if(~isempty(currchunk))
    submitchunk(currchunk,qsubopts,nchunks,target);
  end
  ds.sys.distproc.isopen=1;
end
function submitchunk(chunk,qsubopts,chunkid,target)
      global ds;
      distprocdir=[ds.sys.outdir 'ds/sys/distproc/'];
      logfileerr=[distprocdir 'stderr' num2str(chunkid) '.log'];
      logfileout=[distprocdir 'stdout' num2str(chunkid) '.log'];
       logstring = ['-e "' logfileerr '" -o "' logfileout '"']; 
       if(numel(chunk)==1)
         submitScr=chunk{1};
       else
         submitScr=[distprocdir 'qsubchunk' num2str(chunkid) '.sh'];
         fid = fopen(submitScr, 'w');
         for(i=1:numel(chunk))
           fprintf(fid, '%s\n',[chunk{i} ' &'] );
         end
         fprintf(fid, '%s\n','wait;' );
         fclose(fid)
       end
       qsub_cmd=['source /etc/profile; qsub -V -N dsmapreducer' num2str(chunkid) ' ' qsubopts ' ' logstring ' ' submitScr]
       ssh_cmd = sprintf(['ssh ' target ' ''%s'''], qsub_cmd)
       unix(ssh_cmd);
end
