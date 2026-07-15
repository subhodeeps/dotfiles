#!/bin/bash

exec /mnt/nvme0/llm/llama.cpp/build/bin/llama-server \
	-m /mnt/nvme0/llm/llama.cpp/models/Qwen3-32B/Qwen3-32B-Q5_K_M.gguf \
	-ngl 12 \
	--host 0.0.0.0 \
	--port 8080
