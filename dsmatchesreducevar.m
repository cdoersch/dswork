function res=dsmatchesreducevar(varnm)
  global ds;
  res=false;
  if(~dsfield(ds,'sys','distproc','reducevars'))
    return;
  end
  varnm=dsabspath(varnm);
  for(i=1:numel(ds.sys.distproc.reducevars))
    if(dspathmatch(ds.sys.distproc.reducevars{i},varnm))
      res=true;
      return;
    end
  end
end
