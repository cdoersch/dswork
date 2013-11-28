function resetdistproc();
  global ds;
  ds.sys.distproc.availslaves=setdiff(ds.sys.distproc.allslaves,ds.sys.distproc.notresponding)
  ds.sys.distproc.nextfile=ones(1,numel(ds.sys.distproc.commlinkslave));
  %ds.sys.distproc.jobsinq=1:ds.sys.distproc.njobs;
  %ds.sys.distproc.jobsinq(find(complete))=[];
  ds.sys.distproc.jobsproc=zeros(2,0);
  ds.sys.distproc.donotassociate=zeros(2,0);
    toread=ds.sys.distproc.availslaves;
    toread2=[];
    for(k=[1 5 3 7 2 6 4 8])
      toread2=[toread2 toread(k:8:end)];
    end
  ds.sys.distproc.idleprocs=toread2;
  ds.sys.distproc.hcrashct=zeros(ds.sys.distproc.nmapreducers,1);
  ds.sys.distproc.hdead=ds.sys.distproc.notresponding;
  ds.sys.distproc.jcrashct=zeros(max(ds.sys.distproc.jobsinq),1);
  ds.sys.distproc.jdead=[];
  ds.sys.distproc.loadqueue=[];
  ds.sys.distproc.loaddone=[];
  ds.sys.distproc.uniqueredvars={};
  ds.sys.distproc.nloads=[];
  ds.sys.distproc.totalloadtime=[];
  ds.sys.distproc.jobprogress=[];
  ds.sys.distproc.assignmentlog=[];
  ds.sys.distproc.reducemodulo=0;
  ds.sys.distproc.mapvars={};
  ds.sys.distproc.reducevars={};
  ds.sys.distproc.hascleared=false(ds.sys.distproc.nmapreducers,1);
  ds.sys.distproc.createddirs=struct('var',{},'inds',{},'jid',{});
  if(isfield(ds.sys.distproc,'pendingwrite'))
    rmfield(ds.sys.distproc,'pendingwrite');
  end
  if(dsfield(ds.sys.distproc,'forcerunset'))
    ds.sys.distproc=rmfield(ds.sys.distproc,'forcerunset');
  end
end
