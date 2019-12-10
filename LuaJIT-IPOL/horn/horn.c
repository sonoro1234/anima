#include <stdbool.h>
__declspec(dllexport) void horn_schunck_pyramidal(
	const float *I1,              // source image
	const float *I2,              // target image
	float       *u,               // x component of optical flow
	float       *v,               // y component of optical flow
	const int    nx,              // image width
	const int    ny,              // image height
	const float  alpha,           // smoothing weight
	const int    nscales,         // number of scales
	const float  zfactor,         // zoom factor
	const int    warps,           // number of warpings per scale
	const float  TOL,             // stopping criterion threshold
	const int    maxiter,         // maximum number of iterations
	const bool   verbose          // switch on messages
);
#ifndef DISABLE_OMP
#include <omp.h>
#endif//DISABLE_OMP
#include "horn_schunck_pyramidal.c"