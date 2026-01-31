package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Println("Usage: build-stream8-kernel <src.rpm|url> <outfolder> [arch]")
		os.Exit(1)
	}

	srpmInput := os.Args[1]
	outFolder := os.Args[2]

	// Use provided architecture or default to host architecture
	arch := "linux/" + runtime.GOARCH
	if len(os.Args) >= 4 {
		arch = "linux/" + os.Args[3]
	}
	fmt.Printf(">>> Using Architecture: %s\n", arch)

	// Ensure output dir exists
	if err := os.MkdirAll(outFolder, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to create output dir: %v\n", err)
		os.Exit(1)
	}

	// Determine the SRPM file path
	var srpmPath string
	if strings.HasPrefix(srpmInput, "http") {
		// Download to /tmp
		fmt.Println(">>> Downloading SRPM from URL...")
		tmpFile, err := os.CreateTemp("", "kernel-*.src.rpm")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to create temp file: %v\n", err)
			os.Exit(1)
		}
		tmpFile.Close()
		srpmPath = tmpFile.Name()
		defer os.Remove(srpmPath)

		if err := downloadFile(srpmInput, srpmPath); err != nil {
			fmt.Fprintf(os.Stderr, "Error: Download failed: %v\n", err)
			os.Exit(1)
		}
	} else {
		// Use local file directly
		fmt.Println(">>> Using local SRPM...")
		absPath, err := filepath.Abs(srpmInput)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to get absolute path: %v\n", err)
			os.Exit(1)
		}
		srpmPath = absPath
	}

	// Build Docker Image
	fmt.Println(">>> Building Docker Image...")
	buildCmd := exec.Command("docker", "build", "--platform", arch, "-t", "kernel-builder", ".")
	buildCmd.Stdout = os.Stdout
	buildCmd.Stderr = os.Stderr
	if err := buildCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Docker image build failed: %v\n", err)
		os.Exit(1)
	}

	// Run Docker Container
	fmt.Println(">>> Running Docker Container...")

	// Get absolute path for the output volume
	absOut, _ := filepath.Abs(outFolder)

	runCmd := exec.Command("docker", "run",
		"--platform", arch,
		"--rm",
		"-v", fmt.Sprintf("%s:/src/kernel.src.rpm:ro", srpmPath),
		"-v", fmt.Sprintf("%s:/home/kernelbuilder/output", absOut),
		"kernel-builder",
	)
	runCmd.Stdout = os.Stdout
	runCmd.Stderr = os.Stderr
	if err := runCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Docker run failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf(">>> Build complete. RPMs are in: %s\n", outFolder)
}

func downloadFile(url string, dest string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}
