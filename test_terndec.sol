execfile('ternlib.sol')

for i in range(81*2) do
	x = i-81
	t = ternlib.to_tern(x)
	y = ternlib.to_dec(t)
	if x == y then
		p = '..'
	else
		p = '!!'
	end
	print(p, x, t, y)
end
