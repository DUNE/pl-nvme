#include <stdio.h>

void outputBinary(FILE* file, unsigned int v){
	int	b;
	
	for(b = 31; b >= 0; b--){
		if(v & (1 << b))
			fprintf(file, "1");
		else
			fprintf(file, "0");
	}
	fprintf(file, "\n");
}

int output(FILE* file, unsigned int r, unsigned int i){
	static int		state = 0;
	static unsigned int	data[3];
	
//	printf("Output: %x, %x\n", r, i);
	switch(state){
	case 0:
		data[0] = (r << 8) | (i >> 16);
		data[1] = (i << 16);
		state++;
		break;
	case 1:
		data[1] |= (r >> 8);
		data[2] = (r << 24) | i;

#ifdef ZAP
		printf("%8.8x\n", data[0]);
		printf("%8.8x\n", data[1]);
		printf("%8.8x\n", data[2]);
#endif
		fprintf(file, "%d\n", data[0]);
		fprintf(file, "%d\n", data[1]);
		fprintf(file, "%d\n", data[2]);

//		outputBinary(file, data[0]);
//		outputBinary(file, data[1]);
//		outputBinary(file, data[2]);
		state = 0;
		break;
	}
	return 0;
}

void test1(FILE* file){
	int		c;
	unsigned int	r;
	unsigned int	i;
	
	for(c = 0; c < 4096; c++){
		r = c;
		i = 0x10000 | c;
		output(file, r, i);
	}
}

void test2(FILE* file){
	int		s;
	int		sample = 0;;
	int		subband;
	int		numSamples = 8;
	unsigned int	r;
	unsigned int	i;
	int		n;
	
	for(n = 0; n < 8; n++){
		for(subband = 0; subband < 4; subband++){
			for(s = 0; s < numSamples; s++){
//				r = (0xF << 20) | (subband << 16) | s;
//				i = (0xE << 20) | (subband << 16) | s;
				r = (0x3 << 22) | (subband << 20) | ((sample + s) << 6);
				i = (0x2 << 22) | (subband << 20) | ((sample + s) << 6);
				output(file, r, i);
			}
		}
		sample += numSamples;
	}
}

int main(){
	FILE*		file;
	
	file = fopen("data.txt", "w");
	
//	test1(file);
	test2(file);
	
	fclose(file);
	
	return 0;
}
