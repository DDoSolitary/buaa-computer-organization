SRC := $(wildcard *.v)
OUT := $(patsubst %.v, out/%, $(SRC))

all: out-dir $(OUT)

clean:
	rm -r out

out-dir:
	mkdir -p out

out/%: %.v
	iverilog -o $@ -DDUMPFILE="\"$(notdir $@).vcd\"" $<
