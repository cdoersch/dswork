function [maxprogress createddirs]=dsmapreducerrollback()
  global ds;
  createddirs=[];
  if(isfield(ds.sys,'saved'))
    for(i=1:size(ds.sys.saved,1))
      if(iscell(ds.sys.saved{i,2}) || isstruct(ds.sys.saved{i,2}))
        createddirs=[createddirs;ds.sys.saved(i,:)];
      elseif(isempty(ds.sys.saved{i,2}))
        dsdelete(ds.sys.saved{i,1});
        %in case the interrupt happened during the dssave:
        delete(dsdiskpath(ds.sys.saved{i,1}));
      elseif(size(ds.sys.saved{i,2}==1))
        eval(['ds.sys.savestate' ds.sys.saved{i,1}(4:end) '{2}([' num2str(ds.sys.saved{i,2}(:)') '])=1']); 
        dsdelete([ds.sys.saved{i,1} '{' num2str(ds.sys.saved{i,2}(:)') '}']);
      else
        linidx=sub2ind(eval(['size(ds.sys.savestate' ds.sys.saved{i,1}(4:end) ')']),ds.sys.saved{i,2}(:,1),ds.sys.saved{i,2}(:,2));
        eval(['ds.sys.savestate' ds.sys.saved{i,1}(4:end) '{2}([' num2str(linidx(:)') '])=1']);
        inds=ds.sys.saved{i,2};
        for(i=unique(inds(:,2)))
          dsdelete([ds.sys.saved{i,1} '{' num2str(i) '}{' num2str(inds(inds(:,2)==i,1)') '}']);
        end
      end
    end
  end
  %wrotemaster=dsbool(ds.sys.distproc,'wrotemaster')
  if(isfield(ds.sys.distproc,'nextfile'))
    maxprogress=ds.sys.distproc.nextfile-1;
  else
    maxprogress=0;
  end
end
