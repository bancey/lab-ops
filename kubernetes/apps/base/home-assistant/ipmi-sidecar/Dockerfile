FROM python:3.12-alpine

# Install ipmitool and required dependencies
RUN apk add --no-cache ipmitool

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Run as non-root user
RUN adduser -D -u 1000 ipmi && \
    chown -R ipmi:ipmi /app
USER ipmi

# Expose API port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health').read()"

# Run the Flask application
CMD ["python", "app.py"]
