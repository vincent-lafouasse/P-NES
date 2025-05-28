NAME   = inkbox
CC	   = cc65
LD     = ld65
TARGET = nes

all: build

build: $(NAME)

$(NAME): $(NAME).o
	$(LD) -t $(TARGET) $(NAME).o -o $(NAME)

$(NAME).o: $(NAME).s
	$(CC) -t $(TARGET) $(NAME).s -o $(NAME).o

.PHONY: all build
