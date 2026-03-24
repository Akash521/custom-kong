from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class SimpleAPI(BaseHTTPRequestHandler):
    def do_GET(self):
        print(f"GET request: {self.path}")
        
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode())
            
        elif self.path.startswith('/users'):
            users = [
                {"id": 1, "name": "Alice"},
                {"id": 2, "name": "Bob"},
                {"id": 3, "name": "Charlie"}
            ]
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(users).encode())
            
        elif self.path == '/info':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "service": "Local Test API",
                "version": "1.0.0",
                "endpoints": ["/health", "/users", "/info"]
            }).encode())
            
        else:
            self.send_response(404)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode())

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        self.send_response(201)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {"received": json.loads(post_data), "status": "created"}
        self.wfile.write(json.dumps(response).encode())

    def log_message(self, format, *args):
        # Suppress log messages
        pass

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 5020), SimpleAPI)
    print("Local API server running on http://localhost:5000")
    print("Endpoints: /health, /users, /info")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()
