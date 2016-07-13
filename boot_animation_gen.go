package main

import (
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"math"
	"os"
)

type disc struct {
	center image.Point
	radius float64
}

func sqr(f float64) float64 { return f * f }

func (*disc) ColorModel() color.Model {
	return color.AlphaModel
}

func (d *disc) Bounds() image.Rectangle {
	rr := int(math.Ceil(d.radius))
	return image.Rect(d.center.X-rr, d.center.Y-rr, d.center.X+rr, d.center.Y+rr)
}

func (d *disc) At(x, y int) color.Color {
	xx, yy := float64(x-d.center.X)+0.5, float64(y-d.center.Y)+0.5
	if sqr(xx)+sqr(yy) > sqr(d.radius) {
		return color.Transparent
	}
	return color.Opaque
}

type generator func(i int, steps int, rect image.Rectangle, cent image.Point, img draw.Image)

func gen(fname string, steps int, opt jpeg.Options, gen generator) {
	rect := image.Rect(0, 0, 320, 240)
	cent := image.Pt(160, 120)
	// bg := color.Black
	// pal := color.Palette([]color.Color{bg, fg})
	// img := image.NewPaletted(rect, pal)
	for i := 1; i <= steps; i++ {
		out, err := os.Create(fmt.Sprintf("..\\changes_2\\litegui\\boot_animation\\%s%d.jpg", fname, i))
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		img := image.NewRGBA(rect)

		gen(i, steps, rect, cent, img)

		err = jpeg.Encode(out, img, &opt)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	}
}

func main() {
	gen("boot", 46, jpeg.Options{Quality: 10}, func(i int, steps int, rect image.Rectangle, cent image.Point, img draw.Image) {
		for c := 0; c < i; c++ {
			f1 := float64(i-c) / float64(steps)
			f2 := math.Max(0, float64(steps-2*c)) / float64(steps)
			radius := 333 * f1
			fg := color.RGBA{
				uint8(math.Ceil(f2*0x90)) + 0x09,
				uint8(math.Ceil(f2*0xF0)) + 0x0F,
				0,
				0xFF}
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &disc{cent, radius}, image.ZP, draw.Over)
		}
	})

	gen("shutdown", 18, jpeg.Options{Quality: 10}, func(i int, steps int, rect image.Rectangle, cent image.Point, img draw.Image) {
		f := float64(steps-i) / float64(steps)
		radius := 120 * f
		fg := color.RGBA{
			uint8(math.Ceil(f*0x90)) + 0x09,
			uint8(math.Ceil(f*0xF0)) + 0x0F,
			0,
			0xFF}
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &disc{cent, radius}, image.ZP, draw.Src)
	})
}
