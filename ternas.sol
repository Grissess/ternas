execfile('ternlib.sol')

inf = io.open('/tmp/in.ternas', io.MODE_READ)
outf = io.open('/tmp/out.tern', io.MODE_WRITE|io.MODE_TRUNCATE)

asm = ternlib.assembler.new(inf, outf)
print(asm:assemble())

outf:write(chr(10)+"Generated Labels:"+chr(10))
for label in asm.labels do
	outf:write(label+" at address "+tostring(asm.labels[label])+chr(10))
end

outf:flush()
