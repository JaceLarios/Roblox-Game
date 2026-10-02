from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
import os,json
P=Path(__file__).resolve().parent
os.chdir(P.parent)
class Handler(SimpleHTTPRequestHandler):
 chunks={}
 def do_POST(self):
  name=self.path.removeprefix('/capture/')
  if self.path!='/capture/'+name or '/'in name or '\\'in name or not name.endswith('.json'):
   self.send_error(400);return
  data=self.rfile.read(int(self.headers['Content-Length']));parsed=json.loads(data)
  if isinstance(parsed,dict) and 'chunk' in parsed:
   bucket=self.chunks.setdefault(name,{})
   bucket[parsed['index']]=parsed['chunk']
   if len(bucket)==parsed['total']:
    data=''.join(bucket[i]for i in range(1,parsed['total']+1)).encode();json.loads(data);del self.chunks[name]
   else:data=None
  if data is not None:
   out=P/'toro-live';out.mkdir(exist_ok=True);(out/name).write_bytes(data)
  self.send_response(200);self.end_headers();self.wfile.write(b'OK')
ThreadingHTTPServer(('127.0.0.1',18769),Handler).serve_forever()
