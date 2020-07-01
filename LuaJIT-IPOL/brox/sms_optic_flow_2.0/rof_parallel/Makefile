CC=gcc
CXX=g++
#CFLAGS=-Wall -Wextra -Werror -O4
LFLAGS=iio.o -lpng -ljpeg -ltiff -fopenmp

main: main.cpp brox_optic_flow.h mask.h bicubic_interpolation.h  zoom.h gaussian.h iio.o
	$(CXX) -std=c++98 $(CFLAGS) -o rof_parallel.exe main.cpp  $(LFLAGS)


iio.o: iio.c
	$(CC) -std=c99 $(CFLAGS) -Wno-unused -pedantic -DNDEBUG -D_GNU_SOURCE -c iio.c

clean:
	rm -f iio.o rof_parallel.o rof_parallel.exe
