package main

import (
	"fmt"
	"log"
	"os"
	"bufio"
)

func print_cursor(x int) {
	for i := 0; i < x; i++ {
		fmt.Print(" ")
	}
	fmt.Print("v\n")
}

func main() {
	if (len(os.Args) != 3) {
		log.Fatal("Usage: ./log_checker expected actual");
	}

	var expected_path = os.Args[1];
	expected_file, err := os.Open(expected_path);
	if (err != nil) {
		log.Fatal("Failed to open file %s", expected_path);
	}
	defer expected_file.Close();

	var actual_path = os.Args[2];
	actual_file, err := os.Open(actual_path);
	if (err != nil) {
		log.Fatal("Failed to open file %s", actual_path);
	}
	defer actual_file.Close();

	expected := bufio.NewScanner(expected_file);
	actual := bufio.NewScanner(actual_file);

	line := 1;
	for ;;line++ {
		if !expected.Scan() {
			break;
		}
		if !actual.Scan() {
			break;
		}

		var expected_str = expected.Text()
		var actual_str = actual.Text()

		var l = min(len(expected_str), len(actual_str))
		for i := 0; i < l; i++ {
			if expected_str[i] != actual_str[i] {
				fmt.Println("Mismatch in line ", line)
				fmt.Println("Expected:")
				print_cursor(i)
				fmt.Println(expected_str)
				fmt.Println("Actual:")
				print_cursor(i)
				fmt.Println(actual_str)
				os.Exit(1)
			}
		}

		if len(expected_str) != len(actual_str) {
				fmt.Println("Mismatch in line ", line)
				fmt.Println("Expected:")
				print_cursor(l)
				fmt.Println(expected_str)
				fmt.Println("Actual:")
				print_cursor(l)
				fmt.Println(actual_str)
				os.Exit(1)
		}

	}

	if expected.Scan() || actual.Scan() {
		log.Fatal("Mismatch file length: ", line)
	}


	fmt.Println("Logs ok");
}
