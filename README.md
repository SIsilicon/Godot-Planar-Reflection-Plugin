# Godot-Planar-Reflection-Plugin

Greetings! This plugin, as the name implies adds planar reflection to the Godot game engine. 3.2 to be more specific. I made this plugin to make it easier for others to have good looking reflections for their 3D games. Watch as objects in the scene are faithfully reflected in the planar reflectors. I hope you find this useful. :)

## What is this?
If you're don't know what Planar Reflection is, then let me explain. Planar Reflection is a technique used in real time graphics engines to render a reflection on a planar surface. "Planar" includes anything that's at least close to flat; like a floor, a mirror or a calm body of water. How it does it is that it renders the scene a second time from a different perspective. This second render is then projected onto the plane that'll have the reflection.

![How_it_works](pictures/How_it_works.png) The advantage of using this over something like Screen Space Reflection is that it does not rely on what's on screen. No matter what angle you look at it, everything will show in the reflection.
![Screen_Space_vs_Planar](pictures/Screen_Space_vs_Planar.png)Of course, because it renders the scene another time, having a lot of these is probably not a good idea; use them wisely and sparingly.

## Installation

Whether you're downloading it from the GitHub repo, or from the Godot asset library, the plugin will be inside the `addons` folder. copy that folder into your project's `addons` folder. If you don't have such a folder, make one.

## Usage

As stated before, the plugin adds a new node called `PlanarReflector`. All you need to do to get reflections set up is

1. Add a `PlanarReflector` to the scene.
2. Add a material. Preferably a `SpatialMaterial`.
3. Adjust the default geometry as needed (set its size; **not its scale**).

At first you won't see a reflection, but that's because the default material has a high roughness parameter.

![Default material](pictures/Default_Material.png)

If you turn the roughness down however,

![Smooth Material](pictures/Smooth_Material.png)

Voila! You've got a reflection. Setting the Metallic all the way up will give you a mirror. Cool huh?

![Metallic Material](pictures/Metallic_Material.png)

The `PlanarReflector` works with most of the `SpatialMaterial` settings. It can even work with normal maps.

![Normal Mapped Material](pictures/Normal_Mapped_Material.png)

It also works with `ShaderMaterials`. Which means you can finally have that beautiful reflection in your pond. :)

![Shader Material](pictures/Shader_Material.png)

What's also great is that the reflections can be previewed directly in the editor, as the pictures above show. Sure the reflection lags behind when you move the camera around, but it's better than nothing. ;)

### Parameters

![Parameters](pictures/Parameters.png)

The `PlanarReflector` has the following parameters available.

* `Environment` - A custom environment for the reflection to be rendered with.
* `Resolution` - The resolution of the reflection. A higher value gives a crispier look, but also reduces performance. You could probably use a low resolution to simulate rough reflections.
* `Fit Mode` - How the reflection is fit onto the plane.
  * `Fit Area` - Fits it onto the entire area. The apparent resolution stays the same.
  * `Fit View` - Fits it into your view. The apparent resolution will change with what part of the plane is visible.
* `Perturb Scale` - How much the plane is distorted by normals.
* `Clip Bias` - How much geometry is rendered beyond the reflection plane. You can increase this in case you start seeing seams caused by normal distortion.
* `Render Sky` - Whether to render the environment into the reflection. This allows you to mix planar reflection with other sources of reflections, such as `ReflectionProbes`.
* `Cull Mask` - What gets rendered into the reflection. This allows you to choose what things can be seen in a reflection.

## Limitations

* The planar reflection will still be visible in unshaded materials, but honestly, why would use an unshaded material to begin with? :/

* The reflection doesn't work properly on double-sided materials. More specifically on the opposite side of the plane.
* Materials stored directly in the reflector's mesh will have no effect.
* Specular highlights, from point lights and such, don't appear in metallic reflections. This can be worked around by disabling `Render Sky`. The highlight will appear where there is no geometry.

## Special Thanks

This project wouldn't have been possible without JFons' [Godot Mirror Example](https://github.com/JFonS/godot-mirror-example). His code is the core of the planar reflector's script. :)

Also the code for camera movement in the demo is by [Maujoe](https://github.com/Maujoe/godot-camera-control).