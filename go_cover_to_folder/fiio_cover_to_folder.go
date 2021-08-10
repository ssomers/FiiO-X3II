package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/nfnt/resize"
	"golang.org/x/image/webp"
	"image"
	"image/draw"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const nameIn = "cover"
const fnameOut = "folder.jpg"
const verticalMargin = 16
const heightVisible = 208
const widthOut = 320
const heightOut = verticalMargin + heightVisible + verticalMargin
const jpegQuality = 95
const outFmt = "%-79.79s"

// Compare contents of file to some contents we need.
// Returns nil if the contents match,
// returns io.EOF if file has different contents,
// returns genuine error if file cannot be read.
func compareFileContents(filename string, refContents []byte) error {
	f, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer f.Close()
	actualContents := make([]byte, len(refContents))
	actualLength, err := f.Read(actualContents)
	if err != nil {
		return err // file cannot be read or (io.EOF) is empty
	}
	if actualLength != len(refContents) {
		return io.EOF // file has less data
	}
	_, err = f.Read(actualContents)
	if err == nil {
		return io.EOF // file has more data
	}
	if err != io.EOF {
		return err // weird
	}
	if !bytes.Equal(actualContents, refContents) {
		return io.EOF // file has different data
	}
	return nil
}

type Decoder func(io.Reader) (image.Image, error)

func readArt(inpath string, decode Decoder) (image.Image, error) {
	in, err := os.Open(inpath)
	if err != nil {
		return nil, err
	}
	defer in.Close()
	art, err := decode(in)
	if err != nil {
		return nil, err
	}
	return art, nil
}

func convertArt(art image.Image) ([]byte, error) {
	outrect := image.Rect(0, 0, widthOut, heightOut)
	art = resize.Resize(0, heightVisible, art, resize.MitchellNetravali)
	widthArt := art.Bounds().Dx()
	horizontalMargin := (widthOut - widthArt) / 2
	sp := image.Point{-horizontalMargin, -verticalMargin}
	img := image.NewRGBA(outrect)
	draw.Draw(img, outrect, art, sp, draw.Src)
	jpgContents := bytes.NewBuffer(make([]byte, 0, 32768))
	err := jpeg.Encode(jpgContents, img, &jpeg.Options{Quality: jpegQuality})
	if err != nil {
		return nil, err
	}
	return jpgContents.Bytes(), nil
}

type Writer struct {
	kept, made, bent int
}

type Asker struct {
	scanner    *bufio.Scanner
	yes_to_all bool
}

func NewAsker(r io.Reader) *Asker {
	return &Asker{scanner: bufio.NewScanner(r)}
}

func (a *Asker) ask(question string) (bool, error) {
	if a.yes_to_all {
		return true, nil
	}
	for {
		fmt.Print(question + "? Yes/No/All\b\b\b\b\b\b\b\b\b\b")
		if !a.scanner.Scan() {
			return false, a.scanner.Err()
		}
		answer := strings.ToLower(a.scanner.Text())
		if answer == "y" {
			return true, nil
		}
		if answer == "n" {
			return false, nil
		}
		if answer == "a" {
			a.yes_to_all = true
			return true, nil
		}
		fmt.Print("Pardon?\n")
	}
}

func (w *Writer) findOrWriteJpg(asker *Asker, jpgContents []byte, outpath string) error {
	err := compareFileContents(outpath, jpgContents)
	found_same := err == nil
	found_diff := err == io.EOF
	found_none := os.IsNotExist(err)
	if !found_same && !found_diff && !found_none {
		return err
	}

	write_it := found_none
	if found_diff {
		write_it, err = asker.ask(outpath + " exists, overwrite")
		if err != nil {
			return err
		}
	}

	if found_same {
		w.kept++
		return nil
	}
	if write_it {
		out, err := os.Create(outpath)
		if err != nil {
			return err
		}
		defer out.Close()
		out.Write(jpgContents)
		if found_none {
			fmt.Printf(outFmt+"\n", "Made "+outpath)
			w.made++
		} else {
			fmt.Printf(outFmt+"\n", "Bent "+outpath)
			w.bent++
		}
	}
	return nil
}

func (w *Writer) convertFile(asker *Asker, inpath string, outpath string, decode Decoder) error {
	art, err := readArt(inpath, decode)
	if err != nil {
		return err
	}
	jpgContents, err := convertArt(art)
	if err != nil {
		return err
	}
	err = w.findOrWriteJpg(asker, jpgContents, outpath)
	return err
}

func findDecoder(fname string) (Decoder, error) {
	for ext, decode := range map[string]Decoder{
		".jpg":  jpeg.Decode,
		".png":  png.Decode,
		".webp": webp.Decode} {
		if ext == filepath.Ext(fname) {
			return decode, nil
		}
	}
	return nil, fmt.Errorf("Unknown filename %s", fname)
}

func (w *Writer) visitFile(asker *Asker, inpath string, outpath string) error {
	decode, err := findDecoder(inpath)
	if decode == nil {
		return err
	}
	return w.convertFile(asker, inpath, outpath, decode)
}

func (w *Writer) visitDir(asker *Asker, dir string) error {
	return filepath.Walk(dir, func(inpath string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !fi.Mode().IsRegular() {
			return nil
		}
		match, err := filepath.Match(nameIn+".*", fi.Name())
		if err != nil {
			return err
		}
		if match {
			outpath := filepath.Join(filepath.Dir(inpath), fnameOut)
			return w.visitFile(asker, inpath, outpath)
		}
		return nil
	})
}

func main() {
	asker := NewAsker(os.Stdin)
	var writer Writer
	if len(os.Args) == 1 {
		fmt.Printf(outFmt+"\n", "Nothing to do")
	} else if len(os.Args) == 2 {
		dir := os.Args[1]
		err := writer.visitDir(asker, dir)
		if err != nil {
			panic(err)
		}
		fmt.Printf(outFmt+"\n", fmt.Sprintf("%d file(s) created, %d file(s) updated, %d file(s) existed already.", writer.made, writer.bent, writer.kept))
	} else if len(os.Args) == 3 {
		inpath := os.Args[1]
		outpath := os.Args[2]
		err := writer.visitFile(asker, inpath, outpath)
		if err != nil {
			panic(err)
		}
	} else {
		fmt.Printf(outFmt+"\n", os.Args)
	}
}
