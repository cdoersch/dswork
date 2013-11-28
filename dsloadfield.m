function [currds savestate]=dsloadfield(fnam,currpath,currds,savestate,task,brakidx,reduceload)
    dfnam=fnam;% {dslf_idx};
    fpath=[currpath '/' dfnam '[]'];
    if(reduceload)
      global ds;
      if(dsfield(ds,'sys','distproc','localdir'))
        fpath(1:numel(ds.sys.outdir))=[];
        %fpath=strrep(fpath,'\','\\');
        fpath=strrep(fpath(2:end),'/','.');
        fpath=[ds.sys.distproc.localdir fpath];
      else
        reduceload=0;
      end
    end
    cellsavest=getfield(savestate,dfnam);
    if(iscell(cellsavest))
        if(dshassuffix(dfnam,'img'))
          isimg=1;
        else
          isimg=0;
        end
        ispng=dshassuffix(dfnam,'png');
        if(dshassuffix(dfnam,'html'))
          ishtml=1;
        else
          ishtml=0;
        end
        if(dshassuffix(dfnam,'txt'))
          istxt=1;
        else
          istxt=0;
        end
        if(dshassuffix(dfnam,'fig'))
          return;
        end
        if(numel(cellsavest)>=2)
          cellsavest=cellsavest{2};
        else
          currds=setfield(currds,fnam,[]);
          return;
        end

        for(dssf_k=1:2)
          if(isempty(brakidx{dssf_k}))
            dslf_brakidx{dssf_k}=1:size(cellsavest,dssf_k);
          else
            dslf_brakidx{dssf_k}=brakidx{dssf_k};
          end
          if(isempty(dslf_brakidx{dssf_k}))
            bkidxsz(dssf_k)=0;
          else
            bkidxsz(dssf_k)=max(dslf_brakidx{dssf_k});
          end
        end

        %uncomment these lines
        if(isfield(currds,dfnam))
          tmpcell2=getfield(currds,dfnam);
          tmpcell=cell(max(bkidxsz,max(size(cellsavest),size(tmpcell2))));
          tmpcell(1:size(tmpcell2,1),1:size(tmpcell2,2))=tmpcell2;
          tmpcell2=[];
          %if(strcmp(task,'load'))%not force; check what's already loaded
            %cellsavest=cellsavest.*cellfun(@(x) isempty(x),tmpcell,'UniformOutput',true);%doing it this way breaks transparency somehow
          %  keyboard;
          %  for(i=1:min(numel(tmpcell),numel(cellsavest)))
          %    cellsavest(i)=cellsavest(i).*isempty(tmpcell{i});
          %  end
          %end
        else

          tmpcell=cell(size(cellsavest));

        %and this one
        end
        dslf_brakidx_1=dslf_brakidx{1};
        dslf_brakidx_1(dslf_brakidx_1>size(cellsavest,1))=[];
        dslf_brakidx{2}(dslf_brakidx{2}>size(cellsavest,2))=[];
        %madechanges=0;
        for(dslf_i=dslf_brakidx{2}(:)')
          dslf_isect=dslf_brakidx_1(cellsavest(dslf_brakidx_1,dslf_i)~=0);
          if(isimg||ishtml||istxt||ispng)
            if((~isempty(dslf_isect))&&(strcmp(task,'forceload')||isempty(tmpcell{1,dslf_i})))
              if(isimg)
                tmpcell{1,dslf_i}=imread([fpath '/' num2str(dslf_i) '.jpg']);
              elseif(ispng)
                tmpcell{1,dslf_i}=dsloadpng([fpath '/' num2str(dslf_i) '.png']);
              elseif(ishtml) 
                tmpcell{1,dslf_i}=fileread([fpath '/' num2str(dslf_i) '.html']);
              elseif(istxt) 
                dotpos3=find(dfnam=='_');
                type=varnm((dotpos3(end)+1):end);

                tmpcell{1,dslf_i}=fileread([fpath '/' num2str(dslf_i) type(1:(end-3))]);
              end
            end
          else
            if(strcmp(task,'load'))
              %disp('summarizing')
              %keyboard;
              dslf_empty=[];
              for(dslf_j=1:numel(dslf_isect))
                dslf_empty(dslf_j)=~isempty(tmpcell{dslf_isect(dslf_j),dslf_i});
              end
              dslf_isect(dslf_empty==1)=[];
              %keyboard;
            end
            dslf_vars=[];
            dslf_varnq='';
            dslf_inds='';
            for(dslf_j=dslf_isect(:)')
              %if(size(dslf_vars,2)==0)
              %  dslf_vars=['''data' num2str(dslf_j) ''''];
              %else
              dslf_vars{end+1}=['data' num2str(dslf_j) ];
              %end
              dslf_inds=[dslf_inds ' ' num2str(dslf_j)];
              dslf_varnq=[dslf_varnq ' data' num2str(dslf_j)];
            end
            if(numel(dslf_vars)>0)
              if(reduceload)
                [mypos]=mod(dslf_j-1,numel(ds.sys.distproc.reducehosts))+1; %ismember(ds.sys.distproc.mapreducerid,ds.sys.distproc.reducehosts);
                loadfnam=[fpath '~' num2str(dslf_i) '~' num2str(mypos) '.mat'];
                disp(['load(' loadfnam ',' dslf_vars{:} ')']);
                %while(~exist(loadfnam,'file'))%since this got transferred over ssh rather than through
                                              %shared disk, it's not synchronized.
                %  pause(1);
                %end
                success=0;
                while(~success)
                  try
                    load(loadfnam,dslf_vars{:});
                  catch
                    disp('load failed. retrying in 1 sec...');
                    pause(1);
                    continue;
                  end
                  success=1;
                end
              else
                loadfnam=[fpath '/' num2str(dslf_i) '.mat'];
                tic
                load(loadfnam,dslf_vars{:});
                toc
              end
              %tic
              %if(toc>5),keyboard;end
              eval(['tmpcell([' dslf_inds '],' num2str(dslf_i) ')={' dslf_varnq '};']);%in theory this could be done with struct2cell, but
                                                                                       %I'm not sure save() preserves field order.
              clear(dslf_vars{:});
              %madechanges=1;
            end
          end
        end
        %if(madechanges)
          %disp('setfield');
          currds=setfield(currds,dfnam,tmpcell);
        %end
    else
      if(strcmp(task,'forceload')||~isfield(currds,dfnam)||isempty(getfield(currds,dfnam)))
        disknam=dsgetdisknam(getfield(savestate,dfnam),dfnam,[currpath '/']);
        if(dshassuffix(dfnam,'html')||dshassuffix(dfnam,'txt'))
            data=fileread(disknam{1});%[currpath '/' dfnam '.html']);
          vnam=dfnam;%(:,1:end-5);
        elseif(dshassuffix(dfnam,'img'))
            data=imread(disknam{1});%[currpath '/' dfnam '.jpg']);
          vnam=dfnam;%(:,1:end-4);
        elseif(dshassuffix(dfnam,'png'))
            data=dsloadpng(disknam{1});%[currpath '/' dfnam '.jpg']);
          vnam=dfnam;%(:,1:end-4);
        elseif(dshassuffix(dfnam,'fig'))
          return
        else
            load(disknam{1});%[currpath '/' dfnam '.mat']);
          vnam=dfnam;%(:,1:end-4);
        end
          currds=setfield(currds,vnam,data);
          clear data;
        savestate=setfield(savestate,vnam,1);
      end
    end
