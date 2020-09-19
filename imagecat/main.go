package main

import (
	"encoding/base64"
	"fmt"
	"github.com/pkg/errors"
	"io"
	"os"
	"strings"
)

func main(){

	if len(os.Args)<2{
		fmt.Fprintf(os.Stderr, "missing paths of images to view")
		os.Exit(2)
	}

	for _,path := range os.Args[1:]{

		if err := cat(path); err!=nil{
			fmt.Fprintf(os.Stderr, "failed to cat %s: %v\n",path,err)
		}
	}
}

//ESC ] 1337 ; File = [arguments] : base-64 encoded file contents ^G
//https://iterm2.com/documentation-images.html
func cat(path string) error{

	f,err := os.Open(path)
	if err!=nil{
		return errors.Wrap(err,"failed to open image")
	}
	defer f.Close()

	wc := NewWriter(os.Stdout)
	if _,err = io.Copy(wc,f); err!=nil{
		return err
	}
	return wc.Close()
}

type writer struct {
	done chan struct{}
	pw *io.PipeWriter
}
func (receiver *writer) Write(data []byte) (int,error){
	return receiver.pw.Write(data)
}
func (receiver *writer) Close() error{
	if err:= receiver.pw.Close();err!=nil{
		return err
	}

	<-receiver.done
	return nil
}
func NewWriter(w io.Writer) io.WriteCloser{
	pr,pw := io.Pipe()
	wc := &writer{make(chan struct{}), pw}
	go func() {
		defer close(wc.done)
		err := Copy(w,pr)
		pr.CloseWithError(err)
	}()
	return wc
}
func Copy(w io.Writer, r io.Reader) error{

	header := strings.NewReader("\033]1337;File=inline=1:")
	footer := strings.NewReader("\a\n")

	body,pw := io.Pipe()
	go func() {
		defer pw.Close()
		wc := base64.NewEncoder(base64.StdEncoding, pw)
		_, err := io.Copy(wc, r)
		if err != nil {
			pw.CloseWithError(errors.Wrap(err, "failed to encode image"))
		}
		if err := wc.Close(); err != nil {
			pw.CloseWithError(errors.Wrap(err, "failed to close base64 encoder"))
		}

	}()
	_,err := io.Copy(w, io.MultiReader(header,body,footer))
	return err
}

