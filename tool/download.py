"""Download large public build tools with validated HTTP range requests."""
import concurrent.futures
import os
import sys
import urllib.request

url, destination = sys.argv[1:3]
with urllib.request.urlopen(urllib.request.Request(url, method='HEAD'), timeout=30) as response:
    size = int(response.headers['Content-Length'])
chunk_size = 4 * 1024 * 1024
parts = [(start, min(start + chunk_size, size) - 1) for start in range(0, size, chunk_size)]
os.makedirs(os.path.dirname(os.path.abspath(destination)), exist_ok=True)
with open(destination, 'wb') as output:
    output.truncate(size)

def fetch(part):
    start, end = part
    for attempt in range(4):
        try:
            request = urllib.request.Request(url, headers={'Range': f'bytes={start}-{end}'})
            with urllib.request.urlopen(request, timeout=90) as response:
                if response.status != 206 or not response.headers.get('Content-Range', '').startswith(f'bytes {start}-{end}/'):
                    raise ValueError('Server did not honor byte range')
                data = response.read()
            if len(data) != end - start + 1:
                raise ValueError('Incomplete byte range')
            with open(destination, 'r+b') as output:
                output.seek(start)
                output.write(data)
            return len(data)
        except Exception:
            if attempt == 3:
                raise

with concurrent.futures.ThreadPoolExecutor(max_workers=12) as executor:
    total = 0
    for completed in executor.map(fetch, parts):
        total += completed
        print(f'{total // 1048576}/{size // 1048576} MiB', flush=True)
