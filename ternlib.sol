ternlib = {}

ternlib.OP = {
	LD = -12,
	INC = -9,
	SKP = -6,
	ADD = 12,
	STO = 6,
	HALT = -1,
	INV = 3,
	JP = 1,
	NOOP = 0
}

ternlib.REG = {
	A = -1,
	B = 0,
	C = 1
}

ternlib.HAS_IND = {
	[ternlib.OP.JP] = 1,
	[ternlib.OP.LD] = 1,
	[ternlib.OP.STO] = 1,
	[ternlib.OP.ADD] = 1
}

ternlib.HAS_REG = {
	[ternlib.OP.LD] = 1,
	[ternlib.OP.INC] = 1,
	[ternlib.OP.SKP] = 1,
	[ternlib.OP.ADD] = 1,
	[ternlib.OP.STO] = 1,
	[ternlib.OP.INV] = 1
}

ternlib.ipow = func(x, y)
	if y == 0 then return 1 end
	if y < 0 then
		y *= -1
		x = 1 / tofloat(x)
		base = 1
	else
		base = x
	end
	for i in range(y-1) do
		x *= base
	end
	return x
end

ternlib.powsum = func(base, exp)
	accum = 0
	for i in range(exp) do
		accum += ternlib.ipow(base, i)
	end
	return accum
end

ternlib.abs = func(x)
	if x<0 then return -1*x else return x end
end

ternlib.to_tern = func(i)
	exp = 0
	base = 1
	for step in range(32) do
		if base <= ternlib.abs(i) then base *= 3; exp += 1 end
	end
	res = []
	exp += 1
	while exp > 0 do
		exp -= 1
		added = 0
		if i < 0 then
			if i < -1*(ternlib.powsum(3, exp)) then
				res:insert(0, -1)
				i += ternlib.ipow(3, exp)
				added = 1
			end
		else
			if i > ternlib.powsum(3, exp) then
				res:insert(0, 1)
				i -= ternlib.ipow(3, exp)
				added = 1
			end
		end
		if !added then res:insert(0, 0) end
	end
	while 1 do
		if !#res then break end
		if !(res[(#res)-1] == 0) then break end
		res:remove((#res)-1)
	end
	return res
end

ternlib.to_dec = func(t)
	base = 1
	num = 0
	for elem in t do
		num += base * elem
		base *= 3
	end
	return num
end

ternlib.op = {
	TYPE = {
		INSTR = 1,
		LABEL = 2,
		DATA = 3,
		ADDR = 4
	},
	new = func(type, a1, a2, a3)
		res = {type = type, __index = ternlib.op}
		ternlib.op.CONSTRUCT_DISPATCH[type](res, a1, a2, a3)
		return res
	end,
	CONSTRUCT_DISPATCH = {
		[1] = func(self, op, reg, target)
			self.op = op
			self.reg = reg
			self.target = target
		end,
		[2] = func(self, label)
			self.label = label
		end,
		[3] = func(self, data)
			self.data = data
		end,
		[4] = func(self, pos)
			self.pos = pos
		end
	}
}

ternlib.assembler = {
	INTYPE = {
		V1 = 'input_v1'
	},
	OUTTYPE = {
		V1_FLAT = 'output_v1_flat',
		V1_OBJ = 'output_v1_obj',
	},
	NUMTYPE = {
		FIXEDWIDTH = 'numtype_fixedwidth',
		EXPANDED = 'numtype_expanded',
		SUBST = 'numtype_substituted'
	}
	new = func(stream, out, int, outt, numt)
		if None == int then int = ternlib.assembler.INTYPE.V1 end
		if None == outt then outt = ternlib.assembler.OUTTYPE.V1_FLAT end
		if None == numt then numt = ternlib.assembler.NUMTYPE.FIXEDWIDTH end
		return {stream = stream, out = out, int = int, outt = outt, numt = numt, org = -364, labels = {}, errstream = io.stderr, __index = ternlib.assembler}
	end,
	warning = func(self, msg)
		self.errstream:write(msg+chr(10))
	end,
	error = func(self, msg)
		error(msg)
	end,
	IN_DISPATCH = {
		input_v1 = func(self)
			lparts = []
			while 1 do
				ln = self.stream:read(io.LINE)
				lparts = ln:split(" "+chr(10))
				if self.stream:eof() then break end
				if (#lparts) > 1 then break end
			end
			if self.stream:eof() then return None end
			print("inv1: lparts =", lparts)
			if !#lparts then return None end
			instr = lparts[0]
			if instr == 'ADDR' then
				if (#lparts) < 2 then
					self:error("ADDR expects a program label")
				end
				return ternlib.op.new(ternlib.op.TYPE.ADDR, lparts[1])
			end
			if instr == 'DATA' then
				if (#lparts) < 2 then
					self:error("DATA expects a number or label")
				end
				cond = (lparts[1] == "0") || (toint(lparts[1]))
				if !cond then
					return ternlib.op.new(ternlib.op.TYPE.ADDR, lparts[1])
				else
					return ternlib.op.new(ternlib.op.TYPE.DATA, toint(lparts[1]))
				end
			end
			if instr == 'LABEL' then
				if (#lparts) < 2 then
					self:error("LABEL expects a program label")
				end
				return ternlib.op.new(ternlib.op.TYPE.LABEL, lparts[1])
			end
			op = ternlib.OP[instr]
			if None == op then
				self:warning("Unknown instruction: "+instr+"; continuing.")
				return self.IN_DISPATCH.input_v1(self)
			end
			if (#lparts) > 1 then
				args = lparts[1]:split(",")
			else
				args = []
			end
			if !(None == ternlib.HAS_REG[op]) then
				if #args then
					reg = ternlib.REG[args[0]]
				else
					self:error("Expected register argument to "+instr)
				end
				if None == reg then
					self:error("Invalid register name: "+(args[0]))
				end
				args:remove(0)
			else
				reg = None
			end
			if !(None == ternlib.HAS_IND[op]) then
				if #args then
					target = args[0]
					args:remove(0)
				else
					lparts = []
					while 1 do
						ln = self.stream:read(io.LINE)
						lparts = ln:split(" "+chr(10))
						if self.stream:eof() then break end
						if #lparts then break end
					end
					if self.stream:eof() then
						self:error("EOF while finding indirect address for "+instr)
					end
					if (#lparts) == 1 then
						target = lparts[0]
					end
					if (#lparts) >= 2 then
						if None == {ADDR=1, DATA=1}[lparts[0]] then
							self:warning("Expected ADDR or DATA specifier, got "+(lparts[0]))
						end
						target = lparts[1]
					end
				end
				print("inv1: Ind target =", target)
				if toint(target) then
					target = toint(target)
				end
			else
				target = None
			end
			return ternlib.op.new(ternlib.op.TYPE.INSTR, op, reg, target)
		end
	},
	OUT_DISPATCH = {
		output_v1_flat = func(self, op)
			return {
				[ternlib.op.TYPE.INSTR] = func()
					instr = op.op
					if !(None == ternlib.HAS_REG[op.op]) then
						instr += op.reg
					end
					if !(None == ternlib.HAS_IND[op.op]) then
						if type(op.target) == "string" then
							return [instr, {addr = op.target}]
						else
							return [instr, op.target]
						end
					else
						return [instr]
					end
				end,
				[ternlib.op.TYPE.LABEL] = func()
					return [{label = op.label}]
				end,
				[ternlib.op.TYPE.DATA] = func()
					return [op.data]
				end,
				[ternlib.op.TYPE.ADDR] = func()
					return [{addr = op.pos}]
				end
			}[op.type]()
		end,
		output_v1_obj = func(self, op)
			self:error("Not implemented")
		end
	},
	NUM_DISPATCH = {
		numtype_fixedwidth = func(self, num)
			if None == self.width then
				self.width = 6
			end
			s = ""
			tern = ternlib.to_tern(num)
			if (#tern) > self.width then
				self:warning("Fixedwidth truncation of ternary "+tostring(tern)+" (="+tostring(num)+") using width "+tostring(self.width))
			end
			for idx in range(self.width) do
				if idx < (#tern) then
					trit = tern[idx]
				else
					trit = 0
				end
				s += tostring(trit) + " "
			end
			return s:sub(0, -1)+chr(10)
		end,
		numtype_expanded = func(self, num)
			s = ""
			print("ntex: Input is", num)
			tern = ternlib.to_tern(num)
			print("ntex: Ternary is", tern)
			for trit in tern do
				s += tostring(trit) + " "
			end
			print("ntex: Output is", s)
			return s:sub(0, -1)+chr(10)
		end,
		numtype_substituted = func(self, num)
			s = ""
			for trit in ternlib.to_tern(num) do
				s += {[-1] = "T", [0] = "0", [1] = "1"}[trit]
			end
			return s+chr(10)
		end
	},
	assemble = func(self)
		addrs = {}
		symbols = []
		while !self.stream:eof() do
			op = self.IN_DISPATCH[self.int](self)
			print("asm: Generated", op)
			if op == None then break end
			outputs = self.OUT_DISPATCH[self.outt](self, op)
			print("asm: Outputs:", outputs)
			for num in outputs do
				if type(num) == "map" then
					if !(num.label == None) then
						self.labels[num.label] = self.org
					end
					if !(num.addr == None) then
						addrs[#symbols] = num.addr
						symbols:insert(#symbols, 0)
						self.org += 1
					end
				else
					symbols:insert(#symbols, num)
					self.org += 1
				end
			end
		end
		print("asm: Resolution begins, labels are", self.labels, ", tape is", symbols)
		for idx in addrs do
			print("asm: Resolve", idx, "to", addrs[idx])
			if None == self.labels[addrs[idx]] then
				self:error("Undefined label: "+(addrs[idx]))
			end
			symbols[idx] = self.labels[addrs[idx]]
		end
		print("asm: Postresolution tape is", symbols)
		for sym in symbols do
			self.out:write(self.NUM_DISPATCH[self.numt](self, sym))
		end
		return addrs
	end
}
