#include <stdbool.h>

#if defined _WIN32 || defined __CYGWIN__
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT
#endif

EXPORT void Dual_TVL1_optic_flow_multiscale(
		float *I0,           // source image
		float *I1,           // target image
		float *u1,           // x component of the optical flow
		float *u2,           // y component of the optical flow
		const int   nxx,     // image width
		const int   nyy,     // image height
		const float tau,     // time step
		const float lambda,  // weight parameter for the data term
		const float theta,   // weight parameter for (u - v)²
		const int   nscales, // number of scales
		const float zfactor, // factor for building the image piramid
		const int   warps,   // number of warpings per scale
		const float epsilon, // tolerance for numerical convergence
		const bool  verbose  // enable/disable the verbose mode
);
#ifndef DISABLE_OMP
#include <omp.h>
#endif//DISABLE_OMP
#include "tvl1flow_lib.c"