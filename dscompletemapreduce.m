function dscompletemapreduce(startfresh)
  global ds;
  ds.sys.distproc.hcrashct=zeros(size(ds.sys.distproc.hcrashct));
  ds.sys.distproc.hdead=[];
  ds.sys.distproc.donotassociate=zeros(2,0);
  if(~exist('startfresh','var'))
    startfresh=0;
  end
  %ds.sys.distproc.jobsinq=union(ds.sys.distproc.jobsinq,ds.sys.distproc.jobsproc(1,:));
  %ds.sys.distproc.jobsproc=zeros(2,0);
  if(~dsbool(ds.sys.distproc,'donemap'))
    dsdistprocmgr(startfresh);
    startfresh=1;
    ds.sys.distproc.donemap=1;
  end
  if(~dsbool(ds,'sys','distproc','reducestarted'))
    ds.sys.distproc.reducevars=ds.sys.distproc.reducelatervars;
    ds.sys.distproc.command=ds.sys.distproc.reducelatercommand;
    ds.sys.distproc.forcerunset=ds.sys.distproc.forcerunsetlater;
    dsdistprocmapvars(ds.sys.distproc.reducelatervars);
    dsdistprocconf(ds.sys.distproc.reducelaterconf);
    ds.sys.distproc.nextfile=ones(size(ds.sys.distproc.nextfile));
    ds.sys.distproc.hascleared=false(ds.sys.distproc.nmapreducers,1);
    %ds.sys.distproc.jobsinq=1:ds.sys.distproc.njobs;
    ds.sys.distproc.jobprogress=[];
    ds.sys.distproc.reducestarted=1;
  end
  if(isfield(ds.sys.distproc,'mapvars'))
    ds.sys.distproc=rmfield(ds.sys.distproc,'mapvars');%ds.sys.distproc.mapvars tells dssave/dsload to treat this variable specially
  end
  dsdistprocmgr(startfresh);
  nams={};
  if(dsfield(ds.sys.distproc,'localdir'))
    for(i=1:numel(ds.sys.distproc.reducevars))
      nams=[nams;dsexpandpath(ds.sys.distproc.reducevars{i})];
    end
    for(i=1:numel(nams))
      dotpos=find(nams{i}=='.');
      eval(['ds.sys.savestate' nams{i}(4:dotpos(end)-1) '=rmfield(ds.sys.savestate' nams{i}(4:dotpos(end)-1) ',''' nams{i}(dotpos(end)+1:end) ''');']);
    end
  else
    for(i=1:numel(ds.sys.distproc.reducevars))
      dsdelete(ds.sys.distproc.reducevars{i});
    end
  end
  ds.sys.distproc.readytorun=0; 
end
