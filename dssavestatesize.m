function res=dssavestatesize(fnam,dim)
  global ds;
  fnam=dsabspath(fnam);
  dimstr='';
  if(exist('dim','var'))
    dimstr=[',' num2str(dim)];
  end
  fnam=['ds.sys.savestate.' fnam(5:end)];
  if(dsfield(fnam))
    res=eval(['size(' fnam '{2}' dimstr ')']);
  else
    if(exist('dim','var'))
      res=0;
    else
      res=[0 0];
    end
  end
end
