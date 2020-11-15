SRC := $(wildcard *.v)
OUT := out/$(notdir $(shell pwd))

all: out-dir $(OUT)

clean:
	rm -r out

out-dir:
	mkdir -p out

$(OUT): $(SRC)
	iverilog -o $@ $^
