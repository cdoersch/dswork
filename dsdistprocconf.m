function dsparallelreadconf(conf)
  dssave();
  global ds;
  ds.sys.distproc.loadresults=true;
  ds.sys.distproc.allatonce=false;
  ds.sys.distproc.maxperhost=Inf;
  ds.sys.distproc.waitforstart=false;
  if(isfield(conf,'noloadresults'))
    ds.sys.distproc.loadresults=~(conf.noloadresults);
  end
  if(isfield(conf,'allatonce'))
    ds.sys.distproc.allatonce=(conf.allatonce==1);
  end
  if(isfield(conf,'maxperhost'))
    ds.sys.distproc.maxperhost=conf.maxperhost;
    if(ds.sys.distproc.maxperhost<1)
      error(['maxperhost was ' num2str(ds.sys.distproc.maxperhost) ': must allow at least 1 job per host']);
    end
  end
  if(isfield(conf,'waitforstart'))
    ds.sys.distproc.waitforstart=conf.waitforstart;
  end
end
