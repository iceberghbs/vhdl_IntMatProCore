clc
A = randi ([0 9], 32, 32);
B = randi ([0 9], 32, 32);
C = randi ([0 9], 32, 32);
D = A*B + C;

AHex = dec2hex(A', 4);
BHex = dec2hex(B', 4);
CHex = dec2hex(C', 16);
DHex = dec2hex(D', 16);


