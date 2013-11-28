function res=dsmatchesreducevar(varnm)
  global ds;
  res=false;
  if(~dsfield(ds,'sys','distproc','mapvars'))
    return;
  end
  varnm=dsabspath(varnm);
  for(i=1:numel(ds.sys.distproc.mapvars))
    if(dspathmatch(ds.sys.distproc.mapvars{i},varnm))
      res=true;
      return;
    end
  end
end
