import std/math
import std/parseutils
import std/strformat

import ./vector


func ColorToHex*(color: Vec3f): string =
  &"{int(color.r * 255):02X}{int(color.g * 255):02X}{int(color.b * 255):02X}"

func ColorToHex*(color: Vec4f): string =
  &"{int(color.r * 255):02X}{int(color.g * 255):02X}{int(color.b * 255):02X}{int(color.a * 255):02X}"

func AsPixel*(color: Vec3f): array[4, uint8] =
  [uint8(color.r * 255), uint8(color.g * 255), uint8(color.b * 255), 255'u8]
func AsPixel*(color: Vec4f): array[4, uint8] =
  [uint8(color.r * 255), uint8(color.g * 255), uint8(color.b * 255), uint8(color.a * 255)]

func ToRGBA*(value: string): Vec4f =
  assert value != ""
  var hex = value
  if hex[0] == '#':
    hex = hex[1 .. ^1]
  # when 3 or 6 -> set alpha to 1.0
  assert hex.len == 3 or hex.len == 6 or hex.len == 4 or hex.len == 8
  if hex.len == 3:
    hex = hex & "f"
  if hex.len == 4:
    hex = hex[0] & hex[0] & hex[1] & hex[1] & hex[2] & hex[2] & hex[3] & hex[3]
  if hex.len == 6:
    hex = hex & "ff"
  assert hex.len == 8
  var r, g, b, a: uint8
  discard parseHex(hex[0 .. 1], r)
  discard parseHex(hex[2 .. 3], g)
  discard parseHex(hex[4 .. 5], b)
  discard parseHex(hex[6 .. 7], a)
  return Vec4f([float32(r), float32(g), float32(b), float32(a)]) / 255'f


func Linear2srgb*(value: SomeFloat): SomeFloat =
  clamp(
    if (value < 0.0031308): value * 12.92
    else: pow(value, 1.0 / 2.4) * 1.055 - 0.055,
    0,
    1,
  )
func Srgb2linear*(value: SomeFloat): SomeFloat =
  clamp(
    if (value < 0.04045): value / 12.92
    else: pow((value + 0.055) / 1.055, 2.4),
    0,
    1,
  )
func Linear2srgb*(value: uint8): uint8 = # also covers GrayPixel
  uint8(round(Linear2srgb(float(value) / 255.0) * 255))
func Srgb2linear*(value: uint8): uint8 = # also covers GrayPixel
  uint8(round(Srgb2linear(float(value) / 255.0) * 255))

func ToSRGB*(value: Vec4f): Vec4f =
  NewVec4f(
    Linear2srgb(value.r),
    Linear2srgb(value.g),
    Linear2srgb(value.b),
    value.a,
  )
func FromSRGB*(value: Vec4f): Vec4f =
  NewVec4f(
    Srgb2linear(value.r),
    Srgb2linear(value.g),
    Srgb2linear(value.b),
    value.a,
  )

const
  Black* = ToRGBA "#000000FF"
  Silver* = ToRGBA "#C0C0C0FF"
  Gray* = ToRGBA "#808080FF"
  White* = ToRGBA "#FFFFFFFF"
  Maroon* = ToRGBA "#800000FF"
  Red* = ToRGBA "#FF0000FF"
  Purple* = ToRGBA "#800080FF"
  Fuchsia* = ToRGBA "#FF00FFFF"
  Green* = ToRGBA "#008000FF"
  Lime* = ToRGBA "#00FF00FF"
  Olive* = ToRGBA "#808000FF"
  Yellow* = ToRGBA "#FFFF00FF"
  Navy* = ToRGBA "#000080FF"
  Blue* = ToRGBA "#0000FFFF"
  Teal* = ToRGBA "#008080FF"
  Aqua* = ToRGBA "#00FFFFFF"
