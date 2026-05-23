package main

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/exec"
	"time"
)

type ExecuteRequest struct {
	Code string `json:"code"`
}

type ExecuteResponse struct {
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Using Go 1.22+ routing features: native method matching and strict path matching
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", handleHome)
	mux.HandleFunc("POST /execute", handleExecute)

	log.Printf("Server listening on port %s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	message := "Python code executor is running\n\n" +
		"Sample curl command to send Python code:\n" +
		"curl -X POST http://localhost:8080/execute \\\n" +
		"  -H \"Content-Type: application/json\" \\\n" +
		"  -d '{\"code\": \"print(\\\"Hello from Sandbox!\\\")\"}'\n"
	w.Write([]byte(message))
}

func handleExecute(w http.ResponseWriter, r *http.Request) {
	var req ExecuteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON payload"})
		return
	}

	if req.Code == "" {
		respondJSON(w, http.StatusBadRequest, map[string]string{"error": "Missing or invalid 'code' field"})
		return
	}

	// 1. Context and Timeout Budget
	// Limits execution to 30 seconds to prevent hung requests or infinite loop resource exhaustion.
	// Also respects client cancellations automatically.
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "/usr/local/gcp/bin/sandbox", "do", "--", "/usr/bin/python3", "-c", req.Code)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	// Run command (will be terminated if ctx timeout fires or client disconnects)
	_ = cmd.Run()

	respondJSON(w, http.StatusOK, ExecuteResponse{
		Stdout: stdout.String(),
		Stderr: stderr.String(),
	})
}

// respondJSON is a clean helper to write headers and serialize JSON payloads concisely
func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
