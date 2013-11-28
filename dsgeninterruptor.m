function geninterruptor(outnm)
     fid = fopen(outnm, 'w');
     fprintf(fid, '%s\n','#!/bin/bash');
     fprintf(fid, '%s\n','while kill -0 $2 ;');
     fprintf(fid, '%s\n','do');
     fprintf(fid, '%s\n','   if [ -e $1 ] ;');
     fprintf(fid, '%s\n','   then');
     fprintf(fid, '%s\n','      kill -INT $2');
     fprintf(fid, '%s\n','      rm $1');
     fprintf(fid, '%s\n','   fi');
     fprintf(fid, '%s\n','   sleep 2s');
     fprintf(fid, '%s\n','done');
     fclose(fid);
     unix(['chmod 775 ' outnm]);
end
