function dsmapreducerwrap(dsdistprocid,dsoutdir,isnew,depth)
  %if(nargin<4),depth=1;end
  for(i=1:1000)
    x{i} = onCleanup( @() dsmapreducerbarrier(dsdistprocid,dsoutdir,0) );
  end
  dsmapreducerbarrier(dsdistprocid,dsoutdir,isnew);
end
