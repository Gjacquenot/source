from raysect.optical import World, Node, translate, rotate, Point, d65_white, ConstantSF, InterpolatedSF
from raysect.optical.observer.camera import PinholeCamera
from raysect.optical.material.emitter import UniformSurfaceEmitter
from raysect.optical.material.dielectric import Dielectric
from raysect.primitive import Sphere, Box
from matplotlib.pyplot import *
from numpy import array

world = World()

wavelengths = array([300, 490, 510, 590, 610, 800])
red_attn = array([0.0, 0.0, 0.0, 0.0, 1.0, 1.0]) * 0.98
green_attn = array([0.0, 0.0, 1.0, 1.0, 0.0, 0.0]) * 0.85
blue_attn = array([1.0, 1.0, 0.0, 0.0, 0.0, 0.0]) * 0.98
yellow_attn = array([0.0, 0.0, 1.0, 1.0, 1.0, 1.0]) * 0.85
cyan_attn = array([1.0, 1.0, 1.0, 1.0, 0.0, 0.0]) * 0.85
purple_attn = array([1.0, 1.0, 0.0, 0.0, 1.0, 1.0]) * 0.95

red_glass = Dielectric(index=ConstantSF(1.4), transmission=InterpolatedSF(wavelengths, red_attn))
green_glass = Dielectric(index=ConstantSF(1.4), transmission=InterpolatedSF(wavelengths, green_attn))
blue_glass = Dielectric(index=ConstantSF(1.4), transmission=InterpolatedSF(wavelengths, blue_attn))
yellow_glass = Dielectric(index=ConstantSF(1.4), transmission=InterpolatedSF(wavelengths, yellow_attn))
cyan_glass = Dielectric(index=ConstantSF(1.4), transmission=InterpolatedSF(wavelengths, cyan_attn))
purple_glass = Dielectric(index=ConstantSF(1.4), transmission=InterpolatedSF(wavelengths, purple_attn))

Sphere(1000, world, material=UniformSurfaceEmitter(d65_white, 1.0))

node = Node(parent=world, transform=rotate(0, 0, 90))
Box(Point(-0.5, 0, -2.5), Point(0.5, 0.25, 0.5), node, rotate(0, 0, 0) * translate(0, 1, -0.500001), red_glass)
Box(Point(-0.5, 0, -2.5), Point(0.5, 0.25, 0.5), node, rotate(0, 0, 60) * translate(0, 1, -0.500001), yellow_glass)
Box(Point(-0.5, 0, -2.5), Point(0.5, 0.25, 0.5), node, rotate(0, 0, 120) * translate(0, 1, -0.500001), green_glass)
Box(Point(-0.5, 0, -2.5), Point(0.5, 0.25, 0.5), node, rotate(0, 0, 180) * translate(0, 1, -0.500001), cyan_glass)
Box(Point(-0.5, 0, -2.5), Point(0.5, 0.25, 0.5), node, rotate(0, 0, 240) * translate(0, 1, -0.500001), blue_glass)
Box(Point(-0.5, 0, -2.5), Point(0.5, 0.25, 0.5), node, rotate(0, 0, 300) * translate(0, 1, -0.500001), purple_glass)

camera = PinholeCamera(fov=45, parent=world, transform=translate(0, 0, -6.5) * rotate(0, 0, 0))

ion()
camera.ray_min_depth = 3
camera.ray_max_depth = 500
camera.ray_extinction_prob = 0.01
camera.pixel_samples = 1000
camera.rays = 1
camera.spectral_samples = 21
camera.pixels = (256, 256)
camera.display_progress = True
camera.display_update_time = 10
camera.sub_sample = True
camera.observe()

ioff()
camera.save("raysect_logo.png")
camera.display()
show()

