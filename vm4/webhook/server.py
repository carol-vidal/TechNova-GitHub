from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from datetime import datetime

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)
        timestamp = datetime.utcnow().isoformat()
        with open('/tmp/technova-alerts.log', 'ab') as f:
            f.write(f"[{timestamp}]\n".encode())
            f.write(body + b'\n\n')
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Webhook listener running')

HTTPServer(('0.0.0.0', 5001), Handler).serve_forever()
