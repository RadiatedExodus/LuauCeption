type Memory = {
	[number]: buffer,
	maximum: number,
}

local function rt_memory_new(initializer: { string }, minimum: number, maximum: number): Memory
	local data = buffer.create(minimum)

	for offset, content in initializer do
		buffer.writestring(data, offset, content)
	end

	return { data, maximum = maximum }
end

local bit32_or = bit32.bor

local function rt_subtract_i32(lhs: number, rhs: number): number
	local result = bit32_or(lhs - rhs, 0)

	return result
end

local buffer_write_u32 = buffer.writeu32

local function rt_store_i32(destination: Memory, offset: number, source: number)
	buffer_write_u32(destination[1], offset, source)
end

local function rt_add_i32(lhs: number, rhs: number): number
	local result = bit32_or(lhs + rhs, 0)

	return result
end

local function rt_not_equal_i32(lhs: number, rhs: number): boolean
	return lhs ~= rhs
end

local buffer_read_u32 = buffer.readu32

local function rt_load_i32(source: Memory, offset: number): number
	local result = buffer_read_u32(source[1], offset)

	return result
end

local function rt_equal_i32(lhs: number, rhs: number): boolean
	return lhs == rhs
end

local rt_exclusive_or_i32 = bit32.bxor

local bit32_and = bit32.band

local bit32_rshift = bit32.rshift

local function rt_shift_right_u32(lhs: number, rhs: number): number
	rhs = bit32_and(rhs, 0x1F)

	local result = bit32_rshift(lhs, rhs)

	return result
end

local rt_and_i32 = bit32.band

local bit32_lshift = bit32.lshift

local function rt_shift_left_i32(lhs: number, rhs: number): number
	rhs = bit32_and(rhs, 0x1F)

	local result = bit32_lshift(lhs, rhs)

	return result
end

local function rt_less_than_equal_u32(lhs: number, rhs: number): boolean
	return lhs <= rhs
end

local function rt_less_than_u32(lhs: number, rhs: number): boolean
	return lhs < rhs
end

local function rt_multiply_i32(lhs: number, rhs: number): number
	if (lhs + rhs) < 0x800_0000 then
		local result = bit32_or(lhs * rhs, 0)

		return result
	else
		local a16 = bit32_rshift(lhs, 16)
		local a00 = bit32_and(lhs, 0xFFFF)
		local b16 = bit32_rshift(rhs, 16)
		local b00 = bit32_and(rhs, 0xFFFF)

		local c00 = a00 * b00
		local c16 = a16 * b00 + a00 * b16

		local result = bit32_or(c00 + bit32_lshift(c16, 16), 0)

		return result
	end
end

local function rt_greater_than_equal_u32(lhs: number, rhs: number): boolean
	return lhs >= rhs
end

type Table<T> = {
	[number]: T,
	minimum: number,
	maximum: number,
}

local function rt_table_new<T>(initializer: { T }, minimum: number, maximum: number): Table<T>
	local result = table.create(minimum)

	for offset, element in initializer do
		result[offset] = element
	end

	result.minimum = minimum
	result.maximum = maximum

	return result
end

local function rt_table_get<T>(source: Table<T>, offset: number): T
	assert(offset < source.minimum, "out of bounds table access")

	return source[offset]
end

local function rt_greater_than_u32(lhs: number, rhs: number): boolean
	return lhs > rhs
end

local buffer_write_u8 = buffer.writeu8

local function rt_store_i32_into_i8(destination: Memory, offset: number, source: number)
	buffer_write_u8(destination[1], offset, source)
end

local buffer_write_f64 = buffer.writef64

local TRANSMUTE_N64 = buffer.create(8)

local function from_bits_i64(source: number): (number, number)
	buffer_write_f64(TRANSMUTE_N64, 0, source)

	return buffer_read_u32(TRANSMUTE_N64, 0), buffer_read_u32(TRANSMUTE_N64, 4)
end

local function rt_store_i64(destination: Memory, offset: number, source: number)
	local source_1, source_2 = from_bits_i64(source)

	buffer_write_u32(destination[1], offset + 4, source_2)
	buffer_write_u32(destination[1], offset, source_1)
end

local buffer_read_f64 = buffer.readf64

local function into_bits_i64(source_1: number, source_2: number): number
	buffer_write_u32(TRANSMUTE_N64, 0, source_1)
	buffer_write_u32(TRANSMUTE_N64, 4, source_2)

	return buffer_read_f64(TRANSMUTE_N64, 0)
end

local buffer_read_u16 = buffer.readu16

local function rt_load_i32_from_u16(source: Memory, offset: number): number
	local result = buffer_read_u16(source[1], offset)

	return result
end

local buffer_write_u16 = buffer.writeu16

local function rt_store_i32_into_i16(destination: Memory, offset: number, source: number)
	buffer_write_u16(destination[1], offset, source)
end

local buffer_read_u8 = buffer.readu8

local function rt_load_i32_from_u8(source: Memory, offset: number): number
	local result = buffer_read_u8(source[1], offset)

	return result
end

local rt_or_i32 = bit32.bor

local function rt_memory_fill(destination: Memory, offset: number, source: number, size: number)
	buffer.fill(destination[1], offset, source, size)
end

local bit32_xor = bit32.bxor

local function rt_less_than_s32(lhs: number, rhs: number): boolean
	lhs = bit32_xor(lhs, 0x8000_0000)
	rhs = bit32_xor(rhs, 0x8000_0000)

	return lhs < rhs
end

local function rt_load_f64(source: Memory, offset: number): number
	return buffer_read_f64(source[1], offset)
end

local function rt_store_f64(destination: Memory, offset: number, source: number)
	buffer_write_f64(destination[1], offset, source)
end

local rt_absolute_f64 = math.abs

local rt_round_up_f64 = math.ceil

local function rt_divide_f64(lhs: number, rhs: number): number
	return lhs / rhs
end

local rt_round_down_f64 = math.floor

local math_modf = math.modf

local function rt_saturate_f64_to_s32(source: number): number
	if source >= 0x8000_0000 then
		source = 0x7FFF_FFFF
	elseif source <= -0x8000_0000 then
		source = 0x8000_0000
	elseif source ~= source then
		source = 0
	else
		source = math_modf(source)
		source = bit32_or(source, 0)
	end

	return source
end

local function rt_equal_f64(lhs: number, rhs: number): boolean
	return lhs == rhs
end

local function rt_less_than_f64(lhs: number, rhs: number): boolean
	return lhs < rhs
end

local function rt_greater_than_f64(lhs: number, rhs: number): boolean
	return lhs > rhs
end

local function rt_multiply_f64(lhs: number, rhs: number): number
	return lhs * rhs
end

local rt_square_root_f64 = math.sqrt

local function rt_convert_u32_to_f64(source: number): number
	return source
end

local bit32_arshift = bit32.arshift

local function rt_shift_right_s32(lhs: number, rhs: number): number
	rhs = bit32_and(rhs, 0x1F)

	local result = bit32_arshift(lhs, rhs)

	return result
end

local function rt_narrow_i64(source: number): number
	source = from_bits_i64(source)

	return source
end

local I64_0000_0000_0000_0000 = into_bits_i64(0, 0)

local I64_7FFF_FFFF_FFFF_FFFF = into_bits_i64(0xFFFF_FFFF, 0x7FFF_FFFF)

local I64_8000_0000_0000_0000 = into_bits_i64(0x0000_0000, 0x8000_0000)

local function convert_f64_to_u64(source: number): number
	local source_1 = bit32_or(source % 0x1_0000_0000, 0)
	local source_2 = bit32_or(source / 0x1_0000_0000, 0)

	source = into_bits_i64(source_1, source_2)

	return source
end

local math_ceil = math.ceil

local math_floor = math.floor

local bit32_not = bit32.bnot

local function negate_i64(source: number): number
	local source_1, source_2 = from_bits_i64(source)

	source_1 = bit32_not(source_1) + 1
	source_2 = bit32_not(source_2)

	if source_1 >= 0x1_0000_0000 then
		source_1 = source_1 - 0x1_0000_0000
		source_2 = source_2 + 1
	end

	if source_2 >= 0x1_0000_0000 then
		source_2 = source_2 - 0x1_0000_0000
	end

	source = into_bits_i64(source_1, source_2)

	return source
end

local function rt_saturate_f64_to_s64(source: number): number
	if source >= 0x8000_0000_0000_0000 then
		source = I64_7FFF_FFFF_FFFF_FFFF
	elseif source <= -0x8000_0000_0000_0000 then
		source = I64_8000_0000_0000_0000
	elseif source ~= source then
		source = I64_0000_0000_0000_0000
	elseif source >= 0 then
		source = math_floor(source)
		source = convert_f64_to_u64(source)
	else
		source = math_ceil(source)
		source = convert_f64_to_u64(-source)
		source = negate_i64(source)
	end

	return source
end

local function rt_less_than_equal_s32(lhs: number, rhs: number): boolean
	lhs = bit32_xor(lhs, 0x8000_0000)
	rhs = bit32_xor(rhs, 0x8000_0000)

	return lhs <= rhs
end

local function rt_greater_than_s32(lhs: number, rhs: number): boolean
	lhs = bit32_xor(lhs, 0x8000_0000)
	rhs = bit32_xor(rhs, 0x8000_0000)

	return lhs > rhs
end

local bit32_lrotate = bit32.lrotate

local function rt_rotate_left_i32(lhs: number, rhs: number): number
	rhs = bit32_and(rhs, 0x1F)

	local result = bit32_lrotate(lhs, rhs)

	return result
end

local bit32_rrotate = bit32.rrotate

local function rt_rotate_right_i32(lhs: number, rhs: number): number
	rhs = bit32_and(rhs, 0x1F)

	local result = bit32_rrotate(lhs, rhs)

	return result
end

local function rt_greater_than_equal_s32(lhs: number, rhs: number): boolean
	lhs = bit32_xor(lhs, 0x8000_0000)
	rhs = bit32_xor(rhs, 0x8000_0000)

	return lhs >= rhs
end

local function rt_less_than_equal_f64(lhs: number, rhs: number): boolean
	return lhs <= rhs
end

local buffer_write_f32 = buffer.writef32

local function rt_store_f32(destination: Memory, offset: number, source: number)
	buffer_write_u32(destination[1], offset, source)
end

local function rt_narrow_f64(source: number): number
	buffer_write_f32(TRANSMUTE_N64, 0, source)

	return buffer_read_u32(TRANSMUTE_N64, 0)
end

local function rt_add_f64(lhs: number, rhs: number): number
	return lhs + rhs
end

local function rt_subtract_f64(lhs: number, rhs: number): number
	return lhs - rhs
end

local function rt_not_equal_f64(lhs: number, rhs: number): boolean
	return lhs ~= rhs
end

local function rt_load_i64(source: Memory, offset: number): number
	local memory = source[1]
	local source_1 = buffer_read_u32(memory, offset)
	local source_2 = buffer_read_u32(memory, offset + 4)

	return into_bits_i64(source_1, source_2)
end

local function rt_less_than_u64(lhs: number, rhs: number): boolean
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	return lhs_2 < rhs_2 or (lhs_2 == rhs_2 and lhs_1 < rhs_1)
end

local function raw_shift_left_i64(lhs: number, rhs: number): number
	local source_1, source_2 = from_bits_i64(lhs)

	if rhs >= 32 then
		rhs = bit32_lshift(source_1, rhs - 32)
		lhs = 0
	else
		lhs = bit32_lshift(source_1, rhs)
		rhs = bit32_or(bit32_lshift(source_2, rhs), bit32_rshift(source_1, 32 - rhs))
	end

	local result = into_bits_i64(lhs, rhs)

	return result
end

local function rt_shift_left_i64(lhs: number, rhs: number): number
	rhs = bit32_and(from_bits_i64(rhs), 0x3F)
	lhs = raw_shift_left_i64(lhs, rhs)

	return lhs
end

local function rt_load_f32(source: Memory, offset: number): number
	return buffer_read_u32(source[1], offset)
end

local buffer_read_f32 = buffer.readf32

local function rt_widen_f32(source: number): number
	buffer_write_u32(TRANSMUTE_N64, 0, source)

	return buffer_read_f32(TRANSMUTE_N64, 0)
end

local function rt_divide_s32(lhs: number, rhs: number): number
	if lhs == 0x8000_0000 and rhs == 0xFFFF_FFFF then
		error("integer overflow")
	elseif rhs == 0 then
		error("integer divide by zero")
	end

	lhs = bit32_xor(lhs, 0x8000_0000) - 0x8000_0000
	rhs = bit32_xor(rhs, 0x8000_0000) - 0x8000_0000

	local result = lhs / rhs

	result = math_modf(result)
	result = bit32_or(result, 0)

	return result
end

local function rt_memory_copy(destination: Memory, offset_1: number, source: Memory, offset_2: number, size: number)
	buffer.copy(destination[1], offset_1, source[1], offset_2, size)
end

local function rt_negate_f64(source: number): number
	return -source
end

local function rt_negate_f32(source: number): number
	source = bit32_xor(source, 0x8000_0000)

	return source
end

local function from_bits_f32(source: number): number
	buffer_write_u32(TRANSMUTE_N64, 0, source)

	return buffer_read_f32(TRANSMUTE_N64, 0)
end

local function into_bits_f32(source: number): number
	buffer_write_f32(TRANSMUTE_N64, 0, source)

	return buffer_read_u32(TRANSMUTE_N64, 0)
end

local vector_create = vector.create

local function rt_add_f32(lhs: number, rhs: number): number
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	local result = vector_create(lhs, 0, 0) + vector_create(rhs, 0, 0)

	result = into_bits_f32(result.x)

	return result
end

local function rt_subtract_f32(lhs: number, rhs: number): number
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	local result = vector_create(lhs, 0, 0) - vector_create(rhs, 0, 0)

	result = into_bits_f32(result.x)

	return result
end

local function rt_multiply_f32(lhs: number, rhs: number): number
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	local result = vector_create(lhs, 0, 0) * vector_create(rhs, 0, 0)

	result = into_bits_f32(result.x)

	return result
end

local function rt_equal_f32(lhs: number, rhs: number): boolean
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	return lhs == rhs
end

local function rt_not_equal_f32(lhs: number, rhs: number): boolean
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	return lhs ~= rhs
end

local function rt_divide_f32(lhs: number, rhs: number): number
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	local result = vector_create(lhs, 0, 0) / vector_create(rhs, 0, 0)

	result = into_bits_f32(result.x)

	return result
end

local function rt_round_down_f32(source: number): number
	source = from_bits_f32(source)
	source = math_floor(source)
	source = into_bits_f32(source)

	return source
end

local buffer_read_i8 = buffer.readi8

local function rt_load_i32_from_s8(source: Memory, offset: number): number
	local result = buffer_read_i8(source[1], offset)

	result = bit32_or(result, 0)

	return result
end

local function rt_greater_than_equal_f64(lhs: number, rhs: number): boolean
	return lhs >= rhs
end

local function rt_remainder_u32(lhs: number, rhs: number): number
	if rhs == 0 then
		error("integer divide by zero", 2)
	end

	local result = lhs % rhs

	result = bit32_or(result, 0)

	return result
end

local function rt_equal_i64(lhs: number, rhs: number): boolean
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	return lhs_1 == rhs_1 and lhs_2 == rhs_2
end

local function rt_saturate_f64_to_u32(source: number): number
	if source >= 0x1_0000_0000 then
		source = 0xFFFF_FFFF
	elseif source <= 0 or source ~= source then
		source = 0
	else
		source = math_floor(source)
		source = bit32_or(source, 0)
	end

	return source
end

local function rt_extend_s8_to_i32(source: number): number
	source = bit32_and(source, 0xFF)

	if source >= 0x80 then
		source = bit32_or(source - 0x100, 0)
	end

	return source
end

local function rt_widen_i32(source: number): number
	source = into_bits_i64(source, 0)

	return source
end

local function rt_add_i64(lhs: number, rhs: number): number
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	lhs = lhs_1 + rhs_1
	rhs = lhs_2 + rhs_2

	if lhs >= 0x1_0000_0000 then
		lhs = lhs - 0x1_0000_0000
		rhs = rhs + 1
	end

	if rhs >= 0x1_0000_0000 then
		rhs = rhs - 0x1_0000_0000
	end

	local result = into_bits_i64(lhs, rhs)

	return result
end

local function rt_not_equal_i64(lhs: number, rhs: number): boolean
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	return lhs_1 ~= rhs_1 or lhs_2 ~= rhs_2
end

local function raw_shift_right_u64(lhs: number, rhs: number): number
	local source_1, source_2 = from_bits_i64(lhs)

	if rhs >= 32 then
		lhs = bit32_rshift(source_2, rhs - 32)
		rhs = 0
	else
		lhs = bit32_or(bit32_rshift(source_1, rhs), bit32_lshift(source_2, 32 - rhs))
		rhs = bit32_rshift(source_2, rhs)
	end

	local result = into_bits_i64(lhs, rhs)

	return result
end

local function rt_shift_right_u64(lhs: number, rhs: number): number
	rhs = bit32_and(from_bits_i64(rhs), 0x3F)
	lhs = raw_shift_right_u64(lhs, rhs)

	return lhs
end

local rt_truncate_f64 = math.modf

local function rt_and_i64(lhs: number, rhs: number): number
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	lhs = bit32_and(lhs_1, rhs_1)
	rhs = bit32_and(lhs_2, rhs_2)

	local result = into_bits_i64(lhs, rhs)

	return result
end

local function rt_or_i64(lhs: number, rhs: number): number
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	lhs = bit32_or(lhs_1, rhs_1)
	rhs = bit32_or(lhs_2, rhs_2)

	local result = into_bits_i64(lhs, rhs)

	return result
end

local function rt_subtract_i64(lhs: number, rhs: number): number
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	lhs = lhs_1 - rhs_1
	rhs = lhs_2 - rhs_2

	if lhs < 0 then
		lhs = lhs + 0x1_0000_0000
		rhs = rhs - 1
	end

	if rhs < 0 then
		rhs = rhs + 0x1_0000_0000
	end

	local result = into_bits_i64(lhs, rhs)

	return result
end

local bit32_replace = bit32.replace

local function from_bits_i64_to_i16(source: number): (number, number, number, number)
	buffer_write_f64(TRANSMUTE_N64, 0, source)

	return buffer_read_u16(TRANSMUTE_N64, 0),
		buffer_read_u16(TRANSMUTE_N64, 2),
		buffer_read_u16(TRANSMUTE_N64, 4),
		buffer_read_u16(TRANSMUTE_N64, 6)
end

local function multiply_fast_i64(lhs: number, rhs: number): number?
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	return if lhs_2 == 0
			and rhs_2 == 0
			and lhs_1 <= 0x400_0000
			and rhs_1 <= 0x400_0000
		then convert_f64_to_u64(lhs_1 * rhs_1)
		else nil
end

local function rt_multiply_i64(lhs: number, rhs: number): number
	local result = multiply_fast_i64(lhs, rhs)

	if result then
		return result
	end

	local a00, a16, a32, a48 = from_bits_i64_to_i16(lhs)
	local b00, b16, b32, b48 = from_bits_i64_to_i16(rhs)

	local c00 = a00 * b00
	local c16 = bit32_rshift(c00, 16)

	c00 = bit32_and(c00, 0xFFFF)
	c16 = c16 + a16 * b00

	local c32 = bit32_rshift(c16, 16)

	c16 = bit32_and(c16, 0xFFFF)
	c16 = c16 + a00 * b16
	c32 = c32 + bit32_rshift(c16, 16)
	c16 = bit32_and(c16, 0xFFFF)
	c32 = c32 + a32 * b00

	local c48 = bit32_rshift(c32, 16)

	c32 = bit32_and(c32, 0xFFFF)
	c32 = c32 + a16 * b16
	c48 = c48 + bit32_rshift(c32, 16)
	c32 = bit32_and(c32, 0xFFFF)
	c32 = c32 + a00 * b32
	c48 = c48 + bit32_rshift(c32, 16)
	c32 = bit32_and(c32, 0xFFFF)
	c48 = c48 + a48 * b00 + a32 * b16 + a16 * b32 + a00 * b48
	c48 = bit32_and(c48, 0xFFFF)

	lhs = bit32_replace(c00, c16, 16, 16)
	rhs = bit32_replace(c32, c48, 16, 16)

	result = into_bits_i64(lhs, rhs)

	return result
end

local function rt_extend_s32_to_i64(source: number): number
	source = from_bits_i64(source)
	source = bit32_and(source, 0xFFFF_FFFF)

	if source < 0x8000_0000 then
		source = into_bits_i64(source, 0)
	else
		source = bit32_or(source - 0x1_0000_0000, 0)
		source = into_bits_i64(source, 0xFFFF_FFFF)
	end

	return source
end

local function rt_greater_than_u64(lhs: number, rhs: number): boolean
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	return lhs_2 > rhs_2 or (lhs_2 == rhs_2 and lhs_1 > rhs_1)
end

local function rt_less_than_equal_u64(lhs: number, rhs: number): boolean
	return not rt_greater_than_u64(lhs, rhs)
end

local function rt_convert_s32_to_f64(source: number): number
	source = bit32_xor(source, 0x8000_0000) - 0x8000_0000

	return source
end

local function rt_divide_u32(lhs: number, rhs: number): number
	if rhs == 0 then
		error("integer divide by zero")
	end

	return lhs // rhs
end

local function rt_extend_s16_to_i32(source: number): number
	source = bit32_and(source, 0xFFFF)

	if source >= 0x8000 then
		source = bit32_or(source - 0x1_0000, 0)
	end

	return source
end

local function flip_most_significant(source: number): number
	local source_1, source_2 = from_bits_i64(source)

	source_2 = bit32_xor(source_2, 0x8000_0000)
	source = into_bits_i64(source_1, source_2)

	return source
end

local function rt_less_than_s64(lhs: number, rhs: number): boolean
	lhs = flip_most_significant(lhs)
	rhs = flip_most_significant(rhs)

	local result = rt_less_than_u64(lhs, rhs)

	return result
end

local function rt_transmute_f64_to_i64(source: number): number
	return source
end

local I64_0000_0000_0000_0040 = into_bits_i64(0x40, 0)

local function rt_rotate_left_i64(lhs: number, rhs: number): number
	local result = rt_shift_left_i64(lhs, rhs)

	rhs = rt_subtract_i64(I64_0000_0000_0000_0040, rhs)
	lhs = rt_shift_right_u64(lhs, rhs)

	result = rt_or_i64(lhs, result)

	return result
end

local function rt_count_ones_i32(source: number): number
	source = source - bit32_and(bit32_rshift(source, 1), 0x5555_5555)
	source = bit32_and(source, 0x3333_3333) + bit32_and(bit32_rshift(source, 2), 0x3333_3333)
	source = bit32_and(source + bit32_rshift(source, 4), 0x0F0F_0F0F)
	source = source + bit32_rshift(source, 8)
	source = source + bit32_rshift(source, 16)
	source = bit32_and(source, 0x0000_003F)

	return source
end

local function rt_store_i64_into_i32(destination: Memory, offset: number, source: number)
	local source_1 = from_bits_i64(source)

	buffer_write_u32(destination[1], offset, source_1)
end

local function rt_convert_u32_to_f32(source: number): number
	buffer_write_f32(TRANSMUTE_N64, 0, source)

	source = buffer_read_u32(TRANSMUTE_N64, 0)

	return source
end

local function rt_greater_than_f32(lhs: number, rhs: number): boolean
	lhs = from_bits_f32(lhs)
	rhs = from_bits_f32(rhs)

	return lhs > rhs
end

local function rt_saturate_f32_to_u32(source: number): number
	source = from_bits_f32(source)

	if source >= 0x1_0000_0000 then
		source = 0xFFFF_FFFF
	elseif source <= 0 or source ~= source then
		source = 0
	else
		source = math_floor(source)
	end

	source = bit32_or(source, 0)

	return source
end

local function rt_round_up_f32(source: number): number
	source = from_bits_f32(source)
	source = math_ceil(source)
	source = into_bits_f32(source)

	return source
end

local rt_leading_zeroes_i32 = bit32.countlz

local function rt_load_i64_from_u32(source: Memory, offset: number): number
	local source = buffer_read_u32(source[1], offset)

	return into_bits_i64(source, 0)
end

local function rt_convert_u64_to_f64(source: number): number
	local source_1, source_2 = from_bits_i64(source)

	return source_1 + source_2 * 0x1_0000_0000
end

local I64_FFFF_FFFF_FFFF_FFFF = into_bits_i64(0xFFFF_FFFF, 0xFFFF_FFFF)

local function rt_saturate_f64_to_u64(source: number): number
	if source >= 0x1_0000_0000_0000_0000 then
		source = I64_FFFF_FFFF_FFFF_FFFF
	elseif source <= 0 or source ~= source then
		source = I64_0000_0000_0000_0000
	else
		source = math_floor(source)
		source = convert_f64_to_u64(source)
	end

	return source
end

local function rt_greater_than_equal_u64(lhs: number, rhs: number): boolean
	return not rt_less_than_u64(lhs, rhs)
end

local function rt_store_i64_into_i8(destination: Memory, offset: number, source: number)
	local source_1 = from_bits_i64(source)

	buffer_write_u8(destination[1], offset, source_1)
end

local buffer_read_i32 = buffer.readi32

local function rt_load_i64_from_s32(source: Memory, offset: number): number
	local source = buffer_read_i32(source[1], offset)

	return if source >= 0 then into_bits_i64(source, 0) else into_bits_i64(source + 0x1_0000_0000, 0xFFFF_FFFF)
end

local function rt_greater_than_equal_s64(lhs: number, rhs: number): boolean
	return not rt_less_than_s64(lhs, rhs)
end

local function rt_greater_than_s64(lhs: number, rhs: number): boolean
	lhs = flip_most_significant(lhs)
	rhs = flip_most_significant(rhs)

	local result = rt_greater_than_u64(lhs, rhs)

	return result
end

local function rt_less_than_equal_s64(lhs: number, rhs: number): boolean
	return not rt_greater_than_s64(lhs, rhs)
end

local function rt_transmute_i64_to_f64(source: number): number
	return source
end

local rt_trailing_zeroes_i32 = bit32.countrz

local function rt_memory_size(source: Memory): number
	return buffer.len(source[1])
end

local function rt_exclusive_or_i64(lhs: number, rhs: number): number
	local lhs_1, lhs_2 = from_bits_i64(lhs)
	local rhs_1, rhs_2 = from_bits_i64(rhs)

	lhs = bit32_xor(lhs_1, rhs_1)
	rhs = bit32_xor(lhs_2, rhs_2)

	local result = into_bits_i64(lhs, rhs)

	return result
end

local bit32_countlz = bit32.countlz

local function raw_leading_zeroes_i64(source: number): number
	buffer_write_f64(TRANSMUTE_N64, 0, source)

	source = buffer_read_u32(TRANSMUTE_N64, 4)

	if source == 0 then
		source = buffer_read_u32(TRANSMUTE_N64, 0)
		source = bit32_countlz(source) + 32
	else
		source = bit32_countlz(source)
	end

	return source
end

local function rt_leading_zeroes_i64(source: number): number
	source = raw_leading_zeroes_i64(source)
	source = into_bits_i64(source, 0)

	return source
end

local function rt_transmute_f32_to_i32(source: number): number
	return source
end

local function is_positive(source: number): boolean
	buffer_write_f64(TRANSMUTE_N64, 0, source)

	return buffer_read_i8(TRANSMUTE_N64, 7) >= 0
end

local math_abs = math.abs

local function rt_copy_sign_f64(lhs: number, rhs: number): number
	lhs = math_abs(lhs)

	if not is_positive(rhs) then
		lhs = -lhs
	end

	return lhs
end

local function rt_convert_s32_to_f32(source: number): number
	source = bit32_xor(source, 0x8000_0000) - 0x8000_0000

	buffer_write_f32(TRANSMUTE_N64, 0, source)

	source = buffer_read_u32(TRANSMUTE_N64, 0)

	return source
end

local math_fmod = math.fmod

local function rt_remainder_s32(lhs: number, rhs: number): number
	if rhs == 0 then
		error("integer divide by zero", 2)
	end

	lhs = bit32_xor(lhs, 0x8000_0000) - 0x8000_0000
	rhs = bit32_xor(rhs, 0x8000_0000) - 0x8000_0000

	local result = math_fmod(lhs, rhs)

	result = bit32_or(result, 0)

	return result
end

local I64_0000_0000_0000_0001 = into_bits_i64(1, 0)

local function is_all_zeroes(source: number): boolean
	buffer_write_f64(TRANSMUTE_N64, 0, source)

	return buffer_read_u32(TRANSMUTE_N64, 0) == 0 and buffer_read_u32(TRANSMUTE_N64, 4) == 0
end

local function rt_truncate_f64_to_u64(source: number): number
	source = math_modf(source)

	if source >= 0x1_0000_0000_0000_0000 or source < 0 then
		error("integer overflow")
	elseif source ~= source then
		error("invalid conversion to integer")
	end

	source = convert_f64_to_u64(source)

	return source
end

local function rt_divide_u64(lhs: number, rhs: number): number
	if is_all_zeroes(rhs) then
		error("integer divide by zero")
	end

	local lhs_zeroes = raw_leading_zeroes_i64(lhs)
	local rhs_zeroes = raw_leading_zeroes_i64(rhs)

	if lhs_zeroes >= 11 and rhs_zeroes >= 11 then
		lhs = rt_convert_u64_to_f64(lhs)
		rhs = rt_convert_u64_to_f64(rhs)

		local result = rt_truncate_f64_to_u64(lhs / rhs)

		return result
	elseif lhs_zeroes > rhs_zeroes then
		return 0
	end

	local quotient = 0
	local remainder = lhs

	for offset = rhs_zeroes - lhs_zeroes, 0, -1 do
		local divisor = raw_shift_left_i64(rhs, offset)

		if rt_greater_than_equal_u64(remainder, divisor) then
			remainder = rt_subtract_i64(remainder, divisor)
			quotient = rt_or_i64(raw_shift_left_i64(I64_0000_0000_0000_0001, offset), quotient)
		end
	end

	return quotient
end

local buffer_read_i16 = buffer.readi16

local function rt_load_i64_from_s16(source: Memory, offset: number): number
	local source = buffer_read_i16(source[1], offset)

	return if source >= 0 then into_bits_i64(source, 0) else into_bits_i64(source + 0x1_0000_0000, 0xFFFF_FFFF)
end

local function rt_load_i64_from_u16(source: Memory, offset: number): number
	local source = buffer_read_u16(source[1], offset)

	return into_bits_i64(source, 0)
end

local function rt_load_i64_from_s8(source: Memory, offset: number): number
	local source = buffer_read_i8(source[1], offset)

	return if source >= 0 then into_bits_i64(source, 0) else into_bits_i64(source + 0x1_0000_0000, 0xFFFF_FFFF)
end

local function rt_load_i64_from_u8(source: Memory, offset: number): number
	local source = buffer_read_u8(source[1], offset)

	return into_bits_i64(source, 0)
end

local math_max = math.max

local function rt_maximum_f64(lhs: number, rhs: number): number
	if is_positive(rhs) then
		lhs, rhs = rhs, lhs
	end

	local result = math_max(lhs, rhs)

	return result
end

local function rt_table_set<T>(destination: Table<T>, offset: number, source: T)
	assert(offset < destination.minimum, "out of bounds table access")

	destination[offset] = source
end

local function rt_table_copy<T>(destination: Table<T>, offset_1: number, source: Table<T>, offset_2: number, size: number)
	assert(offset_1 + size <= destination.minimum, "out of bounds table access")
	assert(offset_2 + size <= source.minimum, "out of bounds table access")

	table.move(source, offset_2, offset_2 + size - 1, offset_1, destination)
end

local function rt_table_drop<T>(destination: Table<T>)
	if table.isfrozen(destination) then
		return
	end

	table.clear(destination)

	destination.minimum = 0
	destination.maximum = 0

	table.freeze(destination)
end

local function rt_memory_drop(destination: Memory)
	if table.isfrozen(destination) then
		return
	end

	table.clear(destination)

	destination[1] = buffer.create(0)

	destination.maximum = 0

	table.freeze(destination)
end

return {
    rt_memory_new = rt_memory_new,
    rt_subtract_i32 = rt_subtract_i32,
    rt_store_i32 = rt_store_i32,
    rt_add_i32 = rt_add_i32,
    rt_not_equal_i32 = rt_not_equal_i32,
    rt_load_i32 = rt_load_i32,
    rt_equal_i32 = rt_equal_i32,
    rt_shift_right_u32 = rt_shift_right_u32,
    rt_shift_left_i32 = rt_shift_left_i32,
    rt_less_than_equal_u32 = rt_less_than_equal_u32,
    rt_less_than_u32 = rt_less_than_u32,
    rt_multiply_i32 = rt_multiply_i32,
    rt_greater_than_equal_u32 = rt_greater_than_equal_u32,
    rt_table_new = rt_table_new,
    rt_table_get = rt_table_get,
    rt_greater_than_u32 = rt_greater_than_u32,
    rt_store_i32_into_i8 = rt_store_i32_into_i8,
    from_bits_i64 = from_bits_i64,
    rt_store_i64 = rt_store_i64,
    into_bits_i64 = into_bits_i64,
    rt_load_i32_from_u16 = rt_load_i32_from_u16,
    rt_store_i32_into_i16 = rt_store_i32_into_i16,
    rt_load_i32_from_u8 = rt_load_i32_from_u8,
    rt_memory_fill = rt_memory_fill,
    rt_less_than_s32 = rt_less_than_s32,
    rt_load_f64 = rt_load_f64,
    rt_store_f64 = rt_store_f64,
    rt_divide_f64 = rt_divide_f64,
    rt_saturate_f64_to_s32 = rt_saturate_f64_to_s32,
    rt_equal_f64 = rt_equal_f64,
    rt_less_than_f64 = rt_less_than_f64,
    rt_greater_than_f64 = rt_greater_than_f64,
    rt_multiply_f64 = rt_multiply_f64,
    rt_convert_u32_to_f64 = rt_convert_u32_to_f64,
    rt_shift_right_s32 = rt_shift_right_s32,
    rt_narrow_i64 = rt_narrow_i64,
    convert_f64_to_u64 = convert_f64_to_u64,
    negate_i64 = negate_i64,
    rt_saturate_f64_to_s64 = rt_saturate_f64_to_s64,
    rt_less_than_equal_s32 = rt_less_than_equal_s32,
    rt_greater_than_s32 = rt_greater_than_s32,
    rt_rotate_left_i32 = rt_rotate_left_i32,
    rt_rotate_right_i32 = rt_rotate_right_i32,
    rt_greater_than_equal_s32 = rt_greater_than_equal_s32,
    rt_less_than_equal_f64 = rt_less_than_equal_f64,
    rt_store_f32 = rt_store_f32,
    rt_narrow_f64 = rt_narrow_f64,
    rt_add_f64 = rt_add_f64,
    rt_subtract_f64 = rt_subtract_f64,
    rt_not_equal_f64 = rt_not_equal_f64,
    rt_load_i64 = rt_load_i64,
    rt_less_than_u64 = rt_less_than_u64,
    raw_shift_left_i64 = raw_shift_left_i64,
    rt_shift_left_i64 = rt_shift_left_i64,
    rt_load_f32 = rt_load_f32,
    rt_widen_f32 = rt_widen_f32,
    rt_divide_s32 = rt_divide_s32,
    rt_memory_copy = rt_memory_copy,
    rt_negate_f64 = rt_negate_f64,
    rt_negate_f32 = rt_negate_f32,
    from_bits_f32 = from_bits_f32,
    into_bits_f32 = into_bits_f32,
    rt_add_f32 = rt_add_f32,
    rt_subtract_f32 = rt_subtract_f32,
    rt_multiply_f32 = rt_multiply_f32,
    rt_equal_f32 = rt_equal_f32,
    rt_not_equal_f32 = rt_not_equal_f32,
    rt_divide_f32 = rt_divide_f32,
    rt_round_down_f32 = rt_round_down_f32,
    rt_load_i32_from_s8 = rt_load_i32_from_s8,
    rt_greater_than_equal_f64 = rt_greater_than_equal_f64,
    rt_remainder_u32 = rt_remainder_u32,
    rt_equal_i64 = rt_equal_i64,
    rt_saturate_f64_to_u32 = rt_saturate_f64_to_u32,
    rt_extend_s8_to_i32 = rt_extend_s8_to_i32,
    rt_widen_i32 = rt_widen_i32,
    rt_add_i64 = rt_add_i64,
    rt_not_equal_i64 = rt_not_equal_i64,
    raw_shift_right_u64 = raw_shift_right_u64,
    rt_shift_right_u64 = rt_shift_right_u64,
    rt_and_i64 = rt_and_i64,
    rt_or_i64 = rt_or_i64,
    rt_subtract_i64 = rt_subtract_i64,
    from_bits_i64_to_i16 = from_bits_i64_to_i16,
    multiply_fast_i64 = multiply_fast_i64,
    rt_multiply_i64 = rt_multiply_i64,
    rt_extend_s32_to_i64 = rt_extend_s32_to_i64,
    rt_greater_than_u64 = rt_greater_than_u64,
    rt_less_than_equal_u64 = rt_less_than_equal_u64,
    rt_convert_s32_to_f64 = rt_convert_s32_to_f64,
    rt_divide_u32 = rt_divide_u32,
    rt_extend_s16_to_i32 = rt_extend_s16_to_i32,
    flip_most_significant = flip_most_significant,
    rt_less_than_s64 = rt_less_than_s64,
    rt_transmute_f64_to_i64 = rt_transmute_f64_to_i64,
    rt_rotate_left_i64 = rt_rotate_left_i64,
    rt_count_ones_i32 = rt_count_ones_i32,
    rt_store_i64_into_i32 = rt_store_i64_into_i32,
    rt_convert_u32_to_f32 = rt_convert_u32_to_f32,
    rt_greater_than_f32 = rt_greater_than_f32,
    rt_saturate_f32_to_u32 = rt_saturate_f32_to_u32,
    rt_round_up_f32 = rt_round_up_f32,
    rt_load_i64_from_u32 = rt_load_i64_from_u32,
    rt_convert_u64_to_f64 = rt_convert_u64_to_f64,
    rt_saturate_f64_to_u64 = rt_saturate_f64_to_u64,
    rt_greater_than_equal_u64 = rt_greater_than_equal_u64,
    rt_store_i64_into_i8 = rt_store_i64_into_i8,
    rt_load_i64_from_s32 = rt_load_i64_from_s32,
    rt_greater_than_equal_s64 = rt_greater_than_equal_s64,
    rt_greater_than_s64 = rt_greater_than_s64,
    rt_less_than_equal_s64 = rt_less_than_equal_s64,
    rt_transmute_i64_to_f64 = rt_transmute_i64_to_f64,
    rt_memory_size = rt_memory_size,
    rt_exclusive_or_i64 = rt_exclusive_or_i64,
    raw_leading_zeroes_i64 = raw_leading_zeroes_i64,
    rt_leading_zeroes_i64 = rt_leading_zeroes_i64,
    rt_transmute_f32_to_i32 = rt_transmute_f32_to_i32,
    is_positive = is_positive,
    rt_copy_sign_f64 = rt_copy_sign_f64,
    rt_convert_s32_to_f32 = rt_convert_s32_to_f32,
    rt_remainder_s32 = rt_remainder_s32,
    is_all_zeroes = is_all_zeroes,
    rt_truncate_f64_to_u64 = rt_truncate_f64_to_u64,
    rt_divide_u64 = rt_divide_u64,
    rt_load_i64_from_s16 = rt_load_i64_from_s16,
    rt_load_i64_from_u16 = rt_load_i64_from_u16,
    rt_load_i64_from_s8 = rt_load_i64_from_s8,
    rt_load_i64_from_u8 = rt_load_i64_from_u8,
    rt_maximum_f64 = rt_maximum_f64,
    rt_table_set = rt_table_set,
    rt_table_copy = rt_table_copy,
    rt_table_drop = rt_table_drop,
    rt_memory_drop = rt_memory_drop,
}