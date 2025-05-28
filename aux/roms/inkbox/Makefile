NAME   = inkbox
CC	   = ca65
LD     = ld65
TARGET = nes

all: build

build: $(NAME)

$(NAME): $(NAME).o
	$(LD) -t $(TARGET) $(NAME).o -o $(NAME).nes

$(NAME).o: $(NAME).s
	$(CC) -t $(TARGET) $(NAME).s -o $(NAME).o --verbose 

clean:
	rm -rf $(NAME).o

fclean: clean
	rm -rf $(NAME).nes

.PHONY: all build clean fclean
