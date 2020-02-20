
// Placeholders:
//   DATA = data to decrypt (4 bytes)
//   MAGIC = magic to bruteforce (4 bytes)
//   IV0 = first 4 bytes of the IV
//   IV1 = second 4 bytes of the IV

constant uchar Data[{DATA_SIZE}] = { {DATA} };
constant uchar Magic[{MAGIC_SIZE}] = { {MAGIC} };

uint rotl(uint bits, uint amount) {
	return (bits << amount) | (bits >> (32 - amount));
}

void salsa20(uint *dancers) {
	
	uint x[16];

	#ifdef opencl_unroll_hint
	__attribute__((opencl_unroll_hint))
	#endif
	for(uint i = 0; i < 16; i++) 
		x[i] = dancers[i];

	#ifdef opencl_unroll_hint
	__attribute__((opencl_unroll_hint))
	#endif
	for(uint i = 0; i < 10; i++) {
		// cols
		x[ 4] ^= rotl(x[ 0]+x[12], 7);  x[ 8] ^= rotl(x[ 4]+x[ 0], 9);
		x[12] ^= rotl(x[ 8]+x[ 4],13);  x[ 0] ^= rotl(x[12]+x[ 8],18);

		x[ 9] ^= rotl(x[ 5]+x[ 1], 7);  x[13] ^= rotl(x[ 9]+x[ 5], 9);
		x[ 1] ^= rotl(x[13]+x[ 9],13);  x[ 5] ^= rotl(x[ 1]+x[13],18);

		x[14] ^= rotl(x[10]+x[ 6], 7);  x[ 2] ^= rotl(x[14]+x[10], 9);
		x[ 6] ^= rotl(x[ 2]+x[14],13);  x[10] ^= rotl(x[ 6]+x[ 2],18);

		x[ 3] ^= rotl(x[15]+x[11], 7);  x[ 7] ^= rotl(x[ 3]+x[15], 9);
		x[11] ^= rotl(x[ 7]+x[ 3],13);  x[15] ^= rotl(x[11]+x[ 7],18);

		// rows
		x[ 1] ^= rotl(x[ 0]+x[ 3], 7);  x[ 2] ^= rotl(x[ 1]+x[ 0], 9);
		x[ 3] ^= rotl(x[ 2]+x[ 1],13);  x[ 0] ^= rotl(x[ 3]+x[ 2],18);

		x[ 6] ^= rotl(x[ 5]+x[ 4], 7);  x[ 7] ^= rotl(x[ 6]+x[ 5], 9);
		x[ 4] ^= rotl(x[ 7]+x[ 6],13);  x[ 5] ^= rotl(x[ 4]+x[ 7],18);

		x[11] ^= rotl(x[10]+x[ 9], 7);  x[ 8] ^= rotl(x[11]+x[10], 9);
		x[ 9] ^= rotl(x[ 8]+x[11],13);  x[10] ^= rotl(x[ 9]+x[ 8],18);

		x[12] ^= rotl(x[15]+x[14], 7);  x[13] ^= rotl(x[12]+x[15], 9);
		x[14] ^= rotl(x[13]+x[12],13);  x[15] ^= rotl(x[14]+x[13],18);
	}

	#ifdef opencl_unroll_hint
	__attribute__((opencl_unroll_hint))
	#endif
	for(uint i = 0; i < 16; i++)
		dancers[i] += x[i];
}

kernel void Bruteforce(ulong x, ulong y, uchar mode, ulong offset)
{
	const size_t index = get_global_id(0) + offset;

	//printf(" Index: %d", get_global_id(1));

	// hard-code most of the state
	uint state[16];
	state[0] = 1634760805;
	state[5] = 824206446;
	state[6] = {IV0};
	state[7] = {IV1};
	state[8] = 0;
	state[9] = 0;
	state[10] = 2036477238;
	state[15] = 1797285236;

	// set the key for this iteration
	x += (index * (mode & 1));
	y += (index * (mode & 2));
	state[1] = state[11] = x & 0xFFFFFFFF;
	state[2] = state[12] = (x >> 32) & 0xFFFFFFFF;
	state[3] = state[13] = y & 0xFFFFFFFF;
	state[4] = state[14] = (y >> 32) & 0xFFFFFFFF;

	//for(uint i = 0; i < 16; i++)
	//	printf("%u\r\n", state[i]);

	salsa20(state);

	//printf("State[0]:    %X\r\n", state[0]);
	//printf("State[0][0]: %u %X\r\n", (state[0] >> 0) & 0xFF, ((state[0] >> 0) & 0xFF) ^ Data[0]);
	//printf("State[0][1]: %u %X\r\n", (state[0] >> 8) & 0xFF, ((state[0] >> 8) & 0xFF) ^ Data[1]);
	//printf("State[0][2]: %u %X\r\n", (state[0] >> 16) & 0xFF, ((state[0] >> 16) & 0xFF) ^ Data[2]);
	//printf("State[0][3]: %u %X\r\n", (state[0] >> 24) & 0xFF, ((state[0] >> 24) & 0xFF) ^ Data[3]);

	//printf("State[1]:    %X\r\n", state[1]);
	//printf("State[1][0]: %u %X\r\n", (state[1] >> 0) & 0xFF, ((state[1] >> 0) & 0xFF) ^ Data[4]);
	//printf("State[1][1]: %u %X\r\n", (state[1] >> 8) & 0xFF, ((state[1] >> 8) & 0xFF) ^ Data[5]);
	//printf("State[1][2]: %u %X\r\n", (state[1] >> 16) & 0xFF, ((state[1] >> 16) & 0xFF) ^ Data[6]);
	//printf("State[1][3]: %u %X\r\n", (state[1] >> 24) & 0xFF, ((state[1] >> 24) & 0xFF) ^ Data[7]);

	//printf("Magic[0]: %X\r\n", Magic[0]);
	//printf("Magic[1]: %X\r\n", Magic[1]);
	//printf("Magic[2]: %X\r\n", Magic[2]);
	//printf("Magic[3]: %X\r\n", Magic[3]);
	//printf("Magic[4]: %X\r\n", Magic[4]);
	//printf("Magic[5]: %X\r\n", Magic[5]);
	//printf("Magic[6]: %X\r\n", Magic[6]);
	//printf("Magic[7]: %X\r\n", Magic[7]);

	// faster than inline ifs
	uchar result =
		((((state[0] >>  0) & 0xFF) ^ Data[0]) == Magic[0]) &
		((((state[0] >>  8) & 0xFF) ^ Data[1]) == Magic[1]) &
		((((state[0] >> 16) & 0xFF) ^ Data[2]) == Magic[2]) &
		((((state[0] >> 24) & 0xFF) ^ Data[3]) == Magic[3]) &
		((((state[1] >>  0) & 0xFF) ^ Data[4]) == Magic[4]) &
		((((state[1] >>  8) & 0xFF) ^ Data[5]) == Magic[5]) &
		((((state[1] >> 16) & 0xFF) ^ Data[6]) == Magic[6]) &
		((((state[1] >> 24) & 0xFF) ^ Data[7]) == Magic[7]);

	// check if the first state equals the magic '# Bu'
	if(result)
	{
		printf(" -- MATCH INDEX: %u KEY: %016llX-%016llX --\r\n", index, x, y);
	}
}
