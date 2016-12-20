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
const heightVisible = 169
const widthOut = 320
const heightOut = verticalMargin + heightVisible + verticalMargin
const jpegQuality = 95
const outFmt = "%-79.79s"

var kept, made int

// return value io.EOF means different contents
func equalFileContents(file1, file2 string) error {
	fi1, err := os.Stat(file1)
	if err != nil {
		return err
	}
	fi2, err := os.Stat(file2)
	if err != nil {
		return err
	}
	if fi1.Size() != fi2.Size() {
		return io.EOF
	}

	f1, err := os.Open(file1)
	if err != nil {
		return err
	}
	defer f1.Close()
	f2, err := os.Open(file2)
	if err != nil {
		return err
	}
	defer f2.Close()
	b1 := make([]byte, 4096)
	b2 := make([]byte, 4096)
	for {
		len1, err1 := f1.Read(b1)
		len2, err2 := f2.Read(b2)
		if len1 != len2 {
			return io.EOF // file must have changed after we checked Size()
		}
		if err1 == io.EOF && err2 == io.EOF {
			return nil
		}
		if err1 != nil {
			return err1 // could also be io.EOF
		}
		if err2 != nil {
			return err2 // could also be io.EOF
		}
		if !bytes.Equal(b1[0:len1], b2[0:len2]) {
			return io.EOF
		}
	}
}

func targetfilename(seqNr int) string {
	suffix := ""
	if seqNr > 0 {
		suffix = fmt.Sprintf("(%d)", seqNr)
	}
	return nameOut + suffix + ".jpg"
}

func convert(inpath string) {
	in, err := os.Open(inpath)
	if err != nil {
		log.Fatalf("%s reading %s", err, inpath)
	}
	art, err := jpeg.Decode(in)
	in.Close()
	if err != nil {
		log.Fatalf("%s reading %s", err, inpath)
	}

	art = resize.Resize(0, heightVisible, art, resize.Bilinear)
	outrect := image.Rect(0, 0, widthOut, heightOut)
	horizontalMargin := (widthOut - art.Bounds().Dx()) / 2
	sp := image.Point{-horizontalMargin, -verticalMargin}
	img := image.NewRGBA(outrect)
	draw.Draw(img, outrect, art, sp, draw.Src)

	var seqNr int
	var outpath string
	var out *os.File
	for out == nil {
		outpath = filepath.Join(filepath.Dir(inpath), targetfilename(seqNr))
		out, err = os.OpenFile(outpath, os.O_CREATE|os.O_EXCL, 0666)
		if err == nil {
			break
		}
		if !os.IsExist(err) {
			log.Fatalf("%s writing %s", err, outpath)
		}
		seqNr++
	}
	err = jpeg.Encode(out, img, &jpeg.Options{Quality: jpegQuality})
	if err != nil {
		log.Fatalf("%s writing %s", err, outpath)
	}
	err = out.Close()
	if err != nil {
		log.Fatalf("%s finishing %s", err, outpath)
	}

	var equalTo string
	for prevSeqNr := 0; prevSeqNr < seqNr; prevSeqNr++ {
		prevOutpath := filepath.Join(filepath.Dir(inpath), targetfilename(prevSeqNr))
		err = equalFileContents(prevOutpath, outpath)
		if err == nil {
			equalTo = prevOutpath
			break
		}
		if err != io.EOF {
			log.Fatalf("%s comparing %s and %s", err, prevOutpath, outpath)
		}
	}
	if equalTo == "" {
		fmt.Printf(outFmt+"\n", "Made "+outpath)
		made++
	} else {
		fmt.Printf(outFmt+"\r", "Kept "+equalTo)
		kept++
		err = os.Remove(outpath)
		if err != nil {
			log.Fatalf("%s removing %s", err, outpath)
		}
	}
}

func main() {
	for _, dir := range os.Args[1:] {
		filepath.Walk(dir, func(path string, fi os.FileInfo, err error) error {
			if err != nil {
				fmt.Println("walking %s: %s", path, err)
				return nil
			}
			if !fi.Mode().IsRegular() {
				return nil
			}
			match, err := filepath.Match(nameIn+".jpg", fi.Name())
			if err != nil {
				panic(err)
				os.Exit(1)
			}
			if !match {
				return nil
			}
			convert(path)
			return nil
		})
	}
	fmt.Printf(outFmt+"\n", fmt.Sprintf("%d file(s) made, %d file(s) existed already.", made, kept))
}
