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
from raysect.core.math.cython cimport integrate, interpolate
from numpy cimport PyArray_SimpleNew, PyArray_FILLWBYTE, NPY_FLOAT64, npy_intp, import_array

# Plank's constant * speed of light in a vacuum
DEF CONSTANT_HC = 1.9864456832693028e-25

# required by numpy c-api
import_array()


cdef class Spectrum(SpectralFunction):
    """
    A class for working with spectra.

    Describes the distribution of light at each wavelength in units of radiance (W/m^2/str/nm).
    Spectral samples are regularly spaced over the wavelength range and lie in the centre of
    the wavelength bins.

    :param float min_wavelength: Lower wavelength bound for this spectrum
    :param float max_wavelength: Upper wavelength bound for this spectrum
    :param int bins: Number of samples to use over the spectral range

    .. code-block:: pycon

        >>> from raysect.optical import Spectrum
        >>>
        >>> spectrum = Spectrum(400, 720, 250)
    """

    def __init__(self, double min_wavelength, double max_wavelength, int bins):

        self._wavelength_check(min_wavelength, max_wavelength)

        if bins < 1:
            raise ValueError("Number of bins cannot be less than 1.")

        self._construct(min_wavelength, max_wavelength, bins)

    cdef void _wavelength_check(self, double min_wavelength, double max_wavelength):

        if min_wavelength <= 0.0 or max_wavelength <= 0.0:
            raise ValueError("Wavelength cannot be less than or equal to zero.")

        if min_wavelength >= max_wavelength:
            raise ValueError("Minimum wavelength cannot be greater or equal to the maximum wavelength.")

    cdef void _attribute_check(self):

        # users can modify the sample array, need to prevent segfaults in cython code
        if self.samples is None:
            raise ValueError("Cannot generate sample as the sample array is None.")

        if self.samples.shape[0] != self.bins:
            raise ValueError("Sample array length is inconsistent with the number of bins.")

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void _construct(self, double min_wavelength, double max_wavelength, int bins):

        cdef:
            npy_intp size, index
            double[::1] wavelengths_view

        self.min_wavelength = min_wavelength
        self.max_wavelength = max_wavelength
        self.bins = bins
        self.delta_wavelength = (max_wavelength - min_wavelength) / bins

        # create spectral sample bins, initialise with zero
        size = bins
        self.samples = PyArray_SimpleNew(1, &size, NPY_FLOAT64)
        PyArray_FILLWBYTE(self.samples, 0)

        # obtain memory view
        self.samples_mv = self.samples

        # wavelengths is populated on demand
        self._wavelengths = None

    @property
    def wavelengths(self):
        """
        Wavelength array in nm

        :rtype: ndarray
        """

        self._populate_wavelengths()
        return self._wavelengths

    def __len__(self):
        """
        The number of spectral bins

        :rtype: int
        """

        return self.bins

    def __getstate__(self):
        """Encodes state for pickling."""

        return (
            self.min_wavelength,
            self.max_wavelength,
            self.bins,
            self.delta_wavelength,
            self.samples,
        )

    def __setstate__(self, state):
        """Decodes state for pickling."""

        (self.min_wavelength,
         self.max_wavelength,
         self.bins,
         self.delta_wavelength,
         self.samples) = state

        self._wavelengths = None

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void _populate_wavelengths(self):

        cdef:
            npy_intp size
            int index
            double[::1] w_view

        if self._wavelengths is None:

            # create and populate central wavelength array
            size = self.bins
            self._wavelengths = PyArray_SimpleNew(1, &size, NPY_FLOAT64)
            w_view = self._wavelengths
            for index in range(self.bins):
                w_view[index] = self.min_wavelength + (0.5 + index) * self.delta_wavelength

    cpdef bint is_compatible(self, double min_wavelength, double max_wavelength, int bins):
        """
        Returns True if the stored samples are consistent with the specified
        wavelength range and sample size.

        :param float min_wavelength: The minimum wavelength in nanometers
        :param float max_wavelength: The maximum wavelength in nanometers
        :param int bins: The number of bins.
        :return: True if the samples are compatible with the range/samples, False otherwise.
        :rtype: boolean
        """

        return self.min_wavelength == min_wavelength and \
               self.max_wavelength == max_wavelength and \
               self.bins == bins

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cpdef double average(self, double min_wavelength, double max_wavelength):
        """
        Finds the average number of spectral samples over the specified wavelength range.

        :param float min_wavelength: The minimum wavelength in nanometers
        :param float max_wavelength: The maximum wavelength in nanometers
        :return: Average radiance in W/m^2/str/nm
        :rtype: float

        .. code-block:: pycon

            >>> spectrum = ray.trace(world)
            >>> spectrum.average(400, 700)
            1.095030870970234
        """

        self._wavelength_check(min_wavelength, max_wavelength)
        self._attribute_check()

        # require wavelength information for this calculation
        self._populate_wavelengths()

        # average value obtained by integrating linearly interpolated data and normalising
        return integrate(self._wavelengths, self.samples, min_wavelength, max_wavelength) / (max_wavelength - min_wavelength)

    cpdef double integrate(self, double min_wavelength, double max_wavelength):
        """
        Calculates the integrated radiance over the specified spectral range.

        :param float min_wavelength: The minimum wavelength in nanometers
        :param float max_wavelength: The maximum wavelength in nanometers
        :return: Integrated radiance in W/m^2/str
        :rtype: float

        .. code-block:: pycon

            >>> spectrum = ray.trace(world)
            >>> spectrum.integrate(400, 700)
            328.50926129107023
        """

        self._wavelength_check(min_wavelength, max_wavelength)
        self._attribute_check()

        # this calculation requires the wavelength array
        self._populate_wavelengths()

        return integrate(self._wavelengths, self.samples, min_wavelength, max_wavelength)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cpdef ndarray sample(self, double min_wavelength, double max_wavelength, int bins):
        """
        Re-sample this spectrum over a new spectral range.

        :param float min_wavelength: The minimum wavelength in nanometers
        :param float max_wavelength: The maximum wavelength in nanometers
        :param int bins: The number of spectral bins.
        :rtype: ndarray

        .. code-block:: pycon

            >>> spectrum
            <raysect.optical.spectrum.Spectrum at 0x7f56c22bd8b8>
            >>> spectrum.min_wavelength, spectrum.max_wavelength
            (375.0, 785.0)
            >>> sub_spectrum = spectrum.sample(450, 550, 100)
        """

        cdef:
            ndarray samples
            double[::1] s_view
            npy_intp size, index
            double lower_wavelength, upper_wavelength, centre_wavelength, delta_wavelength, reciprocal

        self._wavelength_check(min_wavelength, max_wavelength)
        self._attribute_check()

        # create new sample object and obtain a memoryview for fast access
        size = bins
        samples = PyArray_SimpleNew(1, &size, NPY_FLOAT64)
        PyArray_FILLWBYTE(samples, 0)
        s_view = samples

        # require wavelength information for this calculation
        self._populate_wavelengths()

        delta_wavelength = (max_wavelength - min_wavelength) / bins

        # re-sample by averaging data across each bin
        lower_wavelength = min_wavelength
        reciprocal = 1.0 / delta_wavelength
        for index in range(bins):

            # average value obtained by integrating linearly interpolated data and normalising
            upper_wavelength = min_wavelength + (index + 1) * delta_wavelength
            s_view[index] = reciprocal * integrate(self._wavelengths, self.samples, lower_wavelength, upper_wavelength)
            lower_wavelength = upper_wavelength

        return samples

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef bint is_zero(self):
        """
        Can be used to determine if all the samples are zero.

        True if the spectrum is zero, False otherwise.

        :rtype: bool

        .. code-block:: pycon

            >>> spectrum = ray.trace(world)
            >>> spectrum.is_zero()
            False
        """

        cdef int index
        self._attribute_check()
        for index in range(self.bins):
            if self.samples_mv[index] != 0.0:
                return False
        return True

    cpdef double total(self):
        """
        Calculates the total radiance integrated over the whole spectral range.

        Returns radiance in W/m^2/str

        :rtype: float

        .. code-block:: pycon

            >>> spectrum = ray.trace(world)
            >>> spectrum.total()
            416.6978223103715
        """

        self._attribute_check()

        # this calculation requires the wavelength array
        self._populate_wavelengths()
        return integrate(self._wavelengths, self.samples, self.min_wavelength, self.max_wavelength)

    @cython.cdivision(True)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cpdef ndarray to_photons(self):
        """
        Converts the spectrum sample array from radiance W/m^2/str/nm to Photons/s/m^2/str/nm
        and returns the data in a numpy array.

        :rtype: ndarray

        .. code-block:: pycon

            >>> spectrum = ray.trace(world)
            >>> spectrum.to_photons()
            array([2.30744985e+17, 3.12842916e+17, ...])
        """

        cdef:
            npy_intp size
            int index
            ndarray photons
            double[::1] photons_view

        self._attribute_check()

        # this calculation requires the wavelength array
        self._populate_wavelengths()

        # create array to hold photon samples
        size = self.bins
        photons = PyArray_SimpleNew(1, &size, NPY_FLOAT64)
        photons_view = photons

        # convert each sample to photons
        for index in range(self.bins):
            photons_view[index] = self.samples_mv[index] / photon_energy(self._wavelengths[index])
        return photons

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void clear(self):
        """
        Resets the sample values in the spectrum to zero.
        """

        cdef npy_intp index
        for index in range(self.bins):
            self.samples_mv[index] = 0

    cpdef Spectrum new_spectrum(self):
        """
        Returns a new Spectrum compatible with the same spectral settings.

        :rtype: Spectrum
        """

        return new_spectrum(self.min_wavelength, self.max_wavelength, self.bins)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cpdef Spectrum copy(self):
        """
        Returns a copy of the spectrum.

        :rtype: Spectrum
        """

        cdef:
            Spectrum spectrum
            npy_intp index

        spectrum = self.new_spectrum()
        for index in range(self.samples_mv.shape[0]):
            spectrum.samples_mv[index] = self.samples_mv[index]
        return spectrum

    # low level scalar maths functions
    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef void add_scalar(self, double value) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] += value

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef void sub_scalar(self, double value) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] -= value

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef void mul_scalar(self, double value) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] *= value

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    cdef void div_scalar(self, double value) nogil:

        cdef:
            double reciprocal
            npy_intp index

        reciprocal = 1.0 / value
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] *= reciprocal

    # low level array maths functions
    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef void add_array(self, double[::1] array) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] += array[index]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef void sub_array(self, double[::1] array) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] -= array[index]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef void mul_array(self, double[::1] array) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] *= array[index]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    cdef void div_array(self, double[::1] array) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] /= array[index]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    cdef void mad_scalar(self, double scalar, double[::1] array) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] += scalar * array[index]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    @cython.initializedcheck(False)
    cdef void mad_array(self, double[::1] a, double[::1] b) nogil:

        cdef npy_intp index
        for index in range(self.samples_mv.shape[0]):
            self.samples_mv[index] += a[index] * b[index]


cdef Spectrum new_spectrum(double min_wavelength, double max_wavelength, int bins):

    cdef Spectrum v

    v = Spectrum.__new__(Spectrum)
    v._construct(min_wavelength, max_wavelength, bins)

    return v


@cython.cdivision(True)
cpdef double photon_energy(double wavelength) except -1:
    """
    Returns the energy of a photon with the specified wavelength.

    :param float wavelength: Photon wavelength in nanometers.
    :return: Photon energy in Joules.
    :rtype: float
    """

    if wavelength <= 0.0:
        raise ValueError("Wavelength must be greater than zero.")

    # h * c / lambda
    return CONSTANT_HC / (wavelength * 1e-9)

