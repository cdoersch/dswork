function dsreassignjobs()
  global ds
  ds.sys.distproc.jobsinq=ds.sys.distproc.jobsproc(1,:);
  ds.sys.distproc.jobsproc=zeros(2,0);
  jp=ds.sys.distproc.jobprogress;
  if(numel(jp)<max(ds.sys.distproc.jobsinq))
    jp(max(ds.sys.distproc.jobsinq))=0;
  end
  ds.sys.distproc.jobsinq(jp(ds.sys.distproc.jobsinq)>0)=[];
  ds.sys.distproc.idleprocs=ds.sys.distproc.availslaves;
end
