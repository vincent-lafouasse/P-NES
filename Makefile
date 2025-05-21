CXXFLAGS = -std=c++17 -Wall -Wextra -pedantic -g3

.PHONY: build
build:
	g++ $(CXXFLAGS) main.cpp -o exe

.PHONY: run
run: build
	./exe

