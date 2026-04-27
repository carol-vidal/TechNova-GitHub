FROM python:3.12-alpine
WORKDIR /app
COPY server.py .
EXPOSE 5001
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:5001/ || exit 1
CMD ["python", "server.py"]
