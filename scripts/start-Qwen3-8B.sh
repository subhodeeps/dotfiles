#!/bin/bash

exec /mnt/nvme0/llm/llama.cpp/build/bin/llama-server \
	-m /mnt/nvme0/llm/llama.cpp/models/Qwen3-8B/Qwen3-8B-Q5_K_M.gguf \
	-ngl 25 \
	--host 0.0.0.0 \
	--port 8080
