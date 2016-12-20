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

import matplotlib.pyplot as plt
import numpy as np
from time import time

from raysect.optical.colour import resample_ciexyz, spectrum_to_ciexyz, ciexyz_to_srgb
from raysect.optical.observer.frame import Frame2D, Pixel
from raysect.optical.observer.observer2d import Pipeline2D, PixelProcessor


class RGBPipeline2D(Pipeline2D):

    def __init__(self, sensitivity=1.0, display_progress=True, display_update_time=5, accumulate=False):
        self.sensitivity = sensitivity
        self.display_progress = display_progress
        self._display_timer = 0
        self.display_update_time = display_update_time
        self.accumulate = accumulate

        self.xyz_frame = None
        self.rgb_frame = None

        self._working_mean = None
        self._working_variance = None

        self._resampled_xyz = None
        self._normalisation = None

        self._samples = 0

    def initialise(self, pixels, pixel_samples, spectral_slices):

        # create intermediate and final frame-buffers
        if not self.accumulate or self.xyz_frame is None or self.xyz_frame.pixels != pixels:
            self.xyz_frame = Frame2D(pixels, channels=3)
            self.rgb_frame = np.zeros((pixels[0], pixels[1], 3))

        self._working_mean = np.zeros((pixels[0], pixels[1], 3))
        self._working_variance = np.zeros((pixels[0], pixels[1], 3))

        # generate pixel processor configurations for each spectral slice
        self._resampled_xyz = [resample_ciexyz(slice.min_wavelength, slice.max_wavelength, slice.num_samples) for slice in spectral_slices]

        self._samples = pixel_samples

        self._start_display()

    def pixel_processor(self, slice_id):
        return XYZPixelProcessor(self._resampled_xyz[slice_id])

    def update(self, pixel_id, packed_result, slice_id):

        # obtain result
        x, y = pixel_id
        mean, variance = packed_result

        # accumulate sub-samples
        self._working_mean[x, y, 0] += mean[0]
        self._working_mean[x, y, 1] += mean[1]
        self._working_mean[x, y, 2] += mean[2]

        self._working_variance[x, y, 0] += variance[0]
        self._working_variance[x, y, 1] += variance[1]
        self._working_variance[x, y, 2] += variance[2]

        # update users
        self._update_display()

    def finalise(self):

        # update final frame with working frame results
        for x in range(self.xyz_frame.pixels[0]):
            for y in range(self.xyz_frame.pixels[1]):
                self.xyz_frame.combine_samples(x, y, 0, self._working_mean[x, y, 0], self._working_variance[x, y, 0], self._samples)
                self.xyz_frame.combine_samples(x, y, 1, self._working_mean[x, y, 1], self._working_variance[x, y, 1], self._samples)
                self.xyz_frame.combine_samples(x, y, 2, self._working_mean[x, y, 2], self._working_variance[x, y, 2], self._samples)

        self._generate_srgb_frame()

        if self.display_progress:
            self.display()

    def _generate_srgb_frame(self):

        # TODO - re-add exposure handlers

        # Apply sensitivity to each pixel and convert to sRGB colour-space
        nx, ny, _ = self.rgb_frame.shape
        for ix in range(nx):
            for iy in range(ny):

                rgb = ciexyz_to_srgb(
                    self.xyz_frame.mean[ix, iy, 0] * self.sensitivity,
                    self.xyz_frame.mean[ix, iy, 1] * self.sensitivity,
                    self.xyz_frame.mean[ix, iy, 2] * self.sensitivity
                )

                self.rgb_frame[ix, iy, 0] = rgb[0]
                self.rgb_frame[ix, iy, 1] = rgb[1]
                self.rgb_frame[ix, iy, 2] = rgb[2]

    def _start_display(self):
        """
        Display live render.
        """

        self._display_timer = 0
        if self.display_progress:
            self.display()
            self._display_timer = time()

    def _update_display(self):
        """
        Update live render.
        """

        # update live render display
        if self.display_progress and (time() - self._display_timer) > self.display_update_time:

            print("RGBPipeline2D updating display...")
            self._generate_srgb_frame()
            self.display()
            self._display_timer = time()

    def display(self):

        if self.rgb_frame is None:
            raise RuntimeError("No frame data to display.")

        plt.figure(1)
        plt.clf()
        plt.imshow(np.transpose(self.rgb_frame, (1, 0, 2)), aspect="equal", origin="upper", interpolation='nearest')
        plt.tight_layout()

        # plot standard error
        plt.figure(2)
        plt.clf()
        plt.imshow(np.transpose(self.xyz_frame.error.mean(axis=2)), aspect="equal", origin="upper", interpolation='nearest')
        plt.colorbar()
        plt.tight_layout()

        plt.draw()
        plt.show()

        # workaround for interactivity for QT backend
        plt.pause(0.1)

    def save(self, filename):
        """
        Save the collected samples in the camera frame to file.
        :param str filename: Filename and path for camera frame output file.
        """
        if self.rgb_frame is None:
            raise RuntimeError("No frame data to save.")

        plt.imsave(filename, np.transpose(self.rgb_frame, (1, 0, 2)))


class XYZPixelProcessor(PixelProcessor):

    def __init__(self, resampled_xyz):
        self._resampled_xyz = resampled_xyz
        self._xyz = Pixel(channels=3)

    def add_sample(self, spectrum):
        # convert spectrum to CIE XYZ and add sample to pixel buffer
        x, y, z = spectrum_to_ciexyz(spectrum, self._resampled_xyz)
        self._xyz.add_sample(0, x)
        self._xyz.add_sample(1, y)
        self._xyz.add_sample(2, z)

    def pack_results(self):

        mean = (self._xyz.mean[0], self._xyz.mean[1], self._xyz.mean[2])
        variance = (self._xyz.variance[0], self._xyz.variance[1], self._xyz.variance[2])
        return mean, variance
