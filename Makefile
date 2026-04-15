ASM      = nasm
ASMFLAGS = -f bin
SRC      = rbtree.asm
TARGET   = rbtree.com

all: $(TARGET)

$(TARGET): $(SRC)
	$(ASM) $(ASMFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)

.PHONY: all clean
