function res=dsreldiskpath(varnm,targpath)
  diskpath=dsdiskpath(varnm,true);
  rel=dsdiskpath(targpath,true);
  rel=rel{1};
  res={};
  for(j=1:numel(diskpath))
    relc=regexp(rel,'/','split');
    relc(cellfun(@isempty,relc))=[];
    diskpc=regexp(diskpath{j},'/','split');
    diskpc(cellfun(@isempty,diskpc))=[];
    while(length(relc)>0&&length(diskpc)>1&&strcmp(relc{1},diskpc{1}))
        relc(1)=[];
        diskpc(1)=[];
    end
    if(numel(relc)>0)
      res{j}=repmat('../', 1, numel(relc)-1);
    else
      res{j}='';
    end
    for(i=1:numel(diskpc))
      res{j}=[res{j} diskpc{i} '/'];
    end
    res{j}(end)=[];
  end
end
