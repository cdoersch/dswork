function mhprint(str)
  global ds_html;
  ds_html{end+1}=sprintf([num2str(str) '\n']);
end
