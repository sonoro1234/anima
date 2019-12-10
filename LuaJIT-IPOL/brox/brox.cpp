#include <stdbool.h>
#include <algorithm>

extern "C"{
__declspec(dllexport) void brox_optic_flow(
    const float *I1,         //first image
    const float *I2,         //second image
    float *u, 		      //x component of the optical flow
    float *v, 		      //y component of the optical flow
    const int    nxx,        //image width
    const int    nyy,        //image height
    const float  alpha,      //smoothness parameter
    const float  gamma,      //gradient term parameter
    const int    nscales,    //number of scales
    const float  nu,         //downsampling factor
    const float  TOL,        //stopping criterion threshold
    const int    inner_iter, //number of inner iterations
    const int    outer_iter, //number of outer iterations
    const bool   verbose     //switch on messages
);
}
#ifndef DISABLE_OMP
#include <omp.h>
#endif//DISABLE_OMP
#include "brox_optic_flow.h"