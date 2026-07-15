#!/bin/bash

exec /mnt/nvme0/llm/llama.cpp/build/bin/llama-server \
	-m /mnt/nvme0/llm/llama.cpp/models/Qwen3-14B/Qwen3-14B-Q5_K_M.gguf \
	-ngl 16 \
	--host 0.0.0.0 \
	--port 8080
