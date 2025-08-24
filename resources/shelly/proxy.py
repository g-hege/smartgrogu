# For testing only, requires Python on Windows
import http.server
import socketserver
import urllib.request

class MyProxy(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        url = 'http://172.22.254.92:3000' + self.path
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)

        req = urllib.request.Request(url, data=post_data, headers={'Content-Type': 'application/json', 'X-Api-Key': '12345'}, method='POST')
        try:
            with urllib.request.urlopen(req) as response:
                self.send_response(response.status)
                self.end_headers()
                self.wfile.write(response.read())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))

with socketserver.TCPServer(("192.168.0.147", 3000), MyProxy) as httpd:
    print("Proxy running on 192.168.0.147:3000")
    httpd.serve_forever()