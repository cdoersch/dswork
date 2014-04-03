function dsmemory()
  global ds;
  fn=fieldnames(ds);
  maxfnln=max(cellfun(@length,fn));
  for(i=1:numel(fn))
    val=ds.(fn{i});
    mem=whos('val');
    disp([fn{i} ':' repmat(' ',1,maxfnln-numel(fn{i})) num2str(mem.bytes)]);
  end
end
