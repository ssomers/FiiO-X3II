package main

import (
	"bufio"
	"io"
	"log"
	"os"
)

var problems int

func whereAreWe(i int64, f *os.File, buf *bufio.Reader) {
	fpos, err := f.Seek(0, os.SEEK_CUR)
	if err != nil {
		panic(err)
	}
	apos := fpos - int64(buf.Buffered())
	if i != apos {
		log.Printf("%8d=%d\n", i, apos)
		problems++
		if problems > 10 {
			log.Fatalln("too many problems")
		}
	}
}

func main() {
	f, err := os.Open(os.Args[0])
	if err != nil {
		panic(err)
	}
	defer func() {
		f.Close()
	}()
	buf := bufio.NewReader(f)
	log.Println("Start...")
	for i := int64(0); ; i++ {
		whereAreWe(i, f, buf)
		_, err = buf.ReadByte()
		if err == io.EOF {
			log.Println("Done.")
			return
		}
		if err != nil {
			panic(err)
		}
	}
}
