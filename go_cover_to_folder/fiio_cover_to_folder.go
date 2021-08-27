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

func ask(scanner *bufio.Scanner, question string) (bool, error) {
	for {
		fmt.Print(question + "? Yes/No\b\b\b\b\b\b")
		if !scanner.Scan() {
			return false, scanner.Err()
		}
		answer := strings.ToLower(scanner.Text())
		if answer == "y" {
			return true, nil
		}
		if answer == "n" {
			return false, nil
		}
		fmt.Print("Pardon?\n")
	}
}

func findOrWriteJpg(scanner *bufio.Scanner, jpgContents []byte, outpath string) error {
	err := compareFileContents(outpath, jpgContents)
	found_same := err == nil
	found_diff := err == io.EOF
	found_none := os.IsNotExist(err)
	if !found_same && !found_diff && !found_none {
		return err
	}

	var write_it bool
	if found_none {
		write_it = true
		fmt.Printf("Making %s\n", outpath)
	}
	if found_diff {
		write_it, err = ask(scanner, "Update "+outpath)
		if err != nil {
			return err
		}
	}
	if found_same {
		return nil
	}
	if write_it {
		out, err := os.Create(outpath)
		if err != nil {
			return err
		}
		defer out.Close()
		out.Write(jpgContents)
	}
	return nil
}

func convertFile(scanner *bufio.Scanner, inpath string, outpath string, decode Decoder) error {
	art, err := readArt(inpath, decode)
	if err != nil {
		return err
	}
	jpgContents, err := convertArt(art)
	if err != nil {
		return err
	}
	err = findOrWriteJpg(scanner, jpgContents, outpath)
	return err
}

func findDecoder(fname string) Decoder {
	for ext, decode := range map[string]Decoder{
		".jpg":  jpeg.Decode,
		".png":  png.Decode,
		".webp": webp.Decode} {
		if ext == filepath.Ext(fname) {
			return decode
		}
	}
	return nil
}

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage: source-path destination-path")
		return
	}
	inpath := os.Args[1]
	outpath := os.Args[2]
	decode := findDecoder(inpath)
	if decode == nil {
		fmt.Printf("Unrecognized filename %s\n", inpath)
		return
	}
	scanner := bufio.NewScanner(os.Stdin)
	err := convertFile(scanner, inpath, outpath, decode)
	if err != nil {
		panic(err)
	}
}
