function dssetlocaldir(dirnm)
  global ds;
  disp(['dssetlocaldir(' dirnm ')']);
  if(isempty(dirnm))
    if(dsfield(ds,'sys','distproc','localdir'))
      ds.sys.distproc=rmfield(ds.sys.distproc,'localdir');
    end
    return
  end
  if(dirnm(end)~='/')
    dirnm(end+1)='/';
  end
  ds.sys.distproc.localdir=dirnm;
  'ismapreducer'
  dsbool(ds.sys.distproc,'mapreducer')
  if(dsbool(ds.sys.distproc,'mapreducer'))
    disp(['mymkdir(' dirnm ')']);
    mymkdir(dirnm);
  end
end
