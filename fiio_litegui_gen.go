package main

import (
	"fmt"
	"github.com/nfnt/resize"
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
	inneralpha, outeralpha   float64
	angleA, angleB           float64 // start & end angle of slice in radians
}

func (*slice) ColorModel() color.Model {
	return color.AlphaModel
}

func (d *slice) Bounds() image.Rectangle {
	if d.innerradius >= d.outerradius {
		panic(fmt.Sprintf("innerradius %f >= outerradius %f", d.innerradius, d.outerradius))
	}
	if d.inneralpha == 0 && d.outeralpha == 0 {
		panic("need inneralpha or outeralpha or both")
	}
	if d.angleA < -math.Pi {
		panic(fmt.Sprintf("angleA %f < -Pi", d.angleA))
	}
	if d.angleB > math.Pi {
		panic(fmt.Sprintf("angleB %f > Pi", d.angleB))
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
	dx := float64(x - d.center.X)
	dy := float64(y - d.center.Y)
	rr := sqr(dx) + sqr(dy)
	minrr := sqr(d.innerradius)
	maxrr := sqr(d.outerradius)
	if rr < minrr || maxrr < rr {
		return color.Transparent
	}
	if d.angleA < d.angleB {
		a := math.Atan2(-dy, dx)
		if a < d.angleA || d.angleB < a {
			return color.Transparent
		}
	}
	if d.angleA > d.angleB {
		a := math.Atan2(-dy, dx)
		if d.angleB < a && a < d.angleA {
			return color.Transparent
		}
	}
	w := math.Sqrt((rr - minrr) / (maxrr - minrr))
	alpha := (1.0-w)*d.inneralpha + w*d.outeralpha
	return color.Alpha16{uint16(math.Ceil(float64(color.Opaque.A) * alpha))}
}

func draw_png(img draw.Image, rect image.Rectangle, fname string, center image.Point, width uint) {
	reader, err := os.Open(fname)
	if err != nil {
		panic(fmt.Sprintf("%s", err))
	}
	defer reader.Close()
	overlay, err := png.Decode(reader)
	if err != nil {
		panic(fmt.Sprintf("%s: %s", fname, err))
	}
	if width > 0 {
		overlay = resize.Resize(width, 0, overlay, resize.MitchellNetravali)
	}
	var pos image.Point
	pos.X = overlay.Bounds().Max.X/2 - center.X
	pos.Y = overlay.Bounds().Max.Y/2 - center.Y
	draw.Draw(img, rect, overlay, pos, draw.Over)
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
		fmt.Println("Writing", fname)
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
	for _, n := range []string{"playing", "category", "explorer", "play_set", "sys_set"} {
		generate(56, 72, filepath.Join("changes_generated", "litegui", "theme1", "launcher", n+"_f.png"), 0, 0, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
			var s slice
			s.center = image.Point{28, 21}
			s.outerradius = 22
			s.inneralpha = 1
			s.outeralpha = 0.5
			fg := color.RGBA{0xE4, 0xFF, 0x78, 0xFF}
			draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Src)

			iconfilename := filepath.Join("changes_edited", "litegui", "theme1", "launcher", n+".png")
			iconreader, err := os.Open(iconfilename)
			if err != nil {
				panic(fmt.Sprintf("%s", err))
			}
			defer iconreader.Close()
			icon, err := png.Decode(iconreader)
			if err != nil {
				panic(fmt.Sprintf("%s: %s", iconfilename, err))
			}
			draw.Draw(img, rect, icon, image.Point{0, 0}, draw.Over)
		})
	}

	circle_fname := filepath.Join("changes_edited", "circle_source.png")
	fnamePattern_boot := filepath.Join("changes_generated", "litegui", "boot_animation", "boot%d.jpg")
	fnamePattern_shutdown := filepath.Join("changes_generated", "litegui", "boot_animation", "shutdown%d.jpg")
	fname_launcher_circle := filepath.Join("changes_generated", "litegui", "theme1", "launcher", "circle.png")
	circle_draw := func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		f := float64(i) / float64(45)
		a := (1.0 - f) * math.Pi / 2.0
		var center image.Point
		center.X = int(160*math.Cos(a)+0.5) + 6
		center.Y = int(-320*math.Sin(a)+0.5) + 370
		width := 24 + uint(480*f)
		draw_png(img, rect, circle_fname, center, width)
	}
	generate(320, 240, fnamePattern_boot, 0, 45, &jpeg.Options{Quality: 50}, circle_draw)
	generate(320, 240, fname_launcher_circle, 45, 45, nil, circle_draw)
	for i := 0; i <= 17; i++ {
		fname_dst := fmt.Sprintf(fnamePattern_shutdown, i)
		fname_src := fmt.Sprintf(fnamePattern_boot, int(17-i)*2)
		fmt.Println("Linking", fname_dst)
		_ = os.Remove(fname_dst)
		os.Link(fname_src, fname_dst)
	}

	generate(32, 32, filepath.Join("changes_generated", "litegui", "theme1", "music_update", "%02d.png"), 0, 11, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		fg := color.RGBA{0xFF, 0x99, 0, 0xFF}
		var s slice
		s.center = cent
		s.inneralpha = 1.0
		s.outeralpha = 1.0
		s.outerradius = 2
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Src)
		s.innerradius = s.outerradius
		s.outerradius = 16
		s.outeralpha = 0.0
		s.angleA = (float64((16-i)%12) - 6.0) / 6.0 * math.Pi
		s.angleB = (float64((20-i)%12) - 6.0) / 6.0 * math.Pi
		draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
	})

	colors := []color.Color{
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x66, 0x99, 0x00, 0xFF},
		color.RGBA{0x00, 0x00, 0x99, 0xFF},
		color.RGBA{0x33, 0x33, 0x33, 0xFF},
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
			s.outeralpha = 1.0
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
		s.inneralpha = 1.0
		s.outeralpha = 1.0
		draw.DrawMask(img, rect, &image.Uniform{color.RGBA{0x99, 0x99, 0x99, 0xFF}}, image.ZP, &s, image.ZP, draw.Over)

		iconfilename := filepath.Join("changes_edited", fmt.Sprintf("theme_icon_%d.png", i))
		var center image.Point
		center.X = 64 + int(math.Cos(ci)*iconradius+0.5)
		center.Y = 64 - int(math.Sin(ci)*iconradius+0.5)
		draw_png(img, rect, iconfilename, center, 0)
	})

	generate(118, 118, filepath.Join("changes_generated", "litegui", "theme1", "adjust", "volume_scale_focus.png"), 0, 0, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
		steps := 120
		var s slice
		s.center = cent
		s.outerradius = 59.0
		s.innerradius = 44.4
		s.inneralpha = 1.0
		s.outeralpha = 1.0
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
				c := 1 - float64(99-j)*0.004
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

	for _, n := range []string{"maxvol", "blktime", "savetime", "sleeptime"} {
		generate(122, 122, filepath.Join("changes_generated", "litegui", "theme1", "adjust", n+"_scale_focus.png"), 0, 0, nil, func(i int, rect image.Rectangle, cent image.Point, img draw.Image) {
			steps := 120
			var s slice
			s.center = cent
			s.outerradius = 56.0
			s.inneralpha = 1.0
			s.outeralpha = 1.0
			for j := 1; j < steps; j++ {
				s.innerradius = s.outerradius - 4.0 - 8.0*float64(j)/float64(steps)
				a := (-0.4 - float64(j+1)/float64(steps)*0.7) * 2 * math.Pi
				b := (-0.4 - float64(j+0)/float64(steps)*0.7) * 2 * math.Pi
				if a < -math.Pi {
					a += 2 * math.Pi
				}
				if b < -math.Pi {
					b += 2 * math.Pi
				}
				var fg color.Color
				c := 1 - float64(steps-j)*0.004
				fg = color.RGBA{uint8(math.Ceil(c * 0x99)), uint8(math.Ceil(c * 0xFF)), 0x00, 0xFF} // topbar_volume_color
				s.angleA = a
				s.angleB = b
				draw.DrawMask(img, rect, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
			}
		})
	}
}
