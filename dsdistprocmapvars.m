function dsdistprocmapvars(mapvars)
  global ds;
  ds.sys.distproc.mapvars2={};
  njobs=NaN;
  if(isnumeric(mapvars)&&numel(mapvars)==1)
    njobs=mapvars;
    mapvars={};
  elseif(ischar(mapvars))
    mapvars={mapvars};
  elseif(~iscell(mapvars))
    error('second argument must be an integer, string, or cell array of strings');
  end
  for(i=1:numel(mapvars))
    currvars=dsexpandpath(mapvars{i});
    if(isempty(currvars))
      continue;
    end
    ds.sys.distproc.mapvars2=[ds.sys.distproc.mapvars2;currvars];
  end
  if(~isempty(mapvars)&&isempty(ds.sys.distproc.mapvars2))
    error('no valid mapreduce variables');
  end
  for(i=1:numel(ds.sys.distproc.mapvars2))
    brakopen=find(ds.sys.distproc.mapvars2{i}=='{');
    brakclose=find(ds.sys.distproc.mapvars2{i}=='}');
    if(numel(brakopen)>0&&numel(brakclose)>0)
      ds.sys.distproc.mapvars2{i}(brakopen(1))='(';
      ds.sys.distproc.mapvars2{i}(brakclose(numel(brakclose)))=')';
    end
  end

  for(i=1:numel(ds.sys.distproc.mapvars2))
    ap=dsabspath(ds.sys.distproc.mapvars2{i})
    sz=0;
    if(dsfield(['ds.sys.savestate' ap(4:end)])&&eval(['iscell(ds.sys.savestate' ap(4:end) ')']))
      sz=eval(['size(ds.sys.savestate' ap(4:end)  '{2})'])
      if(dsmatchesreducevar(ap))
        sz=sz(1);
      else
        sz=sz(2);
      end
    else
      sz=eval(['numel(' dsfindvar(ds.sys.distproc.mapvars2{i}) ')']);
    end
    if(isnan(njobs))
      njobs=sz;
      %varwithmaxsz=ds.sys.distproc.mapvars2{i};
    else
      njobs=max(njobs,sz);
      %varwithmaxsz=ds.sys.distproc.mapvars2{i};
      %if(sz~=1&&sz~=njobs)
      %  throw(MException('dsmapreduce:arglength',['dsmapreduce args ' mapvars{i} ' and ' varwithmaxsz...
      %                   ' are not the same length.']));
      %end
    end
  end
  if(isnan(njobs))
    error('cannot determine the number of parallel jobs.');
  end
  ds.sys.distproc.njobs=njobs;
  ds.sys.distproc.jobsinq=1:ds.sys.distproc.njobs
end
