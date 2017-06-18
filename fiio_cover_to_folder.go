package main

import (
	"bufio"
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
const heightVisible = 200
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

type Writer struct {
	kept, made, bent int
}

type Asker struct {
	reader     io.ByteReader
	yes_to_all bool
}

func NewAsker(r io.Reader) *Asker {
	return &Asker{reader: bufio.NewReader(r)}
}

func (a *Asker) ask(question string) (bool, error) {
	for {
		if a.yes_to_all {
			return true, nil
		}
		fmt.Print(question + "? Yes/No/All\b\b\b\b\b\b\b\b\b\b")
		answer, err := a.reader.ReadByte()
		if err != nil {
			return false, err
		}
		if answer == 'y' {
			return true, nil
		}
		if answer == 'n' {
			return false, nil
		}
		if answer == 'a' {
			a.yes_to_all = true
		}
	}
}

func (w *Writer) findOrWriteJpg(asker *Asker, jpgContents []byte, dir string) error {
	for seqNr := 0; ; seqNr++ {
		outpath := filepath.Join(dir, targetfilename(seqNr))
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
			return nil
		}
	}
}

func (w *Writer) visitFile(asker *Asker, path string, decode Decoder) error {
	art, err := readArt(path, decode)
	if err != nil {
		return err
	}
	jpgContents, err := convertArt(art)
	if err != nil {
		return err
	}
	err = w.findOrWriteJpg(asker, jpgContents, filepath.Dir(path))
	return err
}

func (w *Writer) visitDir(asker *Asker, dir string) error {
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
				return w.visitFile(asker, path, decode)
			}
		}
		return nil
	})
}

func main() {
	asker := NewAsker(os.Stdin)
	var writer Writer
	var dirs = []string{"."}
	if len(os.Args) > 1 {
		dirs = os.Args[1:]
	}
	for _, dir := range dirs {
		err := writer.visitDir(asker, dir)
		if err != nil {
			panic(err)
		}
	}
	fmt.Printf(outFmt+"\n", fmt.Sprintf("%d file(s) created, %d file(s) updated, %d file(s) existed already.", writer.made, writer.bent, writer.kept))
}
