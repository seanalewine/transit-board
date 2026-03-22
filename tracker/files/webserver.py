#!/usr/bin/env python3
import os
import http.server
import socketserver
import sys

PORT = int(os.environ.get("WEB_SERVER_PORT", 8000))
SERVE_DIR = os.environ.get("SERVE_DIR", "/data")

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SERVE_DIR, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def log_message(self, format, *args):
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

if __name__ == "__main__":
    os.chdir(SERVE_DIR)
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        sys.stderr.write(f"Web server serving {SERVE_DIR} on port {PORT}\n")
        httpd.serve_forever()