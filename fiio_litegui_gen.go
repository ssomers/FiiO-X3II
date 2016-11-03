package main

import (
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"image/png"
	"math"
	"os"
)

type disc struct {
	center         image.Point
	radius         float64
	angleA, angleB float64
}

func sqr(f float64) float64 { return f * f }

func (*disc) ColorModel() color.Model {
	return color.AlphaModel
}

func (d *disc) Bounds() image.Rectangle {
	rr := int(math.Ceil(d.radius))
	return image.Rect(
		d.center.X-rr,
		d.center.Y-rr,
		d.center.X+rr,
		d.center.Y+rr)
}

func (d *disc) At(x, y int) color.Color {
	xx := float64(x - d.center.X)
	yy := float64(y - d.center.Y)
	if sqr(xx)+sqr(yy) > sqr(d.radius) {
		return color.Transparent
	}
	if d.angleA == d.angleB {
		return color.Opaque
	}
	a := math.Atan2(-yy, xx)
	if d.angleA < d.angleB && d.angleA <= a && a <= d.angleB {
		return color.Opaque
	}
	if d.angleA > d.angleB && (d.angleA <= a || a <= d.angleB) {
		return color.Opaque
	}
	return color.Transparent
}

type generator func(i int, rect image.Rectangle, cent image.Point, img draw.Image)

func generate(width int, height int, fname string, first int, last int, jpg *jpeg.Options, gen generator) {
	rect := image.Rect(0, 0, width, height)
	cent := image.Pt(width/2, height/2)
	// bg := color.Black
	// pal := color.Palette([]color.Color{bg, fg})
	// img := image.NewPaletted(rect, pal)
	for i := first; i <= last; i++ {
		out, err := os.Create(fmt.Sprintf(fname, i))
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		img := image.NewRGBA(rect)

		gen(i, rect, cent, img)

		if jpg != nil {
			err = jpeg.Encode(out, img, jpg)
		} else {
			err = png.Encode(out, img)
		}
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	}
}

func main() {
	generate(320, 240, "litegui\\boot_animation\\boot%d.jpg", 0, 45, &jpeg.Options{Quality: 10}, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		for c := 0; c < i+1; c++ {
			f1 := float64(i+1-c) / 46.0
			f2 := math.Max(0, float64(46-2*c)) / 46.0
			radius := 333 * f1
			fg := color.RGBA{
				uint8(math.Ceil(f2*0x90)) + 0x09,
				uint8(math.Ceil(f2*0xF0)) + 0x0F,
				0,
				0xFF}
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &disc{cent, radius, 0, 0}, image.ZP, draw.Over)
		}
	})

	generate(320, 240, "litegui\\boot_animation\\shutdown%d.jpg", 0, 17, &jpeg.Options{Quality: 10}, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		f := float64(18-i) / 18.0
		radius := 120 * f
		fg := color.RGBA{
			uint8(math.Ceil(f*0x90)) + 0x09,
			uint8(math.Ceil(f*0xF0)) + 0x0F,
			0,
			0xFF}
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &disc{cent, radius, 0, 0}, image.ZP, draw.Src)
	})

	generate(32, 32, "litegui\\theme1\\music_update\\%02d.png", 0, 11, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		f := math.Sin(float64(i+1) / 12.5 * math.Pi)
		radius := 16 * f
		fg := color.RGBA{
			0x99,
			0xFF,
			0,
			0xFF}
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &disc{cent, radius, 0, 0}, image.ZP, draw.Src)
	})

	colors := []color.Color{
		color.RGBA{0x66, 0x99, 0, 0xFF},
		color.RGBA{0x99, 0xFF, 0, 0xFF},
		color.RGBA{0x00, 0x00, 0x99, 0xFF},
		color.RGBA{0x33, 0x33, 0x33, 0xFF},
		color.RGBA{0x99, 0xFF, 0, 0xFF},
		color.RGBA{0x66, 0x99, 0, 0xFF},
	}
	generate(128, 128, "litegui\\theme1\\theme\\theme_%d.png", 1, 6, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		outerradius := 64.0
		innerradius := 56.0
		cutoffradius := 16.0
		var ai, bi float64
		for j := 1; j <= 6; j++ {
			a := float64((9-j)%8-4) / 4.0 * math.Pi
			b := float64((9-j)%8-3) / 4.0 * math.Pi
			if j == i {
				ai, bi = b, a
			}
			var fg = colors[j-1]
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &disc{cent, outerradius, a, b}, image.ZP, draw.Over)
		}
		draw.DrawMask(img, rect, &image.Uniform{color.RGBA{0, 0, 0, 0xFF}}, image.ZP, &disc{cent, innerradius, ai, bi}, image.ZP, draw.Over)
		draw.DrawMask(img, rect, &image.Uniform{color.RGBA{0x99, 0x99, 0x99, 0xFF}}, image.ZP, &disc{cent, cutoffradius, 0, 0}, image.ZP, draw.Over)
	})
}
