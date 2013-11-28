% Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
%
% A few sanity checks to use when developing dswork.
%
% These are not well-maintained; use at your own risk.
global ds;
if(~exist('currtest','var'))
  currtest=0;
end
if(currtest<1)
  dssetout('/tmp');
  if(~dsmapredisopen())
    dsmapredopen(2,'local');
  end
  ds.a=5;
  dssave;
  ds.a=[];
  b=dsload('ds.a');
  if(ds.a~=b)
    throw(MException('dswork:failtest','save and load failed'));
  end
  currtest=1;
end
if(currtest<2)
  dsdelete('ds.*');
  if(isfield(ds,'a'))
    throw(MException('dswork:failtest','delete did not remove variable'));
  end
  if(~exist([ds.sys.outdir '/ds/sys'],'dir'))
    throw(MException('dswork:failtest','delete removed the sys directory'));
  end
  currtest=2;
end
if(currtest<3)
  ds.somepath.mapvar=[1 2 3 4];
  dscd('ds.somepath');
  dsrundistributed('ds.redvar{dsidx}=ds.mapvar(dsidx)+1;',{'ds.mapvar'});
  dscd('.ds');
  if(~all(cell2mat(ds.somepath.redvar)==(ds.somepath.mapvar+1)))
    throw(MException('dswork:failtest','dsrundistributed results incorrect'));
  end
end
dsmapredclose;
disp('finished testing');
