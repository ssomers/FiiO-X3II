package main

import (
	"bytes"
	"fmt"
	"github.com/nfnt/resize"
	"image"
	"image/draw"
	"image/jpeg"
	"io"
	"log"
	"os"
	"path/filepath"
)

const nameIn = "cover"
const nameOut = "folder"
const verticalMargin = 23
const heightVisible = 176
const widthOut = 320
const heightOut = verticalMargin + heightVisible + verticalMargin
const jpegQuality = 95
const outFmt = "%-79.79s"

var kept, made int

// return value io.EOF means different contents
func compareFileContents(filename string, refContents []byte) error {
	f, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer f.Close()
	actualContents := make([]byte, len(refContents))
	actualLength, err := f.Read(actualContents)
	if err != nil {
		return err // could also be io.EOF
	}
	if actualLength != len(refContents) {
		return io.EOF
	}
	_, err = f.Read(actualContents)
	if err == nil {
		return io.EOF // file has more data
	}
	if err != io.EOF {
		return err
	}
	if !bytes.Equal(actualContents, refContents) {
		return io.EOF // file has different data
	}
	return nil
}

func targetfilename(seqNr int) string {
	suffix := ""
	if seqNr > 0 {
		suffix = fmt.Sprintf("(%d)", seqNr)
	}
	return nameOut + suffix + ".jpg"
}

func readArt(inpath string) (image.Image, error) {
	in, err := os.Open(inpath)
	if err != nil {
		return nil, err
	}
	defer in.Close()
	art, err := jpeg.Decode(in)
	if err != nil {
		return nil, err
	}
	return art, nil
}

func convertArt(art image.Image) []byte {
	art = resize.Resize(0, heightVisible, art, resize.Bilinear)
	outrect := image.Rect(0, 0, widthOut, heightOut)
	horizontalMargin := (widthOut - art.Bounds().Dx()) / 2
	sp := image.Point{-horizontalMargin, -verticalMargin}
	img := image.NewRGBA(outrect)
	draw.Draw(img, outrect, art, sp, draw.Src)
	jpgContents := bytes.NewBuffer(make([]byte, 0, 32768))
	err := jpeg.Encode(jpgContents, img, &jpeg.Options{Quality: jpegQuality})
	if err != nil {
		log.Fatal(err)
	}
	return jpgContents.Bytes()
}

func writeJpg(jpgContents []byte, dir string) {
	var outpath string
	var seqNr int
	var found bool
	for {
		outpath = filepath.Join(dir, targetfilename(seqNr))
		err := compareFileContents(outpath, jpgContents)
		if err == nil {
			found = true
			break
		}
		if os.IsNotExist(err) {
			break
		}
		if err != io.EOF {
			log.Fatalf("%s comparing with %s", err, outpath)
		}
		seqNr++
	}
	if found {
		fmt.Printf(outFmt+"\r", "Kept "+outpath)
		kept++
	} else {
		out, err := os.OpenFile(outpath, os.O_CREATE|os.O_EXCL, 0666)
		if err != nil {
			log.Fatalf("%s creating %s", err, outpath)
		}
		defer out.Close()
		out.Write(jpgContents)
		fmt.Printf(outFmt+"\n", "Made "+outpath)
		made++
	}
}

func main() {
	for _, dir := range os.Args[1:] {
		filepath.Walk(dir, func(path string, fi os.FileInfo, err error) error {
			if err != nil {
				log.Printf("walking %s: %s", path, err)
				return nil
			}
			if !fi.Mode().IsRegular() {
				return nil
			}
			match, err := filepath.Match(nameIn+".jpg", fi.Name())
			if err != nil {
				log.Fatal(err)
			}
			if !match {
				return nil
			}
			art, err := readArt(path)
			if err != nil {
				log.Fatalf("%s reading %s", err, path)
			}
			writeJpg(convertArt(art), filepath.Dir(path))
			return nil
		})
	}
	fmt.Printf(outFmt+"\n", fmt.Sprintf("%d file(s) made, %d file(s) existed already.", made, kept))
}
