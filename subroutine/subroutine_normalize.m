function y = subroutine_normalize(x)
z = x-min(x(:)); % make baseline 0
y = z/max(z(:)); 
