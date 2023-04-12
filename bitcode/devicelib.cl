/*
 * Copyright (c) 2021-22 CHIP-SPV developers
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * This is counterpart to hipcl_mathlib.hh
 * ATM it can't be used right after compilation because of a problem with mangling.
 *
 * HIP with default AS set to 4 mangles functions with pointer args to:
 *   float @_Z13opencl_sincosfPf(float, float addrspace(4)*)
 * while OpenCL code compiled for SPIR mangles to either
 *   float @_Z6sincosfPU3AS4f(float, float addrspace(4)*)
 * or
 *   float @_Z6sincosfPf(float, float *)
*/

#include "ROCm-Device-Libs/ocml/inc/ocml.h"
#define NON_OVLD
#define OVLD __attribute__((overloadable))
//#define AI __attribute__((always_inline))
#define EXPORT NON_OVLD

#define DEFAULT_AS __generic

#define CHIP_MANGLE(N) __chip_##N
#define CHIP_MANGLE2(N, S) __chip_##N##_##S

#define CHIP_MANGLE_ATOMIC(NAME, S) CHIP_MANGLE2(atomic_##NAME, S)

#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#pragma OPENCL EXTENSION cl_khr_fp16 : enable
#pragma OPENCL EXTENSION cl_khr_global_int32_base_atomics : enable
#pragma OPENCL EXTENSION cl_khr_global_int32_extended_atomics : enable
#pragma OPENCL EXTENSION cl_khr_local_int32_base_atomics : enable
#pragma OPENCL EXTENSION cl_khr_local_int32_extended_atomics : enable
#pragma OPENCL EXTENSION cl_khr_int64_base_atomics : enable
#pragma OPENCL EXTENSION cl_khr_int64_extended_atomics : enable

EXPORT unsigned int __chip_funnelshift_l(unsigned int lo, unsigned int hi,
                                         unsigned int shift) {
  unsigned long long concat = ((unsigned long long)hi << 32) | lo;
  unsigned int shifted = concat << (shift & 31);
  return shifted >> 32;
}

EXPORT unsigned int __chip_funnelshift_lc(unsigned int lo, unsigned int hi,
                                          unsigned int shift) {
  unsigned long long concat = ((unsigned long long)hi << 32) | lo;
  unsigned int shifted = concat << (shift & 31);
  unsigned int clamped_shift = shift < 32 ? shift : 32;
  return shifted >> (32 - clamped_shift);
}

EXPORT unsigned int __chip_funnelshift_r(unsigned int lo, unsigned int hi,
                                         unsigned int shift) {
  unsigned long long concat = ((unsigned long long)hi << 32) | lo;
  unsigned int shifted = concat >> (shift & 31);
  return shifted;
}

EXPORT unsigned int __chip_funnelshift_rc(unsigned int lo, unsigned int hi,
                                          unsigned int shift) {
  unsigned long long concat = ((unsigned long long)hi << 32) | lo;
  unsigned int shifted = concat >> (shift & 31);
  unsigned int clamped_shift = shift < 32 ? shift : 32;
  return shifted << (32 - clamped_shift);
}

EXPORT float CHIP_MANGLE2(saturate, f32)(float x) {
  return (x < 0.0f) ? 0.0f : ((x > 1.0f) ? 1.0f : x);
}

EXPORT float CHIP_MANGLE2(jn, f32)(int n, float x) {
  // TODO check if OCML available
  if (n == 0)
    return __ocml_j0_f32(x);
  if (n == 1)
    return __ocml_j1_f32(x);

  float x0 = __ocml_j0_f32(x);
  float x1 = __ocml_j1_f32(x);
  for (int i = 1; i < n; ++i) {
    float x2 = (2 * i) / x * x1 - x0;
    x0 = x1;
    x1 = x2;
  }

  return x1;
}

EXPORT double CHIP_MANGLE2(jn, f64)(int n, double x) {
  if (n == 0)
    return __ocml_j0_f64(x);
  if (n == 1)
    return __ocml_j1_f64(x);

  double x0 = __ocml_j0_f64(x);
  double x1 = __ocml_j1_f64(x);
  for (int i = 1; i < n; ++i) {
    double x2 = (2 * i) / x * x1 - x0;
    x0 = x1;
    x1 = x2;
  }

  return x1;
}

EXPORT float CHIP_MANGLE2(yn, f32)(int n, float x) {
  if (n == 0)
    return __ocml_y0_f32(x);
  if (n == 1)
    return __ocml_y1_f32(x);

  float x0 = __ocml_y0_f32(x);
  float x1 = __ocml_y1_f32(x);
  for (int i = 1; i < n; ++i) {
    float x2 = (2 * i) / x * x1 - x0;
    x0 = x1;
    x1 = x2;
  }

  return x1;
}

// TODO get rid of CHIP_MANGLE
EXPORT double CHIP_MANGLE2(yn, f64)(int n, double x) {
  if (n == 0)
    return __ocml_y0_f64(x);
  if (n == 1)
    return __ocml_y1_f64(x);

  double x0 = __ocml_y0_f64(x);
  double x1 = __ocml_y1_f64(x);
  for (int i = 1; i < n; ++i) {
    double x2 = (2 * i) / x * x1 - x0;
    x0 = x1;
    x1 = x2;
  }

  return x1;
}


EXPORT long long int CHIP_MANGLE2(llrint, f32)(float x) {
  return (long long int)(rint(x));
}
EXPORT long long int CHIP_MANGLE2(llrint, f64)(double x) {
  return (long long int)(rint(x));
}

EXPORT long long int CHIP_MANGLE2(llround, f32)(float x) {
  return (long long int)(round(x));
}
EXPORT long long int CHIP_MANGLE2(llround, f64)(double x) {
  return (long long int)(round(x));
}

EXPORT long int CHIP_MANGLE2(lrint, f32)(float x) {
  return (long int)(rint(x));
}
EXPORT long int CHIP_MANGLE2(lrint, f64)(double x) {
  return (long int)(rint(x));
}

EXPORT long int CHIP_MANGLE2(lround, f32)(float x) {
  return (long int)(round(x));
}
EXPORT long int CHIP_MANGLE2(lround, f64)(double x) {
  return (long int)(round(x));
}


OVLD float length(float4 f);
OVLD double length(double4 f);
EXPORT float  CHIP_MANGLE2(norm4d, f32)(float x, float y, float z, float w) { float4 temp = (float4)(x, y, z, w); return length(temp); }
EXPORT double CHIP_MANGLE2(norm4d, f64)(double x, double y, double z, double w) { double4 temp = (double4)(x, y, z, w); return length(temp); }
EXPORT float  CHIP_MANGLE2(norm3d, f32)(float x, float y, float z) { float4 temp = (float4)(x, y, z, 0.0f); return length(temp); }
EXPORT double CHIP_MANGLE2(norm3d, f64)(double x, double y, double z) { double4 temp = (double4)(x, y, z, 0.0); return length(temp); }

EXPORT float CHIP_MANGLE2(norm, f32)(int dim, const float *a) {
  float r = 0;
  while (dim--) {
    r += a[0] * a[0];
    ++a;
  }

  return sqrt(r);
  }

  EXPORT double CHIP_MANGLE2(norm, f64)(int dim, const double *a) {
  float r = 0;
  while (dim--) {
    r += a[0] * a[0];
    ++a;
  }

  return sqrt(r);
  }

  EXPORT float CHIP_MANGLE2(rnorm, f32)(int dim, const float *a) { 
  float r = 0;
  while (dim--) {
    r += a[0] * a[0];
    ++a;
  }

  return sqrt(r);
}

  EXPORT float CHIP_MANGLE2(rnorm, f64)(int dim, const double *a) { 
  double r = 0;
  while (dim--) {
    r += a[0] * a[0];
    ++a;
  }

  return sqrt(r);
}

EXPORT void CHIP_MANGLE2(sincospi, f32)(float x, float *sptr,
                                              float *cptr) {
  *sptr = sinpi(x);
  *cptr = cospi(x);
}

EXPORT float CHIP_MANGLE2(frexp, f32)(float x, DEFAULT_AS int *i) {
  int tmp;
  float ret = frexp(x, &tmp);
  *i = tmp;
  return ret;
}
EXPORT double CHIP_MANGLE2(frexp, f64)(double x, DEFAULT_AS int *i) {
  int tmp;
  double ret = frexp(x, &tmp);
  *i = tmp;
  return ret;
}

EXPORT float CHIP_MANGLE2(ldexp, f32)(float x, int k) { return ldexp(x, k); }
EXPORT double CHIP_MANGLE2(ldexp, f64)(double x, int k) { return ldexp(x, k); }

EXPORT float CHIP_MANGLE2(modf, f32)(float x, DEFAULT_AS float *i) {
  float tmp;
  float ret = modf(x, &tmp);
  *i = tmp;
  return ret;
}
EXPORT double CHIP_MANGLE2(modf, f64)(double x, DEFAULT_AS double *i) {
  double tmp;
  double ret = modf(x, &tmp);
  *i = tmp;
  return ret;
}


// remquo
EXPORT float CHIP_MANGLE2(remquo, f32)(float x, float y, DEFAULT_AS int *quo) {
  int tmp;
  float rem = remquo(x, y, &tmp);
  *quo = tmp;
  return rem;
}
EXPORT double CHIP_MANGLE2(remquo, f64)(double x, double y, DEFAULT_AS int *quo) {
  int tmp;
  double rem = remquo(x, y, &tmp);
  *quo = tmp;
  return rem;
}

// sincos
EXPORT float CHIP_MANGLE2(sincos, f32)(float x, DEFAULT_AS float *cos) {
  float tmp;
  float sin = sincos(x, &tmp);
  *cos = tmp;
  return sin;
}

EXPORT double CHIP_MANGLE2(sincos, f64)(double x, DEFAULT_AS double *cos) {
  double tmp;
  double sin = sincos(x, &tmp);
  *cos = tmp;
  return sin;
}

#ifdef CHIP_NONPORTABLE_MATH_INTRISINCS

// DEF_OPENCL1F_NATIVE(recip)
// DEF_OPENCL2F_NATIVE(divide)

#else

EXPORT float __fdividef(float x, float y) { return x / y; }

#endif


/* other */

EXPORT void CHIP_MANGLE(local_barrier)() { barrier(CLK_LOCAL_MEM_FENCE); }

EXPORT void CHIP_MANGLE(local_fence)() { mem_fence(CLK_LOCAL_MEM_FENCE); }

EXPORT void CHIP_MANGLE(global_fence)() { mem_fence(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE); }

EXPORT void CHIP_MANGLE(system_fence)() { mem_fence(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE); }
/* memory routines */

// sets size bytes of the memory pointed to by ptr to value
// interpret ptr as a unsigned char so that it writes as bytes
EXPORT void* CHIP_MANGLE(memset)(DEFAULT_AS void* ptr, int value, size_t size) {
  volatile unsigned char* temporary = ptr;

  for(int i=0;i<size;i++)
    temporary[i] = value;
  
    return ptr;
}

EXPORT void* CHIP_MANGLE(memcpy)(DEFAULT_AS void *dest, DEFAULT_AS const void * src, size_t n) {
  volatile unsigned char* temporary_dest = dest;
  volatile const unsigned char* temporary_src = src;

  for(int i=0;i<n;i++)
    temporary_dest[i] = temporary_src[i];

  return dest;
}

/**********************************************************************/

EXPORT uint CHIP_MANGLE2(popcount, ui)(uint var) {
  return popcount(var);
}

EXPORT ulong CHIP_MANGLE2(popcount, ul)(ulong var) {
  return popcount(var);
}


EXPORT int CHIP_MANGLE2(clz, i)(int var) {
  return clz(var);
}

EXPORT long CHIP_MANGLE2(clz, li)(long var) {
  return clz(var);
}

EXPORT int CHIP_MANGLE2(ctz, i)(int var) {
  return ctz(var);
}

EXPORT long CHIP_MANGLE2(ctz, li)(long var) {
  return ctz(var);
}


EXPORT int CHIP_MANGLE2(hadd, i)(int x, int y) {
  return hadd(x, y);
}

EXPORT int CHIP_MANGLE2(rhadd, i)(int x, int y) {
  return hadd(x, y);
}

EXPORT uint CHIP_MANGLE2(uhadd, ui)(uint x, uint y) {
  return hadd(x, y);
}

EXPORT uint CHIP_MANGLE2(urhadd, ui)(uint x, uint y) {
  return hadd(x, y);
}


EXPORT int CHIP_MANGLE2(mul24, i)(int x, int y) {
  return mul24(x, y);
}

EXPORT int CHIP_MANGLE2(mulhi, i)(int x, int y) {
  return mul_hi(x, y);
}

EXPORT long CHIP_MANGLE2(mul64hi, li)(long x, long y) {
  return mul_hi(x, y);
}


EXPORT uint CHIP_MANGLE2(umul24, ui)(uint x, uint y) {
  return mul24(x, y);
}

EXPORT uint CHIP_MANGLE2(umulhi, ui)(uint x, uint y) {
  return mul_hi(x, y);
}

EXPORT ulong CHIP_MANGLE2(umul64hi, uli)(ulong x, ulong y) {
  return mul_hi(x, y);
}




/**********************************************************************/

#define DEF_OPENCL_ATOMIC2(NAME)                                               \
  int CHIP_MANGLE_ATOMIC(NAME, i)(DEFAULT_AS int *address, int i) {          \
    volatile global int *gi = to_global(address);                              \
    if (gi)                                                                    \
      return atomic_##NAME(gi, i);                                             \
    else {                                                                     \
      volatile local int *li = to_local(address);                              \
      if (li)                                                                  \
        return atomic_##NAME(li, i);                                           \
      else                                                                     \
        return 0;                                                              \
    }                                                                          \
  };                                                                           \
  uint CHIP_MANGLE_ATOMIC(NAME, u)(                                          \
      DEFAULT_AS uint *address, uint ui) {                                     \
    volatile global uint *gi = to_global(address);                             \
    if (gi)                                                                    \
      return atomic_##NAME(gi, ui);                                            \
    else {                                                                     \
      volatile local uint *li = to_local(address);                             \
      if (li)                                                                  \
        return atomic_##NAME(li, ui);                                          \
      else                                                                     \
        return 0;                                                              \
    }                                                                          \
  };                                                                           \
  ulong CHIP_MANGLE_ATOMIC(NAME, l)(                                         \
      DEFAULT_AS ulong *address,                                               \
      ulong ull) {                                                             \
    volatile global ulong *gi =                                                \
        to_global((DEFAULT_AS ulong *)address);                                \
    if (gi)                                                                    \
      return atom_##NAME(gi, ull);                                             \
    else {                                                                     \
      volatile local ulong *li =                                               \
          to_local((DEFAULT_AS ulong *)address);                               \
      if (li)                                                                  \
        return atom_##NAME(li, ull);                                           \
      else                                                                     \
        return 0;                                                              \
    }                                                                          \
  };

DEF_OPENCL_ATOMIC2(add)
DEF_OPENCL_ATOMIC2(sub)
DEF_OPENCL_ATOMIC2(xchg)
DEF_OPENCL_ATOMIC2(min)
DEF_OPENCL_ATOMIC2(max)
DEF_OPENCL_ATOMIC2(and)
DEF_OPENCL_ATOMIC2(or)
DEF_OPENCL_ATOMIC2(xor)

#define DEF_OPENCL_ATOMIC1(NAME)                                               \
  int CHIP_MANGLE_ATOMIC(NAME, i)(DEFAULT_AS int *address) {                 \
    volatile global int *gi = to_global(address);                              \
    if (gi)                                                                    \
      return atomic_##NAME(gi);                                                \
    volatile local int *li = to_local(address);                                \
    if (li)                                                                    \
      return atomic_##NAME(li);                                                \
    return 0;                                                                  \
  };                                                                           \
  uint CHIP_MANGLE_ATOMIC(NAME, u)(                                          \
      DEFAULT_AS uint *address) {                                              \
    volatile global uint *gi = to_global(address);                             \
    if (gi)                                                                    \
      return atomic_##NAME(gi);                                                \
    volatile local uint *li = to_local(address);                               \
    if (li)                                                                    \
      return atomic_##NAME(li);                                                \
    return 0;                                                                  \
  };                                                                           \
  ulong CHIP_MANGLE_ATOMIC(NAME, l)(                                         \
      DEFAULT_AS ulong *address) {                                             \
    volatile global ulong *gi =                                                \
        to_global((DEFAULT_AS ulong *)address);                                \
    if (gi)                                                                    \
      return atom_##NAME(gi);                                                  \
    volatile local ulong *li = to_local((DEFAULT_AS ulong *)address);          \
    if (li)                                                                    \
      return atom_##NAME(li);                                                  \
    return 0;                                                                  \
  };

DEF_OPENCL_ATOMIC1(inc)
DEF_OPENCL_ATOMIC1(dec)

#define DEF_OPENCL_ATOMIC3(NAME)                                               \
  int CHIP_MANGLE_ATOMIC(NAME, i)(                                           \
      DEFAULT_AS int *address, int cmp, int val) {                             \
    volatile global int *gi = to_global(address);                              \
    if (gi)                                                                    \
      return atomic_##NAME(gi, cmp, val);                                      \
    volatile local int *li = to_local(address);                                \
    if (li)                                                                    \
      return atomic_##NAME(li, cmp, val);                                      \
    return 0;                                                                  \
  };                                                                           \
  uint CHIP_MANGLE_ATOMIC(NAME, u)(                                          \
      DEFAULT_AS uint *address, uint cmp,                                      \
      uint val) {                                                              \
    volatile global uint *gi = to_global(address);                             \
    if (gi)                                                                    \
      return atomic_##NAME(gi, cmp, val);                                      \
    volatile local uint *li = to_local(address);                               \
    if (li)                                                                    \
      return atomic_##NAME(li, cmp, val);                                      \
    return 0;                                                                  \
  };                                                                           \
  ulong CHIP_MANGLE_ATOMIC(NAME, l)(                                         \
      DEFAULT_AS ulong *address, ulong cmp,                                    \
      ulong val) {                                                             \
    volatile global ulong *gi =                                                \
        to_global((DEFAULT_AS ulong *)address);                                \
    if (gi)                                                                    \
      return atom_##NAME(gi, cmp, val);                                        \
    volatile local ulong *li = to_local((DEFAULT_AS ulong *)address);          \
    if (li)                                                                    \
      return atom_##NAME(li, cmp, val);                                        \
    return 0;                                                                  \
  };

DEF_OPENCL_ATOMIC3(cmpxchg)

/* This code adapted from AMD's HIP sources */

static OVLD float atomic_add_f(volatile local float *address, float val) {
  volatile local uint *uaddr = (volatile local uint *)address;
  uint old = *uaddr;
  uint r;

  do {
    r = old;
    old = atomic_cmpxchg(uaddr, r, as_uint(val + as_float(r)));
  } while (r != old);

  return as_float(r);
}

static OVLD double atom_add_d(volatile local double *address, double val) {
  volatile local ulong *uaddr = (volatile local ulong *)address;
  ulong old = *uaddr;
  ulong r;

  do {
    r = old;
    old = atom_cmpxchg(uaddr, r, as_ulong(val + as_double(r)));
  } while (r != old);

  return as_double(r);
}

static OVLD float atomic_exch_f(volatile local float *address, float val) {
  return as_float(atomic_xchg((volatile local uint *)(address), as_uint(val)));
}

static OVLD float atomic_add_f(volatile global float *address, float val) {
  volatile global uint *uaddr = (volatile global uint *)address;
  uint old = *uaddr;
  uint r;

  do {
    r = old;
    old = atomic_cmpxchg(uaddr, r, as_uint(val + as_float(r)));
  } while (r != old);

  return as_float(r);
}

static OVLD double atom_add_d(volatile global double *address, double val) {
  volatile global ulong *uaddr = (volatile global ulong *)address;
  ulong old = *uaddr;
  ulong r;

  do {
    r = old;
    old = atom_cmpxchg(uaddr, r, as_ulong(val + as_double(r)));
  } while (r != old);

  return as_double(r);
}

static OVLD float atomic_exch_f(volatile global float *address, float val) {
  return as_float(atomic_xchg((volatile global uint *)(address), as_uint(val)));
}

static OVLD uint atomic_inc2_u(volatile local uint *address, uint val) {
  uint old = *address;
  uint r;
  do {
    r = old;
    old = atom_cmpxchg(address, r, ((r >= val) ? 0 : (r+1)));
  } while (r != old);

  return r;
}

static OVLD uint atomic_dec2_u(volatile local uint *address, uint val) {
  uint old = *address;
  uint r;
  do {
    r = old;
    old = atom_cmpxchg(address, r, (((r == 0) || (r > val)) ? val : (r-1)));
  } while (r != old);

  return r;
}

static OVLD uint atomic_inc2_u(volatile global uint *address, uint val) {
  uint old = *address;
  uint r;
  do {
    r = old;
    old = atom_cmpxchg(address, r, ((r >= val) ? 0 : (r+1)));
  } while (r != old);

  return r;
}

static OVLD uint atomic_dec2_u(volatile global uint *address, uint val) {
  uint old = *address;
  uint r;
  do {
    r = old;
    old = atom_cmpxchg(address, r, (((r == 0) || (r > val)) ? val : (r-1)));
  } while (r != old);

  return r;
}

EXPORT float CHIP_MANGLE_ATOMIC(add, f32)(DEFAULT_AS float *address,
                                 float val) {
  volatile global float *gi = to_global(address);
  if (gi)
    return atomic_add_f(gi, val);
  volatile local float *li = to_local(address);
  if (li)
    return atomic_add_f(li, val);
  return 0;
}

EXPORT double CHIP_MANGLE_ATOMIC(add, f64)(DEFAULT_AS double *address,
                                  double val) {
  volatile global double *gi = to_global((DEFAULT_AS double *)address);
  if (gi)
    return atom_add_d(gi, val);
  volatile local double *li = to_local((DEFAULT_AS double *)address);
  if (li)
    return atom_add_d(li, val);
  return 0;
}

EXPORT float CHIP_MANGLE_ATOMIC(exch, f32)(DEFAULT_AS float *address,
                                 float val) {
  volatile global float *gi = to_global(address);
  if (gi)
    return atomic_exch_f(gi, val);
  volatile local float *li = to_local(address);
  if (li)
    return atomic_exch_f(li, val);
  return 0;
}

EXPORT uint CHIP_MANGLE_ATOMIC(inc2, u)(DEFAULT_AS uint *address,
                                 uint val) {
  volatile global uint *gi = to_global((DEFAULT_AS uint *)address);
  if (gi)
    return atomic_inc2_u(gi, val);
  volatile local uint *li = to_local((DEFAULT_AS uint *)address);
  if (li)
    return atomic_inc2_u(li, val);
  return 0;
}

EXPORT uint CHIP_MANGLE_ATOMIC(dec2, u)(DEFAULT_AS uint *address,
                                 uint val) {
  volatile global uint *gi = to_global((DEFAULT_AS uint *)address);
  if (gi)
    return atomic_dec2_u(gi, val);
  volatile local uint *li = to_local((DEFAULT_AS uint *)address);
  if (li)
    return atomic_dec2_u(li, val);
  return 0;
}
/**********************************************************************/

// Use the Intel versions for now by default, since the Intel OpenCL CPU
// driver still implements only them, not the KHR versions.
#define sub_group_shuffle intel_sub_group_shuffle
#define sub_group_shuffle_xor intel_sub_group_shuffle_xor

int OVLD sub_group_shuffle(int var, uint srcLane);
float OVLD sub_group_shuffle(float var, uint srcLane);
int OVLD sub_group_shuffle_xor(int var, uint value);
float OVLD sub_group_shuffle_xor(float var, uint value);

// Compute the full warp lane id given a subwarp of size wSize and
// a "logical" lane id within it.
//
// Assumes that each subwarp behaves as a separate entity
// with a starting logical lane ID of 0.
__attribute__((always_inline))
static int warpLaneId(int subWarpLaneId, int wSize) {
  if (wSize == DEFAULT_WARP_SIZE)
    return subWarpLaneId;
  unsigned laneId = get_sub_group_local_id();
  unsigned logicalSubWarp = laneId / wSize;
  return logicalSubWarp * wSize + subWarpLaneId;
}

#define __SHFL(T)                                                              \
  EXPORT OVLD T __shfl(T var, int srcLane, int wSize) {                        \
    int laneId = get_sub_group_local_id();                                     \
    return sub_group_shuffle(var, warpLaneId(srcLane, wSize));                 \
  }

__SHFL(int);
__SHFL(uint);
__SHFL(long);
__SHFL(ulong);
__SHFL(float);
__SHFL(double);

#define __SHFL_XOR(T)                                                          \
  EXPORT OVLD T __shfl_xor(T var, int value, int warpSizeOverride) {           \
    return sub_group_shuffle_xor(var, value);                                  \
  }

__SHFL_XOR(int);
__SHFL_XOR(uint);
__SHFL_XOR(long);
__SHFL_XOR(ulong);
__SHFL_XOR(float);
__SHFL_XOR(double);

#define __SHFL_UP(T)							\
  EXPORT OVLD T __shfl_up(T var, uint delta, int wSize) {		\
    int laneId = get_sub_group_local_id();				\
    int logicalSubWarp = laneId / wSize;				\
    int logicalSubWarpLaneId = laneId % wSize;				\
    int subWarpSrcId = logicalSubWarpLaneId - delta;			\
    if (subWarpSrcId < 0)						\
      subWarpSrcId = logicalSubWarpLaneId;				\
    return sub_group_shuffle(var, logicalSubWarp * wSize + subWarpSrcId); \
}

__SHFL_UP(int);
__SHFL_UP(uint);
__SHFL_UP(long);
__SHFL_UP(ulong);
__SHFL_UP(float);
__SHFL_UP(double);

#define __SHFL_DOWN(T)							\
EXPORT OVLD T __shfl_down(T var, uint delta, int wSize) {		\
  int laneId = get_sub_group_local_id();				\
  int logicalSubWarp = laneId / wSize;					\
  int logicalSubWarpLaneId = laneId % wSize;				\
  int subWarpSrcId = logicalSubWarpLaneId + delta;			\
  if (subWarpSrcId >= wSize)						\
    subWarpSrcId = logicalSubWarpLaneId;				\
  return sub_group_shuffle(var, logicalSubWarp * wSize + subWarpSrcId); \
}

__SHFL_DOWN(int);
__SHFL_DOWN(uint);
__SHFL_DOWN(long);
__SHFL_DOWN(ulong);
__SHFL_DOWN(float);
__SHFL_DOWN(double);

__attribute__((overloadable)) uint4 sub_group_ballot(int predicate);
EXPORT OVLD ulong __ballot(int predicate) {
#if DEFAULT_WARP_SIZE <= 32
  return sub_group_ballot(predicate).x;
#else
  return sub_group_ballot(predicate).x |
    (sub_group_ballot(predicate).y << 32);
#endif
}

EXPORT OVLD int __all(int predicate) {
  return __ballot(predicate) == ~0;
}

EXPORT OVLD int __any(int predicate) {
  return __ballot(predicate) != 0;
}

EXPORT OVLD unsigned __lane_id() {
  return get_sub_group_local_id();
}

EXPORT OVLD void __syncwarp() {
  // CUDA docs speaks only about "memory". It's not specifying that it would
  // only flush local memory.
  return sub_group_barrier(CLK_GLOBAL_MEM_FENCE);
}

typedef struct {
  intptr_t  image;
  intptr_t  sampler;
} *hipTextureObject_t;

EXPORT float CHIP_MANGLE2(tex2D, f32)(hipTextureObject_t textureObject,
				float x, float y) {
  return read_imagef(
    __builtin_astype(textureObject->image, read_only image2d_t),
    __builtin_astype(textureObject->sampler, sampler_t),
    (float2)(x, y)).x;
}

// In HIP long long is 64-bit integer. In OpenCL it's 128-bit integer.
EXPORT long __double_as_longlong(double x) { return as_long(x); }
EXPORT double __longlong_as_double(long int x) { return as_double(x); }

// See c_to_opencl.def for details.
#define DEF_UNARY_FN_MAP(NAME_, TYPE_)                                         \
  TYPE_ MAP_PREFIX##NAME_(TYPE_ x) { return NAME_(x); }
#define DEF_BINARY_FN_MAP(NAME_, TYPE_)                                        \
  TYPE_ MAP_PREFIX##NAME_(TYPE_ x, TYPE_ y) { return NAME_(x, y); }
#include "c_to_opencl.def"
#undef UNARY_FN
#undef BINARY_FN
