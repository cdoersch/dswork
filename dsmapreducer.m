% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
%
% The 'daemon' that runs on each distributed worker.
try
%hosts={'master','node001','node002','node003','node004'}
%for(i=1:numel(hosts))
%  if(~exist(['/mnt/sgeadmin/master-' hosts{i}],'file'))
%    unix(['while true ; do sleep 5; echo "echo hi"; done | ssh ' hosts{i} '&'])
%  end
%end
if(~exist('ds','var'))
%we are a new dsmapreducer
  global ds;
  if(dsbool(ds,'exit'))
    exit(ds.exit-1); %
  end
  disp('starting');
  dssetout(dsoutdir);
  dsload('ds.conf.*');
  ds.sys.distproc.mapreducer=1;
  ds.sys.distproc.mapreducerid=dsdistprocid;
  commlinkout=[dsoutdir 'ds/sys/distproc/master' num2str(dsdistprocid) '.mat']
  progresslink=[dsoutdir 'ds/sys/distproc/progress' num2str(dsdistprocid)]
  commlinkin=[dsoutdir 'ds/sys/distproc/slave' num2str(dsdistprocid) '.mat']
  interruptcommlink=[dsoutdir 'ds/sys/distproc/interrupt' num2str(dsdistprocid) '.mat'];
  sshconf=[dsoutdir 'ds/sys/distproc/sshconf' num2str(dsdistprocid) '.conf'];
  %sshsocket=[dsoutdir 'ds/sys/distproc/sshsocket' num2str(dsdistprocid) '-%h'];
  interruptlog=[dsoutdir 'ds/sys/distproc/interruptlog' num2str(dsdistprocid) '.log'];
  %interruptcommlink2=[dsoutdir 'distproc/interrupt2' num2str(dsdistprocid) '.mat'];
  dsworkpath=mfilename('fullpath');
  dotpos=find(dsworkpath=='/');
  dsworkpath=dsworkpath(1:(dotpos(end)-1));
  ds.sys.distproc.removesshsockets=true;

  unix([dsoutdir 'ds/sys/distproc/interruptor.sh ''' interruptcommlink ''' ' num2str(feature('getpid')) ' > ' interruptlog ' 2>&1 &']);
  [dsoutdir 'ds/sys/distproc/interruptor.sh ''' interruptcommlink ''' ' num2str(feature('getpid')) ' > ' interruptlog ' 2>&1 &']
  cmd.name='started';
  [~,cmd.host]=unix('hostname');
  cmd.host=cmd.host(1:end-1);
  ds.sys.distproc.myhost=cmd.host;
  disp(['running on ' cmd.host]);
  save(commlinkout,'cmd');
  disp(['wrote ' commlinkout]);
  ds.sys.distproc.lastprocessedserial=-1;
else
%we just restarted because we got an interrupt.
  if(dsbool(ds,'exit'))
    exit(ds.exit-1);
  end
  commlinkout=[dsoutdir 'ds/sys/distproc/master' num2str(dsdistprocid) '.mat']
  progresslink=[dsoutdir 'ds/sys/distproc/progress' num2str(dsdistprocid)]
  commlinkin=[dsoutdir 'ds/sys/distproc/slave' num2str(dsdistprocid) '.mat']
  interruptcommlink=[dsoutdir 'ds/sys/distproc/interrupt' num2str(dsdistprocid) '.mat'];
  sshconf=[dsoutdir 'ds/sys/distproc/sshconf' num2str(dsdistprocid) '.conf'];
  delete(commlinkin);
  %sshsocket=[dsoutdir 'ds/sys/distproc/sshsocket' num2str(dsdistprocid) '-%h'];
  disp('got interrupt');
  if(dsfield(ds,'sys','distproc','pendingwrite'))
    dsmapreducerwritepending(commlinkout,true)
  else
    cmd=struct();
    [cmd.maxprogress cmd.createddirs]=dsmapreducerrollback();
    cmd.name='interrupted';
    save(commlinkout,'cmd');
    disp(['wrote ' commlinkout]);
  end
  [~,host]=unix('hostname');
  ds.sys.distproc.myhost=host(1:end-1);;
end
ds.sys.distproc.sshconf=sshconf;
nwaits=0;
while(1)
  if(mod(nwaits,12)==0)
    if(exist([dsoutdir 'ds/sys/distproc/exit'],'file'))
      disp('got exit signal')
      cmd.name='exited';
      save(commlinkout,'cmd');
      disp(['wrote ' commlinkout]);
      disp('dskeeprunning:cuetoexit');
      ds.exit=1;
      exit(ds.exit-1);
    end
  end
  if(~exist(commlinkin,'file'))
    pause(5);
    nwaits=nwaits+1;
    continue;
  end
  nwaits=0;
  try
    load(commlinkin);
  catch
    %probably tried to read a half-written file
    dsstacktrace(lasterror);
    pause(1);
    continue;
  end
  delete(commlinkin);
  mycmd=cmd
  if(isfield(mycmd,'serial'))
    if(ds.sys.distproc.lastprocessedserial==mycmd.serial)
      %this is the same command that got written twice because of a user interrupt.  Don't process it.
      continue;
    end
    ds.sys.distproc.lastprocessedserial=mycmd.serial;
  end
  cmd=struct();
  if(strcmp(mycmd.name,'exit'))
    disp('got exit signal')
    cmd.name='exit';
    cmd.name='exited';
    save(commlinkout,'cmd');
    disp(['wrote ' commlinkout]);
    disp('dskeeprunning:cuetoexit');
    ds.exit=1;
    exit(ds.exit-1);
  elseif(strcmp(mycmd.name,'restart'))
    disp('got restart signal')
    ds.exit=2;
    return
    %exit(ds.exit-1);
  elseif(strcmp(mycmd.name,'run'))
    mycmd
    %ds.sys.distproc.wrotemaster=false;
    cmd=[];
    completed=[];
    terminatedwitherror=0;
    disp(['clearslaves:' num2str(mycmd.clearslaves)])
    if(mycmd.clearslaves)
      rehash;
      distproc=ds.sys.distproc;
      ds=[];
      dssetout(dsoutdir);
      ds.sys.distproc=distproc;
      conf=struct();
      conf.delete=false;
      scmd=dstryload([ds.sys.outdir 'ds/sys/distproc/savestate.mat'],conf);
      'savestate'
      scmd.savestate
      paths=scmd.matlabpath;
      upaths=regexp(paths,':','split');
      tic
      warning off all;
      mypaths=regexp(path,':','split');
      if(~isdeployed)
        matpath=which('pwd');
        matpath=matpath(1:end-numel('toolbox/matlab/general/pwd.m'));
        for(i=1:numel(upaths))
          if((~dshasprefix(upaths{i},matpath))&&~ismember(upaths{i},mypaths))%'/afs/cs.cmu.edu/misc/matlab/'))&&(~dshasprefix(upaths{i},'/opt/matlab/'))&&(~dshasprefix(upaths{i},'/usr/local/lib/matlab7/')))
            disp(['adding path ' upaths{i}])
            addpath(upaths{i});
          end
        end
      end
      warning on all;
      toc;
      ds.sys.savestate=scmd.savestate;
      ds.sys.distproc.mapreducer=1;
      ds.sys.distproc.mapreducerid=dsdistprocid;
      dssetlocaldir(scmd.localdir);
      %if(scmd.clearlocaldir&&dsfield(ds.sys.distproc,'localdir'))
      %  unix(['rm ' scmd.localdir '*']);%TODO: this isn't necessarily synchronized. should really create a new directory for every mapreduce.
      %end
      if(isfield(scmd,'reducehosts'))
        ds.sys.distproc.reducehosts=scmd.reducehosts;
      end
      ds.sys.saved={};
      ds.sys.savedjid={};
      ds.sys.distproc.nextfile=1;
      %dsload('ds.conf.*');
      dscd(['.ds' scmd.currpath])
      dsload('ds.conf.*');
      clear scmd;
      
      [~,host]=unix('hostname');
      ds.sys.distproc.myhost=host(1:end-1);
    %dsloadsavestate();
      conf=struct();
    end
    for(i=1:numel(mycmd.mapvars))
      mycmd.mapvars{i}=[mycmd.mapvars{i}];
    end
    if(isfield(mycmd,'hostname')&&isfield(ds.sys.distproc,'localdir'))
      if(dsbool(ds.sys.distproc,'removesshsockets'))
        unix(['rm ' ds.sys.distproc.localdir '/sshsocket' num2str(dsdistprocid) '-*']);
      end
      if(~isfield(ds.sys.distproc,'uhosts')),ds.sys.distproc.uhosts={};end
      newhosts=mycmd.hostname(~ismember(mycmd.hostname,ds.sys.distproc.uhosts));
      newhosts=unique(newhosts);
      for(i=1:numel(newhosts))
        if(strcmp(ds.sys.distproc.myhost,newhosts{i}))
          continue;
        end
        if(~exist(sshconf,'file'))
          fid=fopen(sshconf,'w');
          fprintf(fid,'host *\n');
          fprintf(fid,'    controlmaster auto\n');
          fprintf(fid,['    controlpath ' ds.sys.distproc.localdir '/sshsocket' num2str(dsdistprocid) '-%%h\n']);
          fclose(fid);
        end
        ds.sys.distproc.removesshsockets=false;
        ['while kill -0 ' num2str(feature('getpid')) ' ; do while kill -0 ' num2str(feature('getpid')) ' ; do sleep 5; echo "echo hi"; done | ssh -M -F "' sshconf '" ' newhosts{i} ' ; sleep 5; done &']
        unix(['while kill -0 ' num2str(feature('getpid')) ' ; do while kill -0 ' num2str(feature('getpid')) ' ; do sleep 5; echo "echo hi"; done | ssh -M -F "' sshconf '" ' newhosts{i} ' ; sleep 5; done &']);
      end
      ds.sys.distproc.uhosts=[ds.sys.distproc.uhosts newhosts(:)'];
    end
    redvars={};
    for(i=1:numel(mycmd.reducevars))
      redvars=[redvars;dsexpandpath(mycmd.reducevars{i})];
    end
    ds.sys.distproc.mapredmapvars=mycmd.mapvars;
    ds.sys.distproc.mapredreducevars=redvars;
    ds.sys.distproc.savedthisround=struct('vars',{},'inds',{});%cell(numel(mycmd.mapredout),1);
    %dsload('ds.conf.*');
    for(j=1:numel(mycmd.mapredin))
      mapredinexp=dsexpandpath(mycmd.mapredin{j});
      for(l=1:numel(mapredinexp))
        dimstrsz=0;
        for(k=1:numel(ds.sys.distproc.mapredreducevars))
          if(dspathmatch(mapredinexp{l},ds.sys.distproc.mapredreducevars{k}))
            getridof=1:dssavestatesize(mapredinexp{l},1);
            getridof(mycmd.inds)=[];
            eval(['ds.sys.savestate.' mapredinexp{l}(5:end) '{2}(getridof,:)=false;']);
          end
        end
      end
    end

    if(mycmd.allatonce)
      inds=mycmd.inds(:)';
      idxstr='';
      for(i=1:numel(inds))
        idxstr=[idxstr ' '  num2str(inds(i))];
      end
      try
      disp(['running jobs:' idxstr]);
        for(j=1:numel(mycmd.mapredin))
          mapredinexp=dsexpandpath(mycmd.mapredin{j});
          for(l=1:numel(mapredinexp))
            fmatch=0;;
            for(k=1:numel(ds.sys.distproc.mapredreducevars))
              if(dspathmatch(mapredinexp{l},ds.sys.distproc.mapredreducevars{k}))
                dimstrsz=dssavestatesize(ds.sys.distproc.mapredreducevars{k},2);%here we assume that it's only going to match other reducevars
                dimstr=['{1:' num2str(dimstrsz) '}']
                tic
                dsload([mapredinexp{l} '{' idxstr '}' dimstr]);
                toc
                fmatch=1;
              end
            end
            if(~fmatch)
              dsload([mapredinexp{l} '{' idxstr '}']);
            end
          end
        end
        dsmapredrun(mycmd.cmd,inds);
        dssave;
        completed=inds;
        ds=dsfinishjob(ds,inds,idxstr,progresslink,commlinkout,completed,1,mycmd.mapredin,mycmd.serial);
        dsmapreducerwritepending(commlinkout,false);
      catch ex
        disp(['ismapreducer:' num2str(ds.sys.distproc.mapreducer)]);
        ds_err=ex;
        dsstacktrace(ds_err);
        cmd.name='error';
        cmd.err=ds_err;
        cmd.errind=inds(:)';
        cmd.completed=completed;
        cmd.savedthisround=ds.sys.distproc.savedthisround;
        [cmd.maxprogress cmd.createddirs]=dsmapreducerrollback(); % currently not read.
        dstrysave(commlinkout,cmd);
        terminatedwitherror=1;
      end
      %if(~terminatedwitherror)
        %for(j=1:numel(mycmd.mapredout))
        %  ['dssave ' mycmd.mapredout{j} '{' idxstr '}']
        %  dssave([mycmd.mapredout{j} '{' idxstr '}']);
          %TODO: get rid of this stuff when there's an error, too
          %allpaths=dsexpandpath(mycmd.mapredout{j});
          %for(k=1:numel(allpaths))
          %  for(i=inds)
          %    eval([dsfindvar(allpaths{k}) '{' num2str(i) '}=[]']);
          %  end
          %end
        %end
      %end
    else
      for(i=mycmd.inds(:)')
        try
          disp(['running job:' num2str(i)]);
          %for(j=1:numel(mycmd.mapredin))
          %  dimstrsz=0;
          %  for(k=1:numel(ds.sys.distproc.mapredreducevars))
          %    if(dspathmatch(mycmd.mapredin{j},ds.sys.distproc.mapredreducevars{k}))
          %      dimstrsz=max(dimstrsz,savestatesize(ds.sys.distproc.mapredreducevars{k},2));%here we assume that it's only going to match other reducevars
          %    end
          %  end
          %  if(dimstrsz~=0)
          %    dimstr=['{1:' num2str(dimstrsz) '}']
          %  end 
          %  dsload([mycmd.mapredin{j} '{' num2str(i) '}' dimstr]);
          %end
          for(j=1:numel(mycmd.mapredin))
            mapredinexp=dsexpandpath(mycmd.mapredin{j})
            mycmd.mapredin{j}
            ds.sys.savestate
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
          dsmapredrun(mycmd.cmd,i);
          dssave;
          ds=dsfinishjob(ds,i,num2str(i),progresslink,commlinkout,[completed; i],i==mycmd.inds(end),mycmd.mapredin,mycmd.serial);
          dsmapreducerwritepending(commlinkout,false);
          completed=[completed;i];
        catch ex
          disp(['ismapreducer:' num2str(ds.sys.distproc.mapreducer)]);
          ds_err=ex;
          dsstacktrace(ds_err);
          cmd.name='error';
          cmd.err=ds_err;
          cmd.errind=i;
          cmd.completed=completed;
          cmd.savedthisround=ds.sys.distproc.savedthisround;
          [cmd.maxprogress cmd.createddirs]=dsmapreducerrollback(); % currently not read.
          dstrysave(commlinkout,cmd);
          terminatedwitherror=1;
          break;
        end
          %for(j=1:numel(mycmd.mapredout))
          %  ['dssave ' mycmd.mapredout{j} '{' num2str(i) '}']
            %dssave([mycmd.mapredout{j} '{' num2str(i) '}']);
            %TODO: get rid of this stuff when there's an error, too
            %allpaths=dsexpandpath(mycmd.mapredout{j});
            %for(k=1:numel(allpaths))
            %  eval([dsfindvar(allpaths{k}) '{' num2str(i) '}=[]']);
            %end
          %end
        %end
      end
    end
    %if(~terminatedwitherror)
    %  cmd.name='done';
    %  cmd.completed=completed;
    %  cmd.savedthisround=ds.sys.distproc.savedthisround;
    %  dstrysave(commlinkout,cmd);
    %  ds.sys.distproc.savedthisround=struct('vars',{},'inds',{});%cell(numel(mycmd.mapredout),1);
    %end
  %elseif(strcmp(mycmd.name,'clear'))
  %  ds=[];
  %  rehash;
  %  dssetout(dsoutdir);
  %  dsload('ds.conf.*');
  %  ds.sys.distproc.mapreducer=1;
  %  cmd=struct();
  %  cmd.name='cleared';
  %  save(commlinkout,'cmd');
  %  ds.sys.distproc.mapreducer=1;
  end
end
catch ex,dsstacktrace(ex);rethrow(ex);end
