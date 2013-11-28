% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
function ds=dsfinishjob(ds,inds,idxstr,progressfile,commlinkout,completed,islast,mapredin,serial)
  a=tic
  %writeprogress=true;
%  idxstr=num2str(inds(:)');
%  for(j=1:numel(mapredout))
%    ['dssave ' mapredout{j} '{' idxstr '}']
%    dssave([mapredout{j} '{' idxstr '}']);
    %TODO: get rid of this stuff when there's an error, too
%    allpaths=dsexpandpath(mapredout{j});
%    for(k=1:numel(allpaths))
%      varnm=dsfindvar(allpaths{k});
%      for(i=inds)
        %['(numel(' varnm ')>' num2str(i) ')&&~isempty(' varnm '{' num2str(i) '})']
%        savedval=dsfield(varnm)&&eval(['(numel(' varnm ')>=' num2str(i) ')&&~isempty(' varnm '{' num2str(i) '})']);
%        if(savedval)
          %ds.sys.distproc.savedthisround(end+1)=struct('vars',allpaths{k},'inds',i);%[ds.sys.distproc.savedthisround{k} i];
%          eval([varnm '{' num2str(i) '}=[]']);
          %dsload([allpaths{k} '{' num2str(i) '}']);
          %eval([varnm '{' num2str(i) '}=[]']);
          %ds.sys.distproc.savedthisround.inds(end+1)=i;%[ds.sys.distproc.savedthisround{k} i];
          %writeprogress=true;
        %else
        %  disp('fail')
        %  disp(varnm)
        %  disp(i)
          %disp(eval([varnm '{' num2str(i) '}']))
        %  savedval
        %  ['(numel(' varnm ')>' num2str(i) ')&&~isempty(' varnm '{' num2str(i) '})']
        %  eval(['~isempty(' varnm '{' num2str(i) '})'])
        %  eval(['(numel(' varnm ')>' num2str(i) ')']);
%        end
%      end
%    end
%  end
  
  for(j=1:numel(mapredin))
    allpaths=dsexpandpath(mapredin{j});
    for(l=1:numel(allpaths))
      varnm=dsfindvar(allpaths{l});
      fmatch=0;
      for(k=1:numel(ds.sys.distproc.mapredreducevars))
        if(dspathmatch(allpaths{l},ds.sys.distproc.mapredreducevars{k}))
          for(i=inds)
            fmatch=1;
            savedval=dsfield(varnm)&&eval(['iscell(' varnm ')&&(size(' varnm ',1)>=' num2str(i) ')']);
            if(savedval)
              eval([varnm '([' num2str(i) '],:)={[]}']);
            end
          end
        end
      end
      if(~fmatch)
        for(i=inds)
          savedval=dsfield(varnm)&&eval(['iscell(' varnm ')&&(size(' varnm ',2)>=' num2str(i) ')']);
          if(savedval)
            eval([varnm '(:,[' num2str(i) '])={[]}']);
          end
        end
      end
    end
  end
  if(~dsfield(ds,'sys','saved'))
    ds.sys.saved={};
  end
  if(~dsfield(ds,'sys','jid'))
    ds.sys.savedjid=[];
  end
  %disp(['repmsize:' num2str(size(repmat({inds(:)'},size(ds.sys.saved,1)-size(ds.sys.savedjid),1)))]);
  repdmat=cell(size(ds.sys.saved,1)-size(ds.sys.savedjid,1),1);
  nexttoclear=size(ds.sys.savedjid,1)+1;
  for(i=1:numel(repdmat)),repdmat{i}=inds(:)';end
  ds.sys.savedjid=[ds.sys.savedjid; repdmat];
  for(i=nexttoclear:size(ds.sys.saved,1))
    varnm=dsfindvar(ds.sys.saved{i,1});
    if(dsfield(varnm))
      if(~eval(['isstruct(' varnm ')']))
        if(isempty(ds.sys.saved{i,2}))
          if(eval(['iscell(' varnm ')']))
            eval([varnm '={}']);
          else
            eval([varnm '=[]']);
          end
        elseif(size(ds.sys.saved{i,2},2)==1)
          eval([varnm '(1,[' num2str(ds.sys.saved{i,2}') '])={[]}']);
        else
          varsz=eval(['size(' varnm ')']);
          valid=ds.sys.saved{i,2}(:,1)<=varsz(1) & ds.sys.saved{i,2}(:,2)<=varsz(2);
          toclear=sub2ind(eval(['size(' varnm ')']),ds.sys.saved{i,2}(valid,1),ds.sys.saved{i,2}(valid,2));
          try
          [varnm '([' num2str(toclear(:)') '])={[]}']
          eval([varnm '([' num2str(toclear(:)') '])={[]}']);
          catch ex,eval(varnm); rethrow(ex);end
        end
      end
    end
  end
    %ds.sys.savedjid=[ds.sys.savedjid; (repmat({inds(:)'},size(ds.sys.saved,1)-size(ds.sys.savedjid),1))];
    %disp(['savedjidsize:' num2str(size(ds.sys.savedjid))]);
    %disp(['savedsize:' num2str(size(ds.sys.saved))]);
  if(islast || (ds.sys.distproc.nextfile==1) || ~exist([progressfile '_' num2str(ds.sys.distproc.nextfile-1) '.mat'],'file'))% && ~islast)
    cmd.savedthisround=[ds.sys.saved ds.sys.savedjid];%distproc.savedthisround;
    %ds.sys.saved(:,3)=num2cell(ones(size(ds.sys.saved,1),1)*jid);
    cmd.completed=completed;
    save([progressfile '_' num2str(ds.sys.distproc.nextfile) '.mat'],'cmd');
    ds.sys.saved={};
    ds.sys.savedjid={};
    ds.sys.distproc.nextfile=ds.sys.distproc.nextfile+1;
  end
  if(islast)
  cmd.name='done';
  cmd.completed=completed;
  cmd.savedthisround=ds.sys.distproc.savedthisround;
  %dstrysave(commlinkout,cmd);
  cmd.serial=serial;
  ds.sys.distproc.pendingwrite=cmd;
  ds.sys.distproc.savedthisround=struct('vars',{},'inds',{});
  end
  'dsfinishjob'
  toc(a)
end
