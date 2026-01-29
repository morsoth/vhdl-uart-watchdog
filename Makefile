GHDL ?= /ucrt64/bin/ghdl
GTKWAVE ?= /ucrt64/bin/gtkwave

TOP ?= tb_uart_core

WORKDIR := build/ghdl
WAVE    := build/$(TOP).ghw
GTKW	:= waves/$(TOP).gtkw

GHDLFLAGS := --std=08 --workdir=$(WORKDIR)

RTL_SRCS := \
  rtl/fifo/fifo_sync.vhd \
  rtl/uart/uart_baudgen.vhd \
  rtl/uart/uart_rx.vhd \
  rtl/uart/uart_tx.vhd \
  rtl/uart/uart_core.vhd

TB_SRCS := tb/$(TOP).vhd

.PHONY: all sim wave clean

all: sim wave

sim: $(WAVE)

$(WAVE): $(RTL_SRCS) $(TB_SRCS)
	@mkdir -p $(WORKDIR) build
	$(GHDL) -a $(GHDLFLAGS) $(RTL_SRCS) $(TB_SRCS)
	$(GHDL) -e $(GHDLFLAGS) $(TOP)
	$(GHDL) -r $(GHDLFLAGS) $(TOP) --wave=$(WAVE)

wave: sim
	@mkdir -p $(WORKDIR) waves
	@if [ -f "$(GTKW)" ]; then \
		$(GTKWAVE) $(WAVE) $(GTKW); \
	else \
		$(GTKWAVE) $(WAVE); \
	fi

clean:
	rm -rf build