FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY pyproject.toml ./

# Install Python dependencies
RUN pip install uv && \
    uv pip install --system -e .

# Copy source code
COPY src/ ./src/
COPY README.md ./

# Create non-root user
RUN useradd -m -u 1000 claude && \
    chown -R claude:claude /app

USER claude

# Default command
CMD ["claude-cluster-distributed", "--help"]