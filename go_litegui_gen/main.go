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

	xdraw "golang.org/x/image/draw"
)

type slice struct {
	// Image definition for (parts of) a disc.
	// Coordinates and radius are in pixels with the x-axis going east and y-axis going south(!)
	// Angles are in radians from -Pi to +Pi, counter-clockwise with x-axis at angle 0.
	center                   image.Point
	innerradius, outerradius float64
	inneralpha, outeralpha   float64
	angleA, angleB           float64
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
	return image.Rectangle{
		d.center.Sub(image.Pt(rr, rr)),
		d.center.Add(image.Pt(rr+1, rr+1))}
}

func min(x int, y int) int {
	if x < y {
		return x
	} else {
		return y
	}
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
	a := math.Atan2(-dy, dx)
	if d.angleA < d.angleB {
		if a < d.angleA || d.angleB < a {
			return color.Transparent
		}
	}
	if d.angleA > d.angleB {
		if d.angleB < a && a < d.angleA {
			return color.Transparent
		}
	}
	w := math.Sqrt((rr - minrr) / (maxrr - minrr))
	alpha := (1.0-w)*d.inneralpha + w*d.outeralpha
	return color.Alpha16{uint16(math.Ceil(float64(color.Opaque.A) * alpha))}
}

func generate(fnamePattern string, first int, last int, jpg *jpeg.Options, gen func(i int) draw.Image) {
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

		img := gen(i)

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

func read_png(fname string) image.Image {
	reader, err := os.Open(fname)
	if err != nil {
		panic(fmt.Sprintf("%s", err))
	}
	defer reader.Close()
	img, err := png.Decode(reader)
	if err != nil {
		panic(fmt.Sprintf("%s: %s", fname, err))
	}
	return img
}

func surround_png(margin int, thickness int, icon_color *color.Color, inpath string, outpath string) {
	icon := read_png(inpath)
	bounds := icon.Bounds()
	size := bounds.Size()
	length := min(size.X, size.Y)
	if 2*(margin+thickness) >= length {
		panic(fmt.Sprintf("2 * %d ≥ %d, %d", margin+thickness, size.X, size.Y))
	}
	offset := (length - 2*margin) / 5

	var icon_img draw.Image
	if icon_color != nil {
		bw := color.Palette([]color.Color{color.Black, *icon_color})
		icon_img = image.NewPaletted(bounds, bw)
	} else {
		icon_img = image.NewRGBA(bounds)
	}
	draw.Draw(icon_img, bounds, icon, image.ZP, draw.Src)
	generate(outpath, 0, 0, nil, func(i int) draw.Image {
		img := image.NewRGBA(bounds)
		draw.Draw(img, bounds, icon_img, image.ZP, draw.Src)
		if thickness > 0 {
			fg := color.White
			north := image.Rect(margin+offset, margin, size.X-offset-margin, margin+thickness)
			west := image.Rect(margin, margin+offset, margin+thickness, size.Y-offset-margin)
			east := image.Rect(size.X-thickness-margin, margin+offset, size.X-margin, size.Y-offset-margin)
			south := image.Rect(margin+offset, size.Y-thickness-margin, size.X-offset-margin, size.Y-margin)
			nw := slice{image.Pt(margin+offset, margin+offset),
				float64(offset - thickness), float64(offset), 1.0, 1.0,
				math.Pi / 2, math.Pi}
			ne := slice{image.Pt(size.X-1-offset-margin, margin+offset),
				float64(offset - thickness), float64(offset), 1.0, 1.0,
				0, math.Pi / 2}
			sw := slice{image.Pt(margin+offset, size.Y-1-offset-margin),
				float64(offset - thickness), float64(offset), 1.0, 1.0,
				-math.Pi, -math.Pi / 2}
			se := slice{image.Pt(size.X-1-offset-margin, size.Y-1-offset-margin),
				float64(offset - thickness), float64(offset), 1.0, 1.0,
				-math.Pi / 2, 0}
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &nw, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &ne, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &sw, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &se, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &north, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &west, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &east, image.ZP, draw.Over)
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &south, image.ZP, draw.Over)
		}
		return img
	})
}

func main() {
	for _, n := range []string{"playing", "category", "explorer", "play_set", "sys_set"} {
		inpath := filepath.Join("..", "changes_edited", "litegui", "theme1", "launcher", n+".png")
		outpath := filepath.Join("..", "changes_generated", "litegui", "theme1", "launcher", n+"_f.png")
		surround_png(0, 2, nil, inpath, outpath)
	}
	for _, n := range []string{"collec", "collect_select_", "cycle", "order", "playing_menu_add", "random", "rm", "single", "single_play"} {
		inpath := "playing_icon_" + n + ".png"
		outpath0 := filepath.Join("..", "changes_generated", "litegui", "theme1", "playing", n+"0.png")
		outpath1 := filepath.Join("..", "changes_generated", "litegui", "theme1", "playing", n+"1.png")
		var icon_color color.Color = color.RGBA{0xCC, 0xFF, 0x00, 0xFF}
		surround_png(0, 0, &icon_color, inpath, outpath0)
		surround_png(2, 2, &icon_color, inpath, outpath1)
	}

	fnamePattern_boot := filepath.Join("..", "changes_generated", "litegui", "boot_animation", "boot%d.jpg")
	fnamePattern_shutdown := filepath.Join("..", "changes_generated", "litegui", "boot_animation", "shutdown%d.jpg")
	fname_launcher_circle := filepath.Join("..", "changes_generated", "litegui", "theme1", "launcher", "circle.png")
	bounds := image.Rect(0, 0, 320, 240)
	center0 := image.Pt(-9, 58)
	center45 := image.Pt(bounds.Max.X/2, 350)
	width0 := 40
	width45 := 500
	angle0 := 0.5
	fX := float64(center45.X-center0.X) / (1 - math.Sin(angle0))
	fY := float64(center45.Y-center0.Y) / -math.Cos(angle0)
	tX := float64(center45.X) - fX
	tY := float64(center45.Y)
	icon := read_png("circle.png")
	icon_size := icon.Bounds().Size()
	circle_draw := func(i int) draw.Image {
		img := image.NewRGBA(bounds)
		f := float64(i) / float64(45)
		angle := angle0 + (math.Pi/2.0-angle0)*f
		var center image.Point
		center.X = int(math.Round(math.Sin(angle)*fX + tX))
		center.Y = int(math.Round(math.Cos(angle)*fY + tY))
		width := width0 + int(float64(width45-width0)*f)
		height := int(math.Round(float64(width) / float64(icon_size.X) * float64(icon_size.Y)))
		scaled_size := image.Pt(width, height)
		var scaled_bounds image.Rectangle
		scaled_bounds.Min = center.Sub(scaled_size.Div(2))
		scaled_bounds.Max = scaled_bounds.Min.Add(scaled_size)
		xdraw.NearestNeighbor.Scale(img, scaled_bounds, icon, icon.Bounds(), draw.Over, nil)
		return img
	}
	generate(fnamePattern_boot, 0, 45, &jpeg.Options{Quality: 50}, circle_draw)
	generate(fname_launcher_circle, 45, 45, nil, circle_draw)
	for i := 0; i <= 17; i++ {
		fname_dst := fmt.Sprintf(fnamePattern_shutdown, i)
		fname_src := fmt.Sprintf(fnamePattern_boot, int(17-i)*2)
		fmt.Println("Linking", fname_dst)
		_ = os.Remove(fname_dst)
		os.Link(fname_src, fname_dst)
	}

	generate(filepath.Join("..", "changes_generated", "litegui", "theme1", "music_update", "%02d.png"), 0, 11, nil, func(i int) draw.Image {
		bounds := image.Rect(0, 0, 32, 32)
		img := image.NewRGBA(bounds)
		fg := color.RGBA{0xFF, 0x99, 0, 0xFF}
		var s slice
		s.center = bounds.Max.Div(2)
		s.inneralpha = 1.0
		s.outeralpha = 1.0
		s.outerradius = 2
		draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Src)
		s.innerradius = s.outerradius
		s.outerradius = 16
		s.outeralpha = 0.0
		s.angleA = (float64((16-i)%12) - 6.0) / 6.0 * math.Pi
		s.angleB = (float64((20-i)%12) - 6.0) / 6.0 * math.Pi
		draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		return img
	})

	theme_colors := []color.Color{
		color.RGBA{0x99, 0xCC, 0x00, 0xFF},
		color.RGBA{0x99, 0xCC, 0x00, 0xFF},
		color.RGBA{0x99, 0xCC, 0x00, 0xFF},
		color.RGBA{0x99, 0xCC, 0x00, 0xFF},
		color.RGBA{0xCC, 0xCC, 0xCC, 0xFF},
		color.RGBA{0x66, 0x66, 0x99, 0xFF},
	}
	generate(filepath.Join("..", "changes_generated", "litegui", "theme1", "theme", "theme_%d.png"), 1, 6, nil, func(i int) draw.Image {
		bounds := image.Rect(0, 0, 128, 128)
		img := image.NewRGBA(bounds)
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
			var fg = theme_colors[j-1]
			var s slice
			s.center = bounds.Min.Add(bounds.Max.Div(2))
			s.outerradius = outerradius
			s.outeralpha = 1.0
			if j != i {
				s.innerradius = innerradius
			}
			s.angleA = a
			s.angleB = b
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		}
		var s slice
		s.center = bounds.Min.Add(bounds.Max.Div(2))
		s.outerradius = cutoffradius
		s.inneralpha = 1.0
		s.outeralpha = 1.0
		draw.DrawMask(img, bounds, &image.Uniform{color.RGBA{0x99, 0x99, 0x99, 0xFF}}, image.ZP, &s, image.ZP, draw.Over)

		iconfilename := fmt.Sprintf("theme_icon_%d.png", i)
		var center image.Point
		center.X = 64 + int(math.Round(math.Cos(ci)*iconradius))
		center.Y = 64 - int(math.Round(math.Sin(ci)*iconradius))
		icon := read_png(iconfilename)
		position := icon.Bounds().Max.Div(2).Sub(center)
		draw.Draw(img, bounds, icon, position, draw.Over)
		return img
	})

	generate(filepath.Join("..", "changes_generated", "litegui", "theme1", "adjust", "volume_scale_focus.png"), 0, 0, nil, func(i int) draw.Image {
		bounds := image.Rect(0, 0, 118, 118)
		img := image.NewRGBA(bounds)
		steps := 120
		var s slice
		s.center = bounds.Min.Add(bounds.Max.Div(2))
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
			draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
		}
		return img
	})

	for _, n := range []string{"maxvol", "blktime", "savetime", "sleeptime"} {
		generate(filepath.Join("..", "changes_generated", "litegui", "theme1", "adjust", n+"_scale_focus.png"), 0, 0, nil, func(i int) draw.Image {
			bounds := image.Rect(0, 0, 122, 122)
			img := image.NewRGBA(bounds)
			steps := 120
			var s slice
			s.center = bounds.Min.Add(bounds.Max.Div(2))
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
				draw.DrawMask(img, bounds, &image.Uniform{fg}, image.ZP, &s, image.ZP, draw.Over)
			}
			return img
		})
	}
}
