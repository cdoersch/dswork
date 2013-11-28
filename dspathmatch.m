function res=dspathmatch(pattern,poth)
  [tokspat]=regexp(pattern,'\.','split');
  [tokspath]=regexp(poth,'\.','split');
  if(numel(tokspath)~=numel(tokspat))
    res=false;
    return;
  end
  for(i=1:numel(tokspat))
    if(~dsstringmatch(tokspat{i},tokspath{i}))
      res=false;
      return;
    end
  end
  res=true;
end
