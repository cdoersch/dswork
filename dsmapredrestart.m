 % Author: Carl Doersch (cdoersch at cs dot cmu dot edu)
 % 
 % close a distributed processing session and reopen it, ensuring
 % that each worker stays on the same machine.

 function dsmapredrestart()
   global ds;
   cmd=struct();
   cmd.name='restart';
   unix(['rm -f ' ds.sys.outdir 'ds/sys/distproc/progress*']);
   unix(['rm -f ' ds.sys.outdir 'ds/sys/distproc/master*']);
   for(i=ds.sys.distproc.availslaves(:)')%1:numel(ds.sys.distproc.commlinkslave))
     save(ds.sys.distproc.commlinkslave{i},'cmd');
   end
   disp('waiting for mapreducers to restart...');
   exited=zeros(numel(ds.sys.distproc.availslaves),1);
   nwaits=0;
   while(~all(exited))
     for(i=1:numel(ds.sys.distproc.availslaves))
       as=ds.sys.distproc.availslaves(i);
       res=dstryload(ds.sys.distproc.commlinkmaster{as});
       if((~isempty(res))&&strcmp(res.name,'started'))
         exited(i)=1;
       end

     end
     if(~all(exited))
       pause(3);
       nwaits=nwaits+1;
       disp([num2str(numel(exited)-sum(exited)) ' still need to restart...']);
     end
     if(nwaits>20)
       disp(find(~exited(:)'))
     end
   end
end

