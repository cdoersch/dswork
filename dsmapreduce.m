% Essentially equivalent to dsrundistributed, except that this function
% runs two sessions, and enables the results of the first session
% to be sent directly over the network for use in the second session, without
% using the shared storage.  I.e., the results of a dsmapreduce will be
% equivalent to simply running:
%
% dsrundistributed(mapcommand,mapvars,overrideConf(conf,conf1));
% dsrundistributed(reducecommand,mapreducevars,overrideConf(conf,conf2));
% for(foo in mapreducevars),dsdelete(foo);end
%
% Specifically, mapcommand will be run in a first session ('map' session).  If a local
% directory is specified (dssetlocaldir), then any variables that this first
% job writes to mapreducevars will be saved there, and then sent over the
% network via ssh shared connections.  (note wildcards are accepted in mapreducevars)
% Note that this means that jobs for the second session ('reduce' session) have to 
% be assigned to machines right at the beginning: dswork does this by simply enforcing
% that the i'th row of each mapreduce variable gets processed by worker
% i mod the number of processors (or mod the length of the forcerunset list, if
% specified in the conf).  The ssh copy happens immediately after each map job
% finishes.  Any mapreduce variables are deleted before the end of the dsmapreduce,
% but any other variables created will behave as they do in dsrundistributed.
%
% Note that there is no redundancy, so in practice dsmapreduce can be somewhat
% brittle.  If you are having difficulty, it may be a better idea to install a
% proper distributed filesystem (e.g. gluster or memcached/memcachefs) and break 
% the dsmapreduce into two dsrundistributed's.

function dsmapreduce(mapcommand,reducecommand,mapvars,mapreducevars,conf,conf1,conf2)
  global ds;
  dssave;
  if(~exist('conf','var'))
    conf=struct();
  end
  if(~exist('conf1','var'))
    conf1=struct();
  end
  if(~exist('conf2','var'))
    conf2=struct();
  end
  if(~iscell(mapreducevars))
    mapreducevars={mapreducevars};
  end
  for(i=1:numel(mapreducevars))
    mapreducevars{i}=dsabspath(mapreducevars{i});
    if(dsfield(['ds.sys.savestate' mapreducevars{i}(4:end)]))
      savest=eval(['ds.sys.savestate' mapreducevars{i}(4:end)]);
      if(~iscell(savest))
        error(['mapreduce variable ' mapreducevars{i} ' exists and is not a cell']);
      end
      if(numel(savest)>=2 && any(savest{2}(:)))
        error(['mapreduce variable ' mapreducevars{i} ' is non-empty']);
      end
    end
    %mapreducevars{i}=mapreducevars{i}(5:end);
  end
  %if(~dsbool(ds.sys.distproc,'readytorun'))
    dsdistprocconf(dsoverrideconf(conf,conf1));
    dsdistprocmapvars(mapvars);
    dsresetdistproc;
    if(dsfield(conf,'forcerunset'))
     ds.sys.distproc.forcerunsetlater=conf.forcerunset;
     ds.sys.distproc.reducemodulo=numel(conf.forcerunset);
    end
    ds.sys.distproc.donemap=0;
    ds.sys.distproc.mapvars=mapreducevars;
    ds.sys.distproc.reducelatervars=mapreducevars;
    ds.sys.distproc.command=mapcommand;
    ds.sys.distproc.reducelatercommand=reducecommand;
    ds.sys.distproc.reducelaterconf=dsoverrideconf(conf,conf2);
    ds.sys.distproc.mapreducing=1;
    ds.sys.distproc.reducestarted=0;
    ds.sys.distproc.readytorun=1;
    if(isfield(ds.sys.distproc,'forcerunset'))
      ds.sys.distproc=rmfield(ds.sys.distproc,'forcerunset');
    end
  uhosts=unique(ds.sys.distproc.hostname);
  if(isfield(ds.sys.distproc,'localdir'))
    for(i=1:numel(uhosts))
      unix(['ssh ' uhosts{i} ' "find ''' ds.sys.distproc.localdir ''' -name ds.* -print0 | xargs -0 rm"']);%' rm "' ds.sys.distproc.localdir '/ds.*"']);
      ['ssh ' uhosts{i} ' "find ''' ds.sys.distproc.localdir ''' -name ds.* -print0 | xargs -0 rm"']%' rm "' ds.sys.distproc.localdir '/ds.*"']);
    end
  end
  %end
  dscompletemapreduce(1);
  %if(~dsbool(ds.sys.distproc,'donemap'))
  %dsdistprocmgr;
  %ds.sys.distproc.mapvars=ds.sys.distproc.reducelatervars;

  %ds.sys.distproc.readytorun=0;
end
