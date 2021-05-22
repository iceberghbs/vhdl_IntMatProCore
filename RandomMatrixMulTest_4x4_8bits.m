
clc
A = randi([0 9], 4, 4);
B = randi([0 9], 4, 4);
C = A*B; 

AHex = dec2hex(A', 2);
BHex = dec2hex(B', 2);
CHex = dec2hex(C', 5);
% end



