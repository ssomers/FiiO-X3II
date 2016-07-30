package main

import (
	"bufio"
	"io"
	"log"
	"os"
)

func BufioTell(f *os.File, buf *bufio.Reader) (int64, error) {
	fpos, err := f.Seek(0, os.SEEK_CUR)
	if err != nil {
		return 0, err
	}
	apos := fpos - int64(buf.Buffered())
	return apos, nil
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
	problems := 10
	for i := int64(0); ; i++ {
		apos, err := BufioTell(f, buf)
		if err != nil {
			panic(err)
		}
		if i != apos {
			log.Printf("%8d=%d\n", i, apos)
			problems--
			if problems == 0 {
				log.Fatalln("too many problems")
			}
		}

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
