#!/usr/bin/env python3

from http.server import HTTPServer, SimpleHTTPRequestHandler
import argparse

class WebAssemblyRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        return super(WebAssemblyRequestHandler, self).end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

parser = argparse.ArgumentParser(
    prog='IBT HTTP Server',
    description='Simple HTTP server for serving WebAssembly with COOP and COEP headers set.'
)

parser.add_argument('-p', '--port', default='8000', type=int, metavar='port')
parser.add_argument('--host', default='0.0.0.0', metavar='address')
args = parser.parse_args()

print("[IBT] Listening on {}:{}".format(args.host, args.port))
httpd = HTTPServer((args.host, args.port), WebAssemblyRequestHandler)
httpd.serve_forever()
