/*
 Copyright (C) 2015-2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 N-Body compute preferences common structure for the kernel and the utility class.
 */

#ifndef _NBODY_COMPUTE_PREFS_H_
#define _NBODY_COMPUTE_PREFS_H_

#ifdef __cplusplus

namespace NBody{
    namespace Compute{
        struct Prefs{
            float timestep;
            float damping;
            float softeningSqr;
            unsigned int particles;
        };
        
        typedef Prefs Prefs;
    }
}

#endif

#endif
