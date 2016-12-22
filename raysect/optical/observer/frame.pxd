# cython: language_level=3

# Copyright (c) 2016, Dr Alex Meakins, Raysect Project
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

from numpy cimport ndarray


cdef class Pixel:

    cdef:
        readonly int channels
        readonly ndarray mean
        readonly ndarray variance
        readonly ndarray samples
        double[::1] _mean_mv
        double[::1] _variance_mv
        int[::1] _samples_mv

    cpdef object add_sample(self, int channel, double sample)

    cpdef object combine_samples(self, int channel, double mean, double variance, int sample_count)

    cpdef double error(self, int channel)

    cpdef ndarray errors(self)

    cpdef object clear(self)

    cpdef Pixel copy(self)

    cdef inline void _new_buffers(self)

    cdef inline object _bounds_check(self, int channel)


cdef class Frame1D:

    cdef:
        readonly int pixels
        readonly int channels
        readonly ndarray mean
        readonly ndarray variance
        readonly ndarray samples
        double[:,::1] _mean_mv
        double[:,::1] _variance_mv
        int[:,::1] _samples_mv

    cpdef object add_sample(self, int i, int channel, double sample)

    cpdef object combine_samples(self, int i, int channel, double mean, double variance, int sample_count)

    cpdef double error(self, int i, int channel)

    cpdef ndarray errors(self)

    cpdef object clear(self)

    cpdef Frame1D copy(self)

    cdef inline void _new_buffers(self)

    cdef inline object _bounds_check(self, int i, int channel)


cdef class Frame2D:

    cdef:
        readonly tuple pixels
        readonly int channels
        readonly ndarray mean
        readonly ndarray variance
        readonly ndarray samples
        double[:,:,::1] _mean_mv
        double[:,:,::1] _variance_mv
        int[:,:,::1] _samples_mv

    cpdef object add_sample(self, int x, int y, int channel, double sample)

    cpdef object combine_samples(self, int x, int y, int channel, double mean, double variance, int sample_count)

    cpdef double error(self, int x, int y, int channel)

    cpdef ndarray errors(self)

    cpdef object clear(self)

    cpdef Frame2D copy(self)

    cdef inline void _new_buffers(self)

    cdef inline object _bounds_check(self, int x, int y, int channel)
