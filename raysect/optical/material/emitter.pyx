# cython: language_level=3

# Copyright (c) 2014, Dr Alex Meakins, Raysect Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     1. Redistributions of source code must retain the above copyright notice,
#        this list of conditions and the following disclaimer.
#
#     2. Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#
#     3. Neither the name of the Raysect Project nor the names of its
#        contributors may be used to endorse or promote products derived from
#        this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

cimport cython
from numpy cimport ndarray
from libc.math cimport round

from raysect.optical.material.material cimport NullVolume
from raysect.core.math.affinematrix cimport AffineMatrix3D
from raysect.core.scenegraph.primitive cimport Primitive
from raysect.core.scenegraph.world cimport World
from raysect.optical.ray cimport Ray
from raysect.core.math.vector cimport Vector3D
from raysect.core.math.point cimport Point3D
from raysect.optical.spectrum cimport Spectrum
from raysect.optical.spectralfunction cimport SpectralFunction
from raysect.core.math.normal cimport Normal3D
from raysect.core.math.point cimport new_point3d
from raysect.optical.spectrum cimport new_spectrum
from raysect.optical.colour import d65_white


cdef class UniformSurfaceEmitter(NullVolume):

    cdef SpectralFunction emission_spectrum
    cdef double scale

    def __init__(self, SpectralFunction emission_spectrum, double scale = 1.0):
        """
        Uniform and isotropic surface emitter

        emission is spectral radiance: W/m2/str/nm"""

        super().__init__()
        self.emission_spectrum = emission_spectrum
        self.scale = scale
        self.continuous = False
        self.importance = 1.0

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef Spectrum sample_surface(self, World world, Ray ray, Primitive primitive, Point3D hit_point,
                                bint exiting, Point3D inside_point, Point3D outside_point,
                                Normal3D normal, AffineMatrix3D to_local, AffineMatrix3D to_world):

        cdef:
            Spectrum spectrum
            ndarray emission
            double[::1] s_view, e_view
            int index

        spectrum = ray.new_spectrum()
        emission = self.emission_spectrum.sample_multiple(spectrum.min_wavelength, spectrum.max_wavelength, spectrum.num_samples)

        # obtain memoryviews
        s_view = spectrum.samples
        e_view = emission

        for index in range(spectrum.num_samples):
            s_view[index] += e_view[index] * self.scale

        return spectrum
