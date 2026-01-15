# Prefect v3 Docker image for flows and workers
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy flow code and deployments
COPY flows/ ./flows/
COPY deployments/ ./deployments/

# Create a non-root user for security (optional but recommended for production)
RUN useradd -m -u 1000 prefect && chown -R prefect:prefect /app
USER prefect

# Default command: start a Prefect worker
# Override with different commands for flow execution or local dev
CMD ["prefect", "worker", "start", "--pool", "default"]
