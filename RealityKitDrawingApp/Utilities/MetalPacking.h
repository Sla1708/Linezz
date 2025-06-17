//
//  MetalPacking.h
//  Linezz
//
//  Created by Sayan on 13.05.2025.
//

#pragma once

#ifndef __METAL_VERSION__

#include <metal/metal.h>
#include <simd/simd.h>

typedef MTLPackedFloat3 packed_float3;
typedef simd_float2 packed_float2;
typedef struct { _Float16 x, y, z; } packed_half3;

#endif // __METAL_VERSION__

