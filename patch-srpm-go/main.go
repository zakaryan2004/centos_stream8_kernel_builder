package main

import (
	"flag"
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
	srpmInput := flag.String("srpm", "", "Path to SRPM file or URL (required)")
	outFolder := flag.String("out", "src_out", "Output folder for the patched SRPM")
	patchesDir := flag.String("patches", "", "Directory containing patch files to apply (required)")
	arch := flag.String("arch", runtime.GOARCH, "Target architecture (e.g., amd64, arm64)")
	flag.Parse()

	if *srpmInput == "" || *patchesDir == "" {
		flag.Usage()
		os.Exit(1)
	}

	platform := "linux/" + *arch
	fmt.Printf(">>> Using Architecture: %s\n", platform)

	// Ensure output dir exists
	if err := os.MkdirAll(*outFolder, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Failed to create output dir: %v\n", err)
		os.Exit(1)
	}

	// Ensure patches dir exists
	if _, err := os.Stat(*patchesDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Patches directory does not exist: %v\n", err)
		os.Exit(1)
	}

	// Determine the SRPM file path
	var srpmPath string
	if strings.HasPrefix(*srpmInput, "http") {
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

		if err := downloadFile(*srpmInput, srpmPath); err != nil {
			fmt.Fprintf(os.Stderr, "Error: Download failed: %v\n", err)
			os.Exit(1)
		}
	} else {
		// Use local file directly
		fmt.Println(">>> Using local SRPM...")
		absPath, err := filepath.Abs(*srpmInput)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to get absolute path: %v\n", err)
			os.Exit(1)
		}
		srpmPath = absPath
	}

	// Build Docker Image
	fmt.Println(">>> Building Docker Image...")
	buildCmd := exec.Command("docker", "build", "--platform", platform, "-t", "kernel-builder", ".")
	buildCmd.Stdout = os.Stdout
	buildCmd.Stderr = os.Stderr
	if err := buildCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Docker image build failed: %v\n", err)
		os.Exit(1)
	}

	// Run Docker Container
	fmt.Println(">>> Running Docker Container...")

	// Get absolute path for the output volume
	absOut, _ := filepath.Abs(*outFolder)

	dockerArgs := []string{
		"run",
		"--rm", // "-it", "--entrypoint", "", if you want to run interactive terminal
		"--platform", platform,
		"-v", fmt.Sprintf("%s:/src/kernel.src.rpm:ro", srpmPath),
		"-v", fmt.Sprintf("%s:/home/kernelbuilder/output", absOut),
	}

	// Mount patches directory if provided
	if *patchesDir != "" {
		absPatchesDir, err := filepath.Abs(*patchesDir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: Failed to get absolute path for patches: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf(">>> Using patches from: %s\n", absPatchesDir)
		dockerArgs = append(dockerArgs, "-v", fmt.Sprintf("%s:/patches:ro", absPatchesDir))
	}

	dockerArgs = append(dockerArgs, "kernel-builder", "--patchonly") // set /bin/bash if interactive

	runCmd := exec.Command("docker", dockerArgs...)
	runCmd.Stdout = os.Stdout
	runCmd.Stderr = os.Stderr
	runCmd.Stdin = os.Stdin
	if err := runCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: Docker run failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf(">>> Build complete. The patched SRPM is in: %s\n", *outFolder)
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
