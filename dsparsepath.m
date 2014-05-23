function parsepth=dsparsepaths(toparse,lineno)
  if(dshasprefix(toparse,'paths'))
    toparse=toparse(6:end);
    %parsepth=paths;
    %isdelim=~ismember(toparse,['0':'9' 'a':'z' 'A':'Z']);
    while(~evalin('caller','ischar(ds_parsepth)'))
      if(isempty(toparse))
        error(['line ' num2str(lineno) ': path in <%~ does not match any path in paths : ' toparse]);
      end
      numbraks=cumsum(toparse=='{')-cumsum(toparse=='}');
      (toparse=='.'&numbraks==0) | (toparse=='{'&numbraks==1)
      nextdelim=[find((toparse=='.'&numbraks==0) | (toparse=='{'&numbraks==1)) numel(toparse)+1];
      toparse(1:nextdelim(2)-1)
      evalin('caller',['ds_parsepth=ds_parsepth' toparse(1:nextdelim(2)-1) ';']);
      toparse=toparse(nextdelim(2):end);
    end
    parsepth=[evalin('caller',['ds_parsepth']) toparse];
  elseif(dshasprefix(toparse,'ds'))
    parsepth=toparse;
  else
    error(['line ' num2str(lineno) ': invalid path ' toparse]);
  end
end
