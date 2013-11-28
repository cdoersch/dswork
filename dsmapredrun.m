function dsmapredrun(dscmd,dsidx)
  %create an empty workspace to run the command
  global ds;
  try
  eval(dscmd);
  catch ex
    if(dsfield(ds,'conf','dumponerror'))
      dsload('ds.dispoutpath');
      if(dsfield(ds,'dispoutpath'))
        saveto=ds.dispoutpath;
      else
        saveto=ds.sys.outdir;
      end
      disp('job crashed, saving workspace...');
      save([saveto '/crash_' num2str(dsidx) '_' num2str(ds.sys.distproc.mapreducerid) '.mat']);
      unix(['find "' ds.sys.outdir '"']);
    end
    rethrow(ex);
  end
end
