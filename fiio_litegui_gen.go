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
	"path/filepath"
)

type slice struct {
	center                   image.Point
	innerradius, outerradius float64
	angleA, angleB           float64 // start & end angle of slice in radians
}

func (*slice) ColorModel() color.Model {
	return color.AlphaModel
}

func (d *slice) Bounds() image.Rectangle {
	if d.innerradius > d.outerradius {
		fmt.Println(d.innerradius, " > ", d.outerradius)
		os.Exit(1)
	}
	rr := int(math.Ceil(d.outerradius))
	return image.Rect(
		d.center.X-rr,
		d.center.Y-rr,
		d.center.X+rr,
		d.center.Y+rr)
}

func sqr(f float64) float64 { return f * f }

func (d *slice) At(x, y int) color.Color {
	xx := float64(x - d.center.X)
	yy := float64(y - d.center.Y)
	if rr := sqr(xx) + sqr(yy); rr < sqr(d.innerradius) || rr > sqr(d.outerradius) {
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

func generate(width int, height int, fnamePattern string, first int, last int, jpg *jpeg.Options, gen generator) {
	rect := image.Rect(0, 0, width, height)
	cent := image.Pt(width/2, height/2)
	// bg := color.Black
	// pal := color.Palette([]color.Color{bg, fg})
	// img := image.NewPaletted(rect, pal)
	err := os.MkdirAll(filepath.Dir(fnamePattern), os.ModeDir)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	for i := first; i <= last; i++ {
		fname := fnamePattern
		if first < last {
			fname = fmt.Sprintf(fnamePattern, i)
		}
		out, err := os.Create(fname)
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
	generate(320, 240, filepath.Join("changes_generated", "litegui", "boot_animation", "boot%d.jpg"), 0, 45, &jpeg.Options{Quality: 10}, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		for c := 0; c < i+1; c++ {
			f1 := float64(i+1-c) / 46.0
			f2 := math.Max(0, float64(46-2*c)) / 46.0
			var s slice
			s.center = cent
			s.outerradius = 333 * f1
			fg := color.RGBA{
				uint8(math.Ceil(f2*0x90)) + 0x09,
				uint8(math.Ceil(f2*0xF0)) + 0x0F,
				0,
				0xFF}
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		}
	})

	generate(320, 240, filepath.Join("changes_generated", "litegui", "boot_animation", "shutdown%d.jpg"), 0, 17, &jpeg.Options{Quality: 10}, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		f := float64(18-i) / 18.0
		fg := color.RGBA{
			uint8(math.Ceil(f*0x90)) + 0x09,
			uint8(math.Ceil(f*0xF0)) + 0x0F,
			0,
			0xFF}
		var s slice
		s.center = cent
		s.outerradius = 120 * f
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Src)
	})

	generate(32, 32, filepath.Join("changes_generated", "litegui", "theme1", "music_update", "%02d.png"), 0, 11, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		f := math.Sin(float64(i+1) / 12.5 * math.Pi)
		fg := color.RGBA{
			0x99,
			0xFF,
			0,
			0xFF}
		var s slice
		s.center = cent
		s.outerradius = 16 * f
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Src)
	})

	colors := []color.Color{
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x00, 0x00, 0x99, 0xFF},
		color.RGBA{0x33, 0x33, 0x33, 0xFF},
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
	}
	generate(128, 128, filepath.Join("changes_generated", "litegui", "theme1", "theme", "theme_%d.png"), 1, 6, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		outerradius := 64.0
		innerradius := 60.0
		iconradius := 48.0
		cutoffradius := 16.0
		var ci float64 // center angle of slice in radians
		for j := 1; j <= 6; j++ {
			a := (float64((9-j)%8) - 4.0) / 4.0 * math.Pi
			c := (float64((9-j)%8) - 3.5) / 4.0 * math.Pi
			b := (float64((9-j)%8) - 3.0) / 4.0 * math.Pi
			if j == i {
				ci = c
			}
			var fg = colors[j-1]
			var s slice
			s.center = cent
			s.outerradius = outerradius
			if j != i {
				s.innerradius = innerradius
			}
			s.angleA = a
			s.angleB = b
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		}
		var s slice
		s.center = cent
		s.outerradius = cutoffradius
		draw.DrawMask(img, rect, &image.Uniform{color.RGBA{0x99, 0x99, 0x99, 0xFF}}, image.ZP, &s, image.ZP, draw.Over)

		iconfilename := filepath.Join("changes_fed", fmt.Sprintf("theme_icon_%d.png", i))
		iconreader, err := os.Open(iconfilename)
		if err != nil {
			panic(fmt.Sprintf("%s", err))
		}
		defer iconreader.Close()
		icon, err := png.Decode(iconreader)
		if err != nil {
			panic(fmt.Sprintf("%s: %s", iconfilename, err))
		}
		var center image.Point
		center.X = -64 - int(math.Cos(ci)*iconradius+0.5) + icon.Bounds().Max.X/2
		center.Y = -64 + int(math.Sin(ci)*iconradius+0.5) + icon.Bounds().Max.Y/2
		draw.Draw(img, rect, icon, center, draw.Over)
	})

	generate(112, 112, filepath.Join("changes_generated", "litegui", "theme1", "adjust", "volume_scale_focus.png"), 0, 0, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		steps := 120
		var s slice
		s.center = cent
		s.outerradius = 56.0
		s.innerradius = 48.0
		for j := 0; j < steps; j++ {
			// clockwise, starting slightly before 12 o'clock
			a := (0.25 - float64(j-0)/float64(steps)) * 2 * math.Pi
			b := (0.25 - float64(j-1)/float64(steps)) * 2 * math.Pi
			if a < -math.Pi {
				a += 2 * math.Pi
			}
			if b < -math.Pi {
				b += 2 * math.Pi
			}
			var fg color.Color
			if j < 100 {
				c := 1 - float64(99-j)*0.007
				fg = color.RGBA{uint8(math.Ceil(c * 0x99)), uint8(math.Ceil(c * 0xFF)), 0x00, 0xFF} // topbar_volume_color
			} else {
				c := 1 - float64(j-100)/20.0
				fg = color.RGBA{0xFF, uint8(math.Ceil(c * 0x82)), uint8(math.Ceil(0x34)), 0xFF} // topbar_volume_warnning_color
			}
			s.angleA = a
			s.angleB = b
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		}
	})

	generate(122, 122, filepath.Join("changes_generated", "litegui", "theme1", "adjust", "maxvol_scale_focus.png"), 0, 0, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		steps := 120
		var s slice
		s.center = cent
		s.outerradius = 56.0
		s.innerradius = 48.0
		for j := 1; j < steps; j++ {
			a := (-0.4 - float64(j+1)/float64(steps)*0.7) * 2 * math.Pi
			b := (-0.4 - float64(j+0)/float64(steps)*0.7) * 2 * math.Pi
			if a < -math.Pi {
				a += 2 * math.Pi
			}
			if b < -math.Pi {
				b += 2 * math.Pi
			}
			var fg color.Color
			c := 1 - float64(steps-j)*0.005
			fg = color.RGBA{uint8(math.Ceil(c * 0x99)), uint8(math.Ceil(c * 0xFF)), 0x00, 0xFF} // topbar_volume_color
			s.angleA = a
			s.angleB = b
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		}
	})
}
