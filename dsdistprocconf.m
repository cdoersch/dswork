function dsparallelreadconf(conf)
  dssave();
  global ds;
  ds.sys.distproc.loadresults=true;
  ds.sys.distproc.allatonce=false;
  ds.sys.distproc.maxperhost=Inf;
  if(isfield(conf,'noloadresults'))
    ds.sys.distproc.loadresults=~(conf.noloadresults);
  end
  if(isfield(conf,'allatonce'))
    ds.sys.distproc.allatonce=(conf.allatonce==1);
  end
  if(isfield(conf,'maxperhost'))
    ds.sys.distproc.maxperhost=conf.maxperhost;
  end
end
