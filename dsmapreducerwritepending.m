function demapreducerwritepending(outfname,camefrominterrupt)
  global ds;
  if(isfield(ds.sys.distproc,'pendingwrite'))
    cmd=ds.sys.distproc.pendingwrite;
    cmd.camefrominterrupt=camefrominterrupt;
    dstrysave(outfname,cmd);
    ds.sys.distproc=rmfield(ds.sys.distproc,'pendingwrite');
  end
end
