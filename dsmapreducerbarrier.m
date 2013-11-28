%author: cdoersch
%make sure that errors get thrown out of the scope of dsmapreducer so maltab cleans up.
function dsmapreducerbarrier(dsdistprocid,dsoutdir,isnew)
  if(isnew)
    disp('new mapreducer');
  else
    disp('got interrupt');
    global ds;
  end
  dsmapreducer;
end
