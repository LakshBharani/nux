# Ollama Setup Guide for nux

This guide will help you set up Ollama to use local AI models with nux, giving you unlimited AI assistance without any API costs or rate limits.

## Installation

### 1. Install Ollama

Visit [ollama.ai](https://ollama.ai) and download the installer for your platform, or use:

```bash
# macOS (using Homebrew)
brew install ollama

# Linux
curl -fsSL https://ollama.ai/install.sh | sh

# Windows
# Download from ollama.ai
```

### 2. Start Ollama Service

```bash
# This will start Ollama and keep it running
ollama serve
```

### 3. Download a Model

Choose one of these models based on your system:

```bash
# Recommended: Balanced performance and speed
ollama pull llama3.1:8b

# For coding tasks (larger but better at code)
ollama pull codellama:13b

# Lightweight option (faster, less capable)
ollama pull llama3.1:7b

# High-quality option (requires more RAM)
ollama pull llama3.1:70b
```

## Configuration in nux

1. Open nux Settings (⌘ + ,)
2. Go to the "AI" section
3. Select "Ollama (Local)" as your provider
4. Choose your preferred model from the dropdown

## System Requirements

- **RAM**: At least 8GB (16GB+ recommended for larger models)
- **Storage**: 4-30GB depending on model size
- **CPU**: Modern multi-core processor

## Model Recommendations

| Model           | Size   | RAM Required | Best For                     |
| --------------- | ------ | ------------ | ---------------------------- |
| `llama3.1:7b`   | ~4GB   | 8GB+         | Quick responses, basic tasks |
| `llama3.1:8b`   | ~4.7GB | 8GB+         | **Recommended balance**      |
| `codellama:13b` | ~7GB   | 16GB+        | Code-heavy terminal tasks    |
| `llama3.1:70b`  | ~40GB  | 64GB+        | Highest quality (enterprise) |

## Troubleshooting

### Ollama Not Detected

- Ensure Ollama is running: `ollama list`
- Check if service is active: `curl http://localhost:11434/api/tags`
- Restart Ollama: `ollama serve`

### Model Not Found

- List available models: `ollama list`
- Pull missing model: `ollama pull llama3.1:8b`

### Performance Issues

- Try a smaller model (7b instead of 8b)
- Close other memory-intensive applications
- Consider upgrading RAM

## Benefits of Local AI

✅ **No Rate Limits**: Use AI as much as you want  
✅ **No API Costs**: Completely free after setup  
✅ **Privacy**: Everything stays on your machine  
✅ **Always Available**: Works offline  
✅ **Fast Responses**: No network latency

## Support

For Ollama-specific issues, visit:

- [Ollama GitHub](https://github.com/ollama/ollama)
- [Ollama Documentation](https://ollama.ai/docs)

For nux integration issues, check the nux repository.
