# slim, specific python version for smaller and more secure image
FROM python:3.11-slim

# Set environment variables upfront.
# PYTHONDONTWRITEBYTECODE: prevents python from writing unnecessary .pyc cache files to disk 
# PYTHONUNBUFFERED: stdout/stderr sent directly to the terminal, to ensure logs are real time
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # default BASE_URL, overridden at runtime via helm values
    BASE_URL=http://localhost:8080

# non-root user and group to prevent container escape, and limiting room for actions of compromiser
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

# Run with gunicorn instead of Flask's default server for production-grade process management and stability
# (e.g, worker prefork prevents container restarts (just worker restart), handling SIGTERMs...).
# - default 30s timeout would be okay for this in-memory app.
# - access logs to stdout for visibility in container logs
# - using default one worker since state is in-memory
# - using default sync worker class since it's a simple app and doesn't require async handling and to prevent race conditions with multiple workers accessing shared in-memory state
#
# NOTE ON TIMEOUT & WORKERS:
# - When running locally WITHOUT a reverse proxy (e.g, bare docker), modern browsers like Chrome 
#   keep unfinished TCP connections open/silent (pre-connect/keepalive), causing the sync worker to block on recv(),
#   i.e gunicorn keepalive flag doesnt work as expected since the client is still technically alive,
#   This triggers a 30s gunicorn worker timeout and a subsequent SIGKILL/restart.
# - This expected behavior in a bare container environment will be naturally resolved 
#   in production once the container sits behind an ingress controller / other reverse proxy
#   which properly absorbs and terminates client TCP connections.
CMD ["gunicorn", "--keep-alive", "2", "--bind", "0.0.0.0:8080", "--access-logfile", "-", "src.app:app"]