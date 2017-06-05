package main

import (
	"bytes"
	"fmt"
	"github.com/nfnt/resize"
	"image"
	"image/draw"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
)

const nameIn = "cover"
const nameOut = "folder"
const verticalMargin = 0
const heightVisible = 198
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
	art = resize.Resize(0, heightVisible, art, resize.Bilinear)
	outrect := image.Rect(0, 0, widthOut, heightOut)
	horizontalMargin := (widthOut - art.Bounds().Dx()) / 2
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

func targetfilename(seqNr int) string {
	suffix := ""
	if seqNr > 0 {
		suffix = fmt.Sprintf("(%d)", seqNr)
	}
	return nameOut + suffix + ".jpg"
}

func findJpg(jpgContents []byte, dir string) (outpath string, found bool, finalErr error) {
	for seqNr := 0; ; seqNr++ {
		outpath = filepath.Join(dir, targetfilename(seqNr))
		err := compareFileContents(outpath, jpgContents)
		if err == nil {
			found = true
			return
		}
		if os.IsNotExist(err) {
			return // past highest sequence number (or there's a gap)
		}
		if err != io.EOF {
			finalErr = err
			return // trouble
		}
	}
}

type Writer struct {
	kept, made int
}

func (w *Writer) findOrWriteJpg(jpgContents []byte, dir string) error {
	outpath, found, err := findJpg(jpgContents, dir)
	if err != nil {
		return err
	}
	if found {
		fmt.Printf(outFmt+"\r", "Kept "+outpath)
		w.kept++
	} else {
		out, err := os.OpenFile(outpath, os.O_CREATE|os.O_EXCL, 0666)
		if err != nil {
			return err
		}
		defer out.Close()
		out.Write(jpgContents)
		fmt.Printf(outFmt+"\n", "Made "+outpath)
		w.made++
	}
	return nil
}

func (w *Writer) visitFile(path string, decode Decoder) error {
	art, err := readArt(path, decode)
	if err != nil {
		return err
	}
	jpgContents, err := convertArt(art)
	if err != nil {
		return err
	}
	err = w.findOrWriteJpg(jpgContents, filepath.Dir(path))
	return err
}

func (w *Writer) visitDir(dir string) error {
	return filepath.Walk(dir, func(path string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !fi.Mode().IsRegular() {
			return nil
		}
		for ext, decode := range map[string]Decoder{".jpg": jpeg.Decode, ".png": png.Decode} {
			match, err := filepath.Match(nameIn+ext, fi.Name())
			if err != nil {
				return err
			}
			if match {
				return w.visitFile(path, decode)
			}
		}
		return nil
	})
}

func main() {
	var writer Writer
	var dirs = []string{"."}
	if len(os.Args) > 1 {
		dirs = os.Args[1:]
	}
	for _, dir := range dirs {
		err := writer.visitDir(dir)
		if err != nil {
			panic(err)
		}
	}
	fmt.Printf(outFmt+"\n", fmt.Sprintf("%d file(s) made, %d file(s) existed already.", writer.made, writer.kept))
}
