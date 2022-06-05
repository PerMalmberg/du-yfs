local pid = {}
pid.__index = pid;

local function new(p, i, d, amortization)
	return setmetatable({amortization = amortization or 0.99, p = p, i = i, d = d, 
    value = 0, prev_val = 0, integral = 0, derivative = 0}, pid)
end

function pid:inject(val)
    self.value = val
	self.integral = self.amortization * self.integral + self.value
	self.derivative = self.value - self.prev_val
	self.prev_val = self.value
end

function pid:get()
	return self.p * self.value 
	     + self.i * self.integral
		 + self.d * self.derivative
end

function pid:reset()
    self.value = 0
	self.prev_val = 0

	self.integral = 0
    self.derivative = 0
 end

-- the module
return setmetatable(
	{
		new = new
	}, {
		__call = function(_, ...) return new(...) end
	}
)