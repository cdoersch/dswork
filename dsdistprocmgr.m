% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
%
% Manages a distributed processing session.  The style of this
% file (and related files) is very strange because I assume that 
% the execution can be interrupted at any point, which means we'll 
% suddenly be in an oncleanup handler and everything except global 
% variables will be gone.  Hence any data that needs to persist 
% even for a short time gets written to ds.sys.distproc.  Add to
% that the fact that the current functionality is completely different
% (and 10x more useful) than my original plan, and this file is a mess.
% Good luck reading it.
%
function dsdistprocmgr(startfresh)
  try
  global ds;
  global ds_nocatch;
  if(~startfresh)
    writepending();
  end
  if(isfield(ds.sys.distproc,'mapredreducevars'))
    %this was set by dsruncommand() to make us behave like a worker.  
    %Unset it so we'll run like a distproc manager.
    ds.sys.distproc=rmfield(ds.sys.distproc,'mapredreducevars');
  end
  ds.sys.distproc.rollbackdirs=[];
  ds_nocatch=false;
  ds.sys.distproc.interruptexiting=false;
  if(~dsmapredisopen())
    for(i=1:50)
      cleaners{i}=onCleanup(@handleinterrupt);
    end
    jobsbyround=ds.sys.distproc.jobsinq;
    if(ds.sys.distproc.allatonce)
      jobsbyround=jobsbyround';
    end
    ct=0;
    for(i=jobsbyround)
      runjoblocal(i);
      ct=ct+1;
      disp([ds.sys.distproc.command ': ' num2str(ct) '/' num2str(numel(jobsbyround))]);
    end
    ds.sys.distproc.interruptexiting=true;
    return;
  end
  if(startfresh)
    warning off all;
    for(i=1:ds.sys.distproc.nmapreducers)
      readslave(i,false,ds.sys.distproc.loadresults,false); %to pick up newly started mapreducers
      delete([ds.sys.distproc.progresslink{i} '_*']);
    end
    warning on all;
  end

  %if(~dsbool(ds.sys.distproc,'reducemodulo')&&dsbool(ds.sys.distproc,'mapreducing'))
  %  ds.sys.distproc.reducemodulo=numel(ds.sys.distproc.availslaves);
  %  ds.sys.distproc.forcerunsetlater=ds.sys.distproc.availslaves;
  %end

  if(dsfield(ds.sys.distproc,'forcerunset'))
    myslaves=ds.sys.distproc.forcerunset;
  else
    myslaves=ds.sys.distproc.availslaves;
  end
  %if(isfield(ds.sys.distproc,'maxperhost'))
  %  hostidx=ismember(ds.sys.distproc.hostname(myslaves),unique(ds.sys.distproc.hostname));
  %  ct=zeros(1,max(hostidx));
  %  flag=false(size(hostidx));
  %  for(i=1:numel(hostidx))
  %    if(ct(hostidx(i))<=ds.sys.distproc.maxperhost)
  %      ct(hostidx(i))=ct(hostidx(i))+1;
  %    else
  %      flag(i)=true;
  %    end
  %  end
  %  myslaves(flag)=[];
  %end
  scmd.savestate=ds.sys.savestate;
  scmd.currpath=ds.sys.currpath;
  scmd.matlabpath=path;
  if(dsfield(ds.sys.distproc,'localdir'))
    scmd.localdir=ds.sys.distproc.localdir;
  else
    scmd.localdir='';
  end
  %cmd.matlabpath=path;
  %cmd.reducemodulo=ds.sys.distproc.reducemodulo;
  %cmd.reducehosts=ds.sys.distproc.hostname(myslaves);
  if(~dsfield(ds.sys.distproc,'reducevars'))
    ds.sys.distproc.reducevars={};
  end
  if(~dsfield(ds.sys.distproc,'mapvars'))
    ds.sys.distproc.mapvars={};
  end
  %cmd.clearlocaldir=0;%isempty(ds.sys.distproc.reducevars);
  %save([ds.sys.outdir 'ds/sys/distproc/savestate.mat'],'cmd','-v7.3');
  runthisround=[];
  for(i=1:50)
    cleaners{i}=onCleanup(@handleinterrupt);
  end
  while((numel(ds.sys.distproc.jobsinq)+size(ds.sys.distproc.jobsproc,2))>0)
    sjp=sum(ds.sys.distproc.jobprogress);%ds.sys.distproc.njobs-size(ds.sys.distproc.jobsproc,2)-numel(ds.sys.distproc.jobsinq);
    disp([ds.sys.distproc.command ': ' num2str(sjp)...
          '+' num2str(ds.sys.distproc.njobs-numel(ds.sys.distproc.jobsinq)-sjp) '/' num2str(ds.sys.distproc.njobs)]);
    if(sjp<0 || ds.sys.distproc.njobs-numel(ds.sys.distproc.jobsinq)-sjp<0)
      keyboard
    end
    wait=1;
    if(ds.sys.distproc.allatonce)
      [~,idx]=ismember(ds.sys.distproc.hostname(setdiff(ds.sys.distproc.possibleslaves,ds.sys.distproc.hdead)),unique(ds.sys.distproc.hostname));
      totalprocs=sum(min(histc(idx,1:numel(unique(ds.sys.distproc.hostname))),ds.sys.distproc.maxperhost));
      jobsthisround=ceil(numel(ds.sys.distproc.jobsinq)/totalprocs);
    else
      jobsthisround=ceil(numel(ds.sys.distproc.jobsinq)/(2*(numel(ds.sys.distproc.possibleslaves)-numel(ds.sys.distproc.hdead))));
    end
    if(isnan(jobsthisround))
      disp('all mapreducers are dead')
      return;
    end
    toread=setdiff(ds.sys.distproc.possibleslaves,ds.sys.distproc.notresponding);
    toread2=[];
    for(k=[1 5 3 7 2 6 4 8])
      toread2=[toread2 toread(k:8:end)];
    end
    for(i=toread2(:)')
      readslave(i,1,ds.sys.distproc.loadresults,false);
    end
    allocated=zeros(size(ds.sys.distproc.idleprocs));
    idleprocsidx=1;
    %'idleprocs'
    %ds.sys.distproc.idleprocs
    if(dsfield(ds.sys.distproc,'forcerunset'))
      myslaves=ds.sys.distproc.forcerunset;
      ds.sys.distproc.idleprocs=intersect(ds.sys.distproc.forcerunset,ds.sys.distproc.idleprocs);
    else
      myslaves=ds.sys.distproc.availslaves;
    end
    workingprocs=setdiff(setdiff(myslaves,ds.sys.distproc.idleprocs),ds.sys.distproc.hdead);
    if(dsbool(ds.sys.distproc,'waitforstart')&&numel(ds.sys.distproc.availslaves)~=numel(ds.sys.distproc.possibleslaves)-numel(ds.sys.distproc.notresponding))
      disp(['waiting for ' num2str(numel(ds.sys.distproc.possibleslaves)-numel(ds.sys.distproc.availslaves)-numel(ds.sys.distproc.notresponding)) ' procs to start']);
      loaduntiltimeout(3);
      continue;
    end

    if(~dsbool(ds.sys.distproc,'reducemodulo')&&dsbool(ds.sys.distproc,'mapreducing'))
      if(dsfield(ds.sys.distproc,'forcerunset'))
        ds.sys.distproc.reducemodulo=numel(ds.sys.distproc.forcerunset);
        ds.sys.distproc.forcerunsetlater=ds.sys.distproc.forcerunset;
        myslaves=ds.sys.distproc.forcerunset;
      else
        ds.sys.distproc.reducemodulo=numel(ds.sys.distproc.availslaves);
        ds.sys.distproc.forcerunsetlater=ds.sys.distproc.availslaves;
        myslaves=ds.sys.distproc.availslaves;
      end
    end
    if(exist('scmd','var'))
      scmd.reducehosts=ds.sys.distproc.hostname(myslaves);
      dstrysave([ds.sys.outdir 'ds/sys/distproc/savestate.mat'],scmd,'-v7.3');
      clear scmd;
    end
    disp(['working procs: ' num2str(workingprocs(:)')]);
    disp([num2str(numel(ds.sys.distproc.idleprocs)) ' idle.']);
    %ds.sys.distproc.jobprogress(max(ds.sys.distproc.jobsinq)+1)=0;
    if(any(ds.sys.distproc.jobprogress(ds.sys.distproc.jobsinq)))
      keyboard;
    end
    for(i=ds.sys.distproc.idleprocs(:)')
      if(numel(ds.sys.distproc.jobsinq)>0)
        %[~,uhostind]=ismember(ds.sys.distproc.hostnames(i),ds.sys.distproc.uniquehosts);
        if(numel(getrunningperhost(ds.sys.distproc.hostname{i}))>=ds.sys.distproc.maxperhost)
          idleprocsidx=idleprocsidx+1;
          continue;
        end
        cmd=struct();
        cmd.name='run';
        cmd.cmd=ds.sys.distproc.command;
        cmd.reducevars=ds.sys.distproc.reducevars;
        if(~dsfield(ds.sys.distproc,'forcerunset'))
          badids=ds.sys.distproc.donotassociate(1,find(ds.sys.distproc.donotassociate(2,:)==i));
  %        avail=ds.sys.distproc.jobsinq(
          availjiqidx=find(~ismember(ds.sys.distproc.jobsinq,sort(badids)));
          availjiqidx=availjiqidx(1:min(numel(availjiqidx),jobsthisround));
        else
          [~,modval]=ismember(i,ds.sys.distproc.forcerunset);
          availjiqidx=find(mod(ds.sys.distproc.jobsinq-1,numel(ds.sys.distproc.forcerunset))+1==modval);
        end
        cmd.inds=ds.sys.distproc.jobsinq(availjiqidx);
        if(numel(cmd.inds)==0)
          idleprocsidx=idleprocsidx+1;
          continue;
        end
        cmd.mapredin=ds.sys.distproc.mapvars2;;
        cmd.mapvars=ds.sys.distproc.mapvars;
        cmd.hostname=unique(ds.sys.distproc.hostname);
        % cmd.mapredout=reducevars;
        cmd.allatonce=ds.sys.distproc.allatonce;
        cmd.clearslaves=~ds.sys.distproc.hascleared(i);
        %if(~hascleared(i))%~ismember(i,runthisround))
        %  cmd.clearslaves=true;
          %runthisround=[runthisround,i];
        %else
        %  cmd.clearslaves=false;
        %end
        cmd.serial=ds.sys.distproc.nextserial;
        if(numel(cmd.inds)==0)
          keyboard;
        end
        ds=prepjob_atomic(ds,ds.sys.distproc.commlinkslave{i},cmd,availjiqidx,i);
        if(any(ds.sys.distproc.jobprogress(ds.sys.distproc.jobsinq)))
          keyboard;
        end
        writepending();
        nidleprocs=setdiff(setdiff(ds.sys.distproc.availslaves,ds.sys.distproc.idleprocs),ds.sys.distproc.hdead);
        if(any(~ismember(nidleprocs,ds.sys.distproc.jobsproc(2,:))))
          keyboard
        end
        %allocated(idleprocsidx)=1;
        %ds.sys.distproc.runningperhost{uhostind}=[ds.sys.distproc.runningperhost{uhostind} i];
      end
      idleprocsidx=idleprocsidx+1;
    end
    if((numel(ds.sys.distproc.jobsinq)+size(ds.sys.distproc.jobsproc,2))==0)
      wait=0;
    end
    if(wait)
      loaduntiltimeout(3);
    end
    clearslaves=false;
  end
  %for(i=1:numel(reducevars))
  %  disp(['var:' reducevars{i}]);
  %  disp('loading savestate');
  %  dsloadsavestate(reducevars{i});
  %  if(loadresults)
  %    disp('loading results');
  %    dsload(reducevars{i});
  %  end
  %end
  disp('loading final results...');
  loaduntiltimeout(Inf);
  ds.sys.distproc.interruptexiting=true;
  %loaduntiltimeout(Inf,reducevars2);
  delete([ds.sys.outdir 'ds/sys/distproc/savestate.mat']);
  catch ex
    global ds_nocatch;
    if(ds_nocatch)
      rethrow(ex);
    end
    dsprinterr;
  end
end

function runjoblocal(i)
    global ds;

    if(dsfield(ds,'sys','distproc','reducevars'))
      ds.sys.distproc.mapredreducevars=ds.sys.distproc.reducevars;
    end
    mapvars2=ds.sys.distproc.mapvars2;
    fwascleared=false(max(i),numel(mapvars2));
    %for(j=1:numel(mapvars2))
    %  try
    %    sz=eval(['numel(' dsfindvar(mapvars2{j}) ');']);
    %  catch
    %    sz=0;
    %  end
    %  for(thisi=i(:)')
    %    if(thisi>sz||(eval(['iscell(' dsfindvar(mapvars2{j}) ')']) && isempty(eval([dsfindvar(mapvars2{j}) '{' num2str(thisi) '}']))))
    %      fwascleared(thisi,j)=true;
    %      dsload([mapvars2{j} '{' num2str(thisi) '}']);
    %    end
    %  end
    %end
    for(j=1:numel(mapvars2))
      mapredinexp=dsexpandpath(mapvars2{j})
      %mycmd.mapredin{j}
      %ds.sys.savestate
      for(l=1:numel(mapredinexp))
        fmatch=0;
        for(k=1:numel(ds.sys.distproc.mapredreducevars))
          if(dspathmatch(mapredinexp{l},ds.sys.distproc.mapredreducevars{k}))
            dimstrsz=dssavestatesize(ds.sys.distproc.mapredreducevars{k},2);%here we assume that it's only going to match other reducevars
            dimstr=['{1:' num2str(dimstrsz) '}']
            dsload([mapredinexp{l} '{' num2str(i) '}' dimstr]);
            fmatch=1;
          end
        end
        if(~fmatch)
          dsload([mapredinexp{l} '{' num2str(i) '}']);
        end
      end
    end

    dsmapredrun(ds.sys.distproc.command,i);
      %TODO:dsfinishjob
      dssave;
      %for(j=1:numel(mapvars2))
      %  for(thisi=i(:)')
      %    if(fwascleared(thisi,j))
      %      dsclear([mapvars2{j} '{' num2str(thisi) '}']);
      %    end
      %  end
      %end
end

function ds=prepjob_atomic(ds,filenm,cmd,availjiqidx,i)
  ds.sys.distproc.jobsinq(availjiqidx)=[];
  if(numel(cmd.inds)==0)
    disp('inds cannot be empty');
    error('inds cannot be empty');
  end
  ds.sys.distproc.jobsproc=[ds.sys.distproc.jobsproc [cmd.inds(:)'; ones(1,numel(cmd.inds))*i]];
  ds.sys.distproc.assignmentlog=[ds.sys.distproc.assignmentlog [cmd.inds(:)'; ones(1,numel(cmd.inds))*i]];
  ds.sys.distproc.idleprocs(ds.sys.distproc.idleprocs==i)=[];
  ds.sys.distproc.pendingwrite.fnam=filenm;
  ds.sys.distproc.pendingwrite.cmd=cmd;
  ds.sys.distproc.nextserial=cmd.serial+1;
  ds.sys.distproc.hascleared(i)=true;
end

function writepending()
  global ds;
  if(dsfield(ds.sys.distproc,'pendingwrite'))
    cmd=ds.sys.distproc.pendingwrite.cmd;
    save(ds.sys.distproc.pendingwrite.fnam,'cmd');
    %if we get interrupted here, we may write twice, hence the serial number.
    ds.sys.distproc=rmfield(ds.sys.distproc,'pendingwrite');
  end
end

function gotinterrupt=readslave(idx,isrunning,loadresults,handlinginterrupt)
  global ds;
  [ds, gotinterrupt]=readslave_atomic(ds,idx,isrunning,loadresults,handlinginterrupt);
  while(numel(ds.sys.distproc.filestodelete)>0)
    delete(ds.sys.distproc.filestodelete{1});
    ds.sys.distproc.filestodelete(1)=[];
  end
end

function [ds, gotinterrupt] = readslave_atomic(ds,idx,isrunning,loadresults,handlinginterrupt)
  try
  gotinterrupt=false;
  maxprogress=Inf;
  if(~dsfield(ds.sys.distproc,'filestodelete'))
    ds.sys.distproc.filestodelete={};
  end
  %if(handlinginterrupt)
  %  interrupt=dstryload(ds.sys.distproc.commlinkinterrupt{idx});
  %  if(~isempty(interrupt))
  %    gotinterrupt=true;
  %  end
  %  if(~interrupt.wrotemaster && exist(ds.sys.distproc.commlinkmaster{idx},'file'))
  %    ds.sys.distproc.filestodelete{end+1}=ds.sys.distproc.commlinkmaster{idx};
  %  end
  %  maxprogress=interrupt.maxprogress;
  %end
  if(exist(ds.sys.distproc.commlinkmaster{idx},'file') && ~ismember(ds.sys.distproc.commlinkmaster{idx},ds.sys.distproc.filestodelete))
    iserror=0;
    %while(iserror>=0)
    %  if(iserror>0)
        %pause(1)
    %    return;
    %  end
      try
        load(ds.sys.distproc.commlinkmaster{idx});
        %if(~exist('cmd','var'))
        %  iserror=iserror+1;
        %else
        %  iserror=-1;
        %end
      catch ex
        dsstacktrace(ex)
        return
        %iserror=iserror+1;
        %if(iserror==10)
        %  error(['Unable to read mapreducer communication in file ' ds.sys.distproc.commlinkmaster{idx}]);
        %end
      end

      if(~exist('cmd','var'))
        disp(['loaded '  ds.sys.distproc.commlinkmaster{idx} ' but found nothing there']);
        keyboard
      end
    gotinterrupt=dsbool(cmd,'camefrominterrupt');
    if(isfield(cmd,'serial') && ds.sys.distproc.slavefinishedserial(idx)==cmd.serial)
      ds.sys.distproc.filestodelete{end+1}=ds.sys.distproc.commlinkmaster{idx};
      return;
    end
    if(isfield(cmd,'serial'))
      ds.sys.distproc.slavefinishedserial(idx)=cmd.serial;
    end
    %end
    %if(iserror==-1)
      if(isrunning||strcmp(cmd.name,'started'))
        ds.sys.distproc.filestodelete{end+1}=ds.sys.distproc.commlinkmaster{idx};
      end
      if(strcmp(cmd.name,'started'))
        %if(~ismember(idx,ds.sys.distproc.idleprocs))
        %  ds.sys.distproc.idleprocs=[ds.sys.distproc.idleprocs idx];
        %end
        %if(~ismember(idx,ds.sys.distproc.idleprocs))
        %  ds.sys.distproc.availprocs=[ds.sys.distproc.availprocs idx];
        %end
        if(ismember(idx,ds.sys.distproc.availslaves))
            %try
            %error('mapreducer started that was already available');
            %catch ex; dsprinterr;end
            disp(['mapreducer ' num2str(idx) ' started that was already available']);
            keyboard
        end
        delete([ds.sys.distproc.progresslink{idx} '_' num2str(ds.sys.distproc.nextfile(idx)) '.mat']);
        ds.sys.distproc.hascleared(idx)=false;
        ds.sys.distproc.allslaves=unique([ds.sys.distproc.allslaves idx]);
        ds.sys.distproc.idleprocs=unique([ds.sys.distproc.idleprocs idx]);
        ds.sys.distproc.availslaves=unique([ds.sys.distproc.availslaves idx]);
        ds.sys.distproc.hostname{idx}=cmd.host;
        myincompjobs=find(ismember(ds.sys.distproc.jobsproc(2,:),idx));
        compjobs=myincompjobs(find(ds.sys.distproc.jobprogress(myincompjobs)));
        myincompjobs=setdiff(myincompjobs,compjobs);
        ds.sys.distproc.donotassociate=[ds.sys.distproc.donotassociate ds.sys.distproc.jobsproc(:,myincompjobs)];
        ds.sys.distproc.jobsinq=[ds.sys.distproc.jobsproc(1,myincompjobs) ds.sys.distproc.jobsinq];
        ds.sys.distproc.jobsproc(:,[myincompjobs(:)' compjobs(:)'])=[];
        ds.sys.distproc.jobprogress(myincompjobs)=0;
        ds.sys.distproc.nextfile(idx)=1;
        %if(~ismember(cmd.host,ds.sys.distproc.uniquehosts))
        %  ds.sys.distproc.uniquehosts{1,end+1}=cmd.host;
          %ds.sys.distproc.runningperhost{1,end+1}=[];
        %end
      elseif(strcmp(cmd.name,'interrupted'))
        gotinterrupt=true;
        maxprogress=cmd.maxprogress;
        for(i=1:size(cmd.createddirs,1))
          if(~ismember(cmd.createddirs{i,1},{ds.sys.distproc.createddirs.var}))
            ds.sys.distproc.rollbackdirs=[ds.sys.distproc.rollbackdirs;cmd.createddirs(i,:)];
          end
        end
        ds.sys.distproc.idleprocs=unique([idx ds.sys.distproc.idleprocs]);
      elseif(strcmp(cmd.name,'done'))
          if(~isrunning)%&&numel(ds.sys.distproc.idleprocs)>numel(ds.sys.distproc.availslaves))
            try
            error('found something still running!  Run dinterrupt to stop it...');
            catch ex; dsprinterr;end
          end
        ds.sys.distproc.idleprocs=[idx ds.sys.distproc.idleprocs];
          if(numel(ds.sys.distproc.idleprocs)~=numel(unique(ds.sys.distproc.idleprocs)))%&&numel(ds.sys.distproc.idleprocs)>numel(ds.sys.distproc.availslaves))
            try
            error('idleprocs is redundant');
            catch ex; dsprinterr;end
          end
        jpjid=unique(ds.sys.distproc.jobsproc(2,ismember(ds.sys.distproc.jobsproc(1,:),cmd.completed)));
        if(numel(jpjid)>1)
          keyboard;
        end
        if(numel(ds.sys.distproc.jobsproc(2,ismember(ds.sys.distproc.jobsproc(1,:),cmd.completed)))~=sum(ds.sys.distproc.jobsproc(2,:)==jpjid))
          keyboard;
        end
        ds.sys.distproc.jobsproc(:,ismember(ds.sys.distproc.jobsproc(1,:),cmd.completed))=[];
        if(isrunning)
          %[~,uhostind]=ismember(ds.sys.distproc.hostnames(i),ds.sys.distproc.uniquehosts);
          %ds.sys.distproc.runningperhost{uhostind}(ds.sys.distproc.runningperhost{uhostind}==idx)=[];
          ds=handlewritten(ds,cmd.savedthisround,cmd.completed,loadresults);
        end
        gotcompletion=cmd.completed;
      elseif(strcmp(cmd.name,'exited'))
        ds.sys.distproc.availslaves(ds.sys.distproc.availslaves==idx)=[];
      elseif(strcmp(cmd.name,'error'))
        if(~isrunning)%&&numel(ds.sys.distproc.idleprocs)>numel(ds.sys.distproc.availslaves))
          error('found something still running!  Run dinterrupt to stop it...');
        end
        disp(['job no. ' num2str(cmd.errind) ' crashed on mapreducer ' num2str(idx) ', host ' ds.sys.distproc.hostname{idx}]);
        ds.sys.distproc.hcrashct(idx)=ds.sys.distproc.hcrashct(idx)+1;
        if(ds.sys.distproc.hcrashct(idx)>=300)
          ds.sys.distproc.hdead=unique([ds.sys.distproc.hdead; idx]);
          disp(['mapreducer '  num2str(idx) ' has crashed twice in this mapreduce round. It will be disabled for the remainder of the round.']);
        else
          ds.sys.distproc.idleprocs=[ds.sys.distproc.idleprocs idx];
          if(isrunning&&numel(ds.sys.distproc.idleprocs)>numel(ds.sys.distproc.availslaves))
            disp('too many idle procs');
            keyboard;
          end
        end
        dsstacktrace(cmd.err,1);
        if(dsbool(ds,'conf','rethrowerrors'))
          global ds_nocatch;
          ds_nocatch=true;
          if(dsbool(ds,'conf','dumponerror'))
            unix(['find "' ds.sys.outdir '"']);
          end
          rethrow(cmd.err);
        end
        mycompjobs=ismember(ds.sys.distproc.jobsproc(1,:),cmd.completed);
        ds.sys.distproc.jobsproc(:,mycompjobs)=[];
        myincompjobs=ismember(ds.sys.distproc.jobsproc(2,:),idx);
        ds.sys.distproc.donotassociate=[ds.sys.distproc.donotassociate ds.sys.distproc.jobsproc(:,myincompjobs)];
        ds.sys.distproc.jobsinq=[ds.sys.distproc.jobsproc(1,myincompjobs) ds.sys.distproc.jobsinq];
        ds.sys.distproc.jobsproc(:,myincompjobs)=[];
        if(isrunning)
          %[~,uhostind]=ismember(ds.sys.distproc.hostnames(idx),ds.sys.distproc.uniquehosts);
          %ds.sys.distproc.runningperhost{uhostind}(ds.sys.distproc.runningperhost{uhostind}==idx)=[];
          ds=handlewritten(ds,cmd.savedthisround,cmd.completed,loadresults);
        end
      end
      %if(~isrunning)
        %if(exist(ds.sys.distproc.progresslink{idx}))
        %end
      %end
    %end
  end
  nidleprocs=setdiff(setdiff(ds.sys.distproc.availslaves,ds.sys.distproc.idleprocs),ds.sys.distproc.hdead);
  if(any(~ismember(nidleprocs,ds.sys.distproc.jobsproc(2,:))))
    keyboard
  end
  if(isrunning)
    cmd=struct();
    nreads=0;
    while((~isempty(cmd))&&exist([ds.sys.distproc.progresslink{idx} '_' num2str(ds.sys.distproc.nextfile(idx)) '.mat'],'file'))
      readfile = (maxprogress>=ds.sys.distproc.nextfile(idx));
      nreads=nreads+1;
      %if(nreads>1)
      %  disp('read two progresses on one round??')
      %  keyboard;
      %end
      if(~ismember([ds.sys.distproc.progresslink{idx} '_' num2str(ds.sys.distproc.nextfile(idx)) '.mat'],ds.sys.distproc.filestodelete))
        cmd=dstryload([ds.sys.distproc.progresslink{idx} '_' num2str(ds.sys.distproc.nextfile(idx)) '.mat'],struct('nowait',readfile,'delete',false));
      else
        cmd=[];
      end
      if(~isempty(cmd))
        ds.sys.distproc.filestodelete{end+1}=[ds.sys.distproc.progresslink{idx} '_' num2str(ds.sys.distproc.nextfile(idx)) '.mat'];
        ds.sys.distproc.nextfile(idx)=ds.sys.distproc.nextfile(idx)+1;
      end
      if(isrunning&&~isempty(cmd)&&readfile)
        ds=handlewritten(ds,cmd.savedthisround,cmd.completed,loadresults);
      end
    end
  else
    fils=dir([ds.sys.distproc.progresslink{idx} '_*']);
    if(any(~ismember({fils.name},ds.sys.distproc.filestodelete)))
      error('found something still running!  Run dinterrupt to stop it...');
    end
  end
  if(exist(ds.sys.distproc.commlinkslave{idx},'file'))
    ds.sys.distproc.commfailures(idx)=ds.sys.distproc.commfailures(idx)+1;
    if(ds.sys.distproc.commfailures(idx)>50)
      disp(['mapreducer ' num2str(idx) ', host ' ds.sys.distproc.hostname{idx} ' has stopped responding.  Sending it an exit signal'])
      ds.sys.distproc.notresponding=unique([ds.sys.distproc.notresponding; idx]);
      ds.sys.distproc.availslaves(ds.sys.distproc.availslaves==idx)=[];
      cmd.name='exit';
      dstrysave(ds.sys.distproc.commlinkslave{idx},cmd);
      
      myincompjobs=ismember(ds.sys.distproc.jobsproc(2,:),idx);
      ds.sys.distproc.jobsinq=[ds.sys.distproc.jobsproc(1,myincompjobs) ds.sys.distproc.jobsinq];
      ds.sys.distproc.jobsproc(:,myincompjobs)=[];
    end
  else
    ds.sys.distproc.commfailures(idx)=0;
  end
  nidleprocs=setdiff(setdiff(ds.sys.distproc.availslaves,ds.sys.distproc.idleprocs),ds.sys.distproc.hdead);
  if(any(~ismember(nidleprocs,ds.sys.distproc.jobsproc(2,:))))
    keyboard
  end
  if(exist('gotcompletion','var')&&idx==1)
    if(any(ds.sys.distproc.jobprogress(gotcompletion)==0))
      keyboard;
    end
  end
  if(size(ds.sys.distproc.jobsproc,2)~=numel(unique(ds.sys.distproc.jobsproc(1,:))))
    keyboard
  end
  catch ex,dsprinterr_noglobal;end
end

function res=getrunningperhost(hostname)
  global ds;
  mrinds=find(ismember(ds.sys.distproc.hostname,{hostname}));
  res=mrinds(ismember(mrinds,ds.sys.distproc.jobsproc(2,:)));
end

function ds=handlewritten(ds,saved,completed,loadresults)
  try
  ds.sys.distproc.jobprogress(completed)=1;
  for(i=1:size(saved,1))
    sv.var=saved{i,1};
    sv.inds=saved{i,2};
    sv.jid=saved{i,3};
    nm=dsabspath(saved{i,1});
    %for(j=1:numel(saved{i}))
    svnm=['ds.sys.savestate' nm(4:end)];
    %TODO: this needs to be rewritten to handle interrupts happening while we update the savestate/load queue
    if((~isstruct(sv.inds))&&(~iscell(sv.inds)))
      if((~isempty(sv.inds)))
        %for(j=1:size(sv.inds,1))
          %indstr=num2str(sv.inds(j,1));
         
        if(size(sv.inds,2)~=2)
          sv.inds=[ones(size(sv.inds(:))) sv.inds(:)];
            %indstr=[indstr ',' num2str(sv.inds(j,2))];
          %else
            %indstr=['1,' indstr];
        end
        %end
        
        if(~dsfield(svnm)||eval(['numel(' svnm ')<2'])||eval(['~all(size(' svnm '{2})>=max(sv.inds,[],1))']))
          eval([svnm '{2}(max(sv.inds(:,1)),max(sv.inds(:,2)))=false;'])
        end
        indstr=sub2ind(eval(['size(' svnm '{2})']),sv.inds(:,1),sv.inds(:,2));
        indstr=['[' num2str(indstr(:)') ']'];
        if(eval(['any(' svnm '{2}(' indstr ')==1)']))
          disp(['warning: mapreducer wrote a variable (' svnm ') that already existed??']);
        end
        %['ds.sys.savestate' nm(4:end) '{2}(' indstr ')=true;']
        %if(dsfield(['ds.sys.savestate' nm(4:end) '']));
        %  eval(['ds.sys.savestate' nm(4:end) '{2};']);
        %end
        %['ds.sys.savestate' nm(4:end) '{2}(' indstr ')=true;']
        %tic
        eval([svnm '{2}(' indstr ')=true;']);
        %toc
        eval([svnm '{1}=1;']);
        %eval(['ds.sys.savestate' nm(4:end) '{2};']);
      else
        eval([svnm '=true;']);
      end
    end
    %locnm=dsfindvar(nm);
    %if(~dsfield(locnm)||(eval(['numel(' locnm ')'])<j))
    %  eval([locnm '{' num2str(ds.sys.distproc.redsize) '}=[];']);
    %end
    if(isstruct(sv.inds)||iscell(sv.inds))
      pth=dsfindvar(sv.var);
      if(~dsfield(pth))
        eval([pth '=sv.inds;']);
      end
      %if(isfield(ds.sys.distproc.createddirs))
        if(~ismember(sv.var,{ds.sys.distproc.createddirs.var}))
          ds.sys.distproc.createddirs(end+1)=sv;
        end
      %else
      %  ds.sys.distproc.createddirs(1)=sv;
      %end
    elseif(loadresults&&~dsmatchesmapvar(sv.var))
      enqueue=struct('vars',{},'inds',{},'jid',{});;
      if(isempty(sv.inds))
          enqueue(end+1)=struct('vars',sv.var,'inds',[],'jid',sv.jid);
      else
        for(j=1:size(sv.inds,1))
          enqueue(end+1)=struct('vars',sv.var,'inds',sv.inds(j,:),'jid',sv.jid);
        end
      end
      ds.sys.distproc.loadqueue=[ds.sys.distproc.loadqueue;enqueue(:)];
      %TODO:should add new dirs to loaddone
    end
    %end
  end
  catch ex
    global ds_nocatch;
    if(ds_nocatch)
      rethrow(ex);
    end
    dsprinterr;
  end
end

function loaduntiltimeout(timeout)
  global ds;
  try
  a=tic;
  firstit=1;
  while(numel(ds.sys.distproc.loadqueue)>0)
      b=tic;
    lq=ds.sys.distproc.loadqueue;
    loadvar=lq(1).vars;
    idx=lq(1).inds;
    jid=lq(1).jid;
    [~,varidx]=ismember({loadvar},ds.sys.distproc.uniqueredvars);
    if(varidx==0)
      varidx=numel(ds.sys.distproc.uniqueredvars)+1;
      ds.sys.distproc.uniqueredvars{varidx}=loadvar;
      ds.sys.distproc.nloads(varidx)=0;
      ds.sys.distproc.totalloadtime(varidx)=0;
    end
    timespent=toc(a);
    if(~firstit&&(~isinf(timeout))&&((ds.sys.distproc.nloads(varidx)==0)||(ds.sys.distproc.totalloadtime(varidx)/ds.sys.distproc.nloads(varidx)+timespent>timeout)))
      break;
    end
    b=tic;
    firstit=0;
    varnm=dsabspath(loadvar);
    %disp(['dsload(''' varnm '{' num2str(idx) '}'')']);
    clear lq;
    loadstr=getvarstr(varnm,idx);
    sucval=false;
    try
      dsload(loadstr);
      sucval=true;
    catch ex
      dsstacktrace(ex);
      disp(['read failed.  deleting ' num2str(jid) ' and resubmitting']);
      lq=[ds.sys.distproc.loadqueue; ds.sys.distproc.loaddone];
      marks=false(size(lq));
      for(t=1:numel(lq))
        marks(t)=~isempty(intersect(lq(t).jid,jid));
      %  if(marks(t))
      %    dsdelete(getvarstr(lq(t).vars,lq(t).inds));
      %  end
      end
      [ds]=discard_atomic(ds,jid,marks,idx);
      handledeletion(lq(marks));
    end
    if(sucval)
      ds.sys.distproc.nloads(varidx)=ds.sys.distproc.nloads(varidx)+1;
      ds.sys.distproc.totalloadtime(varidx)=ds.sys.distproc.totalloadtime(varidx)+toc(b);
      ds=poploadqueue_atomic(ds);
      %lq=ds.sys.distproc.loadqueue;
      %if(numel(lq)>0)
      %  pending = [];
      %else
      %  pending=unique([lq.jid]);
      %end
      %ld=ds.sys.distproc.loaddone;
      %marks=false(size(ld));
      %tic
      %for(t=1:numel(ld))
      %  marks(t)=(~any(ismember(ld(t).jid,pending)));
      %end
      %toc
      %note: we're assuming that if a jid is in loaddone but isn't in the 
      %current loadqueue, it'll never show up there again.  This relies on
      %an underlying assumption that once a job is finished, everything that
      %job wrote will end up in the loadqueue all at once.  in practice, the
      %loadqueue should be organized by job, but meh, do that later.
      %...actually this doesn't matter anymore since loaddone never gets cleared.
      %ds.sys.distproc.loaddone(marks)=[];
    end
      disp(['load:' num2str(toc(b))]);
  end
  timeremaining=timeout-toc(a);
  if(~isinf(timeremaining)&&timeremaining>0)
    pause(timeremaining);
  end
  catch ex
    global ds_nocatch;
    if(ds_nocatch)
      rethrow(ex);
    end
    dsprinterr;
  end
end

function [ds,todelete]=discard_atomic(ds,jid,marks,idx);
  %TODO: shouldn't ds.sys.distproc.jobsproc change too?
  ds.sys.distproc.jobprogress(jid)=0;
  ds.sys.distproc.loaddone(marks((numel(ds.sys.distproc.loadqueue)+1):end))=[];
  ds.sys.distproc.loadqueue(marks(1:numel(ds.sys.distproc.loadqueue)))=[];
  ds.sys.distproc.jobsinq=[idx ds.sys.distproc.jobsinq];
end

function ds=poploadqueue_atomic(ds)
  ds.sys.distproc.loaddone=[ds.sys.distproc.loaddone;ds.sys.distproc.loadqueue(1)];
  ds.sys.distproc.loadqueue(1)=[];
end

function handleinterrupt(source)
  global ds;
  if(nargin==0)
    source='keyboard';
  end
  if(dsbool(ds.sys.distproc,'interruptexiting'))
    return;
  end
  switch source
    case 'keyboard'
      disp('Interrupted from keyboard!  Your options are:');
  end
  needchoice = true;
  while(needchoice)
    str='distributed computation';
    if(dsbool(ds.sys.distproc,'mapreducing'))
      str='mapreduce';
    end
    disp(['  [a]: Complete the ' str ' and return to the command line once finished.']);
    disp(['  [b]: Roll back the ' str '.']);
    disp(['  [c]: Stop the ' str ' and return to the command line, keeping any completed results.']);
    disp(['  [d]: Drop to an interactive shell to run jobs locally.']);
    disp(['  [e]: Return to the command line immediately, leaving the workers running.']);
    handlingmethod = input('choice>','s');
    if(ismember(handlingmethod, {'a','b','c','d','e'}))
      needchoice=false;
    else
      disp('Umm...that option wasn''t listed.  Your options are:')
    end

    switch handlingmethod
      case 'a'
        if(dsbool(ds.sys.distproc,'mapreducing'))
          dscompletemapreduce(0);
        else
          dsdistprocmgr(0);
        end
      case 'b'
        dsrollback();
      case 'c'
        dscancel();
      case 'd'
        dsinterpreter();
      case 'e'
        ds.sys.distproc.interruptexiting=true;
        return;
    end
  end
end

function dsinterpreter()
  global ds;
  str='distributed computation';
  if(dsbool(ds.sys.distproc,'mapreducing'))
    str='mapreduce';
  end
  disp('Welcome to the dswork distributed prompt.  Here are some useful commands:');
  disp(' - dsruncommand(dsidx): evaluate the command with index dsidx.');
  disp([' - dsrollback(): roll back the ' str ' and return']);
  disp([' - dscancel(): stop the ' str ' and return, keeping results']);
  disp(' - dsquit(): return to the commandline immediately.');
  disp([' - dscontinue(): finish the ' str '.']);
  disp(' - dscmd(command[, worker id list]): if workers have hit keyboard statements, this will have them execute command directly (restart workers by issuing dbquit).');
  disp(' - dshostforworker(worker id): get the hostname for this worker');
  while(~ds.sys.distproc.interruptexiting)
    terminated=false;
    try
    res={};
    while(~terminated)
      res{end+1} = input('ds>>','s');
      idx=strfind(res{end},'...');
      terminated = isempty(idx) || any(res{end}(idx(end)+3:end))==''''; % not quite right, but it'll catch most real usages of ...
    end
    res=[sprintf('%s\n',res{1:end-1}),res{end}];
    eval(res);
    catch ex,dsstacktrace(ex);end
  end
end

function dscontinue()
  dsdistprocmgr(0);
end

function dsruncommand(idx)
  global ds;
  if(dsfield(ds,'sys','distproc','reducevars')&&~isempty(ds.sys.distproc.reducevars))
    ds.sys.distproc.mapredreducevars=ds.sys.distproc.reducevars;
    hostid=ds.sys.distproc.forcerunset(mod(idx-1,numel(ds.sys.distproc.forcerunset))+1);
    ds.sys.distproc.reducehosts=ds.sys.distproc.hostname(ds.sys.distproc.forcerunset);
    workerhost=ds.sys.distproc.hostname{hostid};
    [~,hname]=unix('hostname');
    if(~strcmp(workerhost,hname(1:end-1))&&dsfield(ds.sys.distproc,'localdir'))
      for(i=1:numel(ds.sys.distproc.mapredreducevars))
        unix(['scp "' workerhost ':' ds.sys.distproc.localdir ds.sys.distproc.mapredreducevars{i}(2:end) '[]~*~' num2str(hostid) '.mat" ' ds.sys.distproc.localdir]);
        (['scp "' workerhost ':' ds.sys.distproc.localdir ds.sys.distproc.mapredreducevars{i}(2:end) '[]~*~' num2str(hostid) '.mat" ' ds.sys.distproc.localdir])
        keyboard
      end
    end
  end
  try
  runjoblocal(idx);
  catch ex,dsstacktrace(ex);end
end

function dshostforworker(id)
  global ds;
  disp(ds.sys.distproc.hostname{id});
end

function dsquit()
  global ds;
  ds.sys.distproc.interruptexiting=true;
end

function dsrollback()
  global ds;
  try
  dscancel();
  disp('deleting created files...')
  if(isfield(ds.sys.distproc,'loadqueue'))
    todel=ds.sys.distproc.loadqueue;
    if(isfield(ds.sys.distproc,'loaddone'))
      todel=[todel;ds.sys.distproc.loaddone];
    end
  end
  handledeletion(todel);
  catch ex,dsprinterr;end
end

function handledeletion(todelete,forcedeletedirs)
  global ds;
  try
  if(isempty(todelete)),return;end
  createddirs={};
  createdcells={};
  todelete=summarizedeletion(todelete);
  for(i=1:numel(todelete))
    if(iscell(todelete(i).inds)&&numel(todelete(i).inds)==0)
      createdcells=[createdcells;todelete(i)];
    elseif(isstruct(todelete(i).inds))
      createddirs=[createddirs;todelete(i)];
    elseif(isempty(todelete(i).inds))
      dsdelete(todelete(i).vars);
      %in case the interrupt happened during the dssave:
      delete(dsdiskpath(todelete(i).vars));
    elseif(size(todelete(i).vars,2)==1)
      eval(['ds.sys.savestate' todelete(i).vars(4:end) '{2}([' num2str(todelete(i).inds(:)') '])=1']);
      dsdelete([todelete(i).vars '{' num2str(todelete(i).inds(:)') '}']);
    else
      %linidx=sub2ind(eval(['size(ds.sys.savestate' todelete(i).vars(4:end) '{2})']),todelete(i).inds{1},todelete(i).inds(:,2));
      inds=todelete(i).inds;
      eval(['ds.sys.savestate' todelete(i).vars(4:end) '{2}([' num2str(inds{1}') ',' num2str(inds{2}') '])=1']);
      %for(i=unique(inds(:,2)))
        dsdelete([todelete(i).vars '{' num2str(inds{1}') '}{' num2str(inds{2}') '}']);
        %dsdelete([todelete(i).vars '{' num2str(inds(inds(:,2)==i,1)') '}{' num2str(i) '}']);
      %end
    end
  end
  for(i=1:numel(createdcells))
    if(forcedeletedirs || eval(['all(~ds.sys.savestate' createdcells{i}(4:end) '(:))']))
      dsdelete(createdcells{i});
    end
  end
  [~,ord]=sort(cellfun(@length,createddirs),'descend');
  createddirs=createddirs(ord);
  for(i=1:numel(createddirs))
    if(forcedeletedirs || eval(['size(fieldnames(ds.sys.savestate' createddirs{i}(4:end) '))'])==0)
      dsdelete(createddirs{i});
    end
  end
  catch ex,dsprinterr;end
end

function res=summarizedeletion(todelete)
  global ds;
  try
  allnams={todelete.vars};
  unams=unique(allnams)
  res=struct('vars',{},'inds',{});
  for(i=1:numel(unams))
    mydelete=todelete(ismember(allnams,unams{i}));
    if(numel(mydelete)==1)
      res=[res;mydelete];
      continue;
    end
    savest=eval(['ds.sys.savestate' unams{i}(4:end) '{2}'])~=0;
    deletesavest=false(size(savest));
    createdcell=false;
    for(j=1:numel(mydelete))
      inds=mydelete(j).inds;
      if(isempty(inds))
        createdcell=true;
        break;
      end
      rowvec=false;
      if(size(inds,2)==1)
        rowvec=true;
        inds=[ones(size(inds)), inds];
      end
      deletesavest(sub2ind(size(deletesavest),inds(:,1),inds(:,2)))=true;
    end
    if(createdcell)
      res=[res;struct('vars',unams{i},'inds',{})];
      res=[res;struct('vars',unams{i},'inds',{{}})];
      continue;
    end
    %if(all(deletesavest|(~savest))&&createdcell)
    %  continue;
    %end
    savest(all(~savest,1))=1;%any columns that are empty should be skipped during deletion
    safetodelete=(deletesavest|(~savest))';
    deletionforgroup=unique(safetodelete,'rows');
    [~,deletegroups]=ismember(safetodelete,deletionforgroup,'rows');
    append=struct('vars',{},'inds',{});
    for(j=1:size(deletionforgroup,1))
      inds=find(deletegroups==j);
      if(~rowvec)
        inds={find(deletionforgroup(j,:))', inds};
      end
      append=[append;struct('vars',{unams{i}},'inds',{inds})];
    end
    res=[res;append];
  end
  catch ex, dsprinterr;end
  
end

function dscancel()
  try
  global ds;
  toread=unique(ds.sys.distproc.jobsproc(2,:));
  for(i=toread(:)')
    readslave(i,1,ds.sys.distproc.loadresults,true);
  end

  toread=unique(ds.sys.distproc.jobsproc(2,:));
  dsinterrupt(toread);
  if(isempty(toread))
    disp('all workers are stopped.');
  end
  numreads=0;
  while(~isempty(toread))
    numreads=numreads+1;
    disp([num2str(numel(toread)) ' still need to be canceled...']);
    if(numreads>20)
      disp(toread);
    end
    read=[];
    for(i=toread(:)')
      if(readslave(i,1,ds.sys.distproc.loadresults,true))
        read=[read i];
      end
    end
    toread(ismember(toread,read))=[];
    if(~isempty(toread))
      pause(1);
    end
  end
  disp('cleaning up...')
  %for(i=1:numel(ds.sys.distproc.createddirs))
  rollbackpath={};
  for(i=1:size(ds.sys.distproc.rollbackdirs,1))
    if(~ismember(ds.sys.distproc.rollbackdirs{i,1},{ds.sys.distproc.createddirs.var}))
      rollbackpath=[rollbackpath;dsdiskpath(ds.sys.distproc.rollbackdirs{i,1},true,dsgettypeforvar(ds.sys.distproc.rollbackdirs{i,[2 1]}))];
    end
  end
  [~,ord]=sort(cellfun(@length,rollbackpath),'descend');
  rollbackpath=rollbackpath(ord);
  for(i=1:numel(rollbackpath))
    rmdir(rollbackpath{i});
  end

  %end
  ds.sys.distproc.interruptexiting=true;
  catch ex,dsprinterr;end
end

function loadstr=getvarstr(varnm,idx)
    if(numel(idx)==0)
      loadstr=[varnm];
    elseif(numel(idx)==1)
      loadstr=[varnm '{' num2str(idx) '}'];
    else
      loadstr=[varnm '{' num2str(idx(1)) '}{' num2str(idx(2)) '}'];
    end
end
