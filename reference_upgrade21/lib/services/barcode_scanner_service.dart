import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class BarcodeScannerService extends ChangeNotifier {
  BarcodeScannerService._();

  static final BarcodeScannerService instance = BarcodeScannerService._();

  final StreamController<String> _codes = StreamController<String>.broadcast();
  HttpServer? _server;
  List<String> _addresses = const [];
  String _lastCode = '';
  String _lastClient = '';
  String _lastError = '';
  DateTime? _lastScanAt;
  int _scanCount = 0;

  Stream<String> get codes => _codes.stream;
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 8765;
  List<String> get addresses => List.unmodifiable(_addresses);
  String get lastCode => _lastCode;
  String get lastClient => _lastClient;
  String get lastError => _lastError;
  DateTime? get lastScanAt => _lastScanAt;
  int get scanCount => _scanCount;

  String get primaryUrl {
    if (_addresses.isEmpty) return '';
    return 'http://${_addresses.first}:$port';
  }

  String get submitUrlTemplate {
    final url = primaryUrl;
    return url.isEmpty ? '' : '$url/scan?code=BARCODE';
  }

  Future<bool> start({int preferredPort = 8765}) async {
    if (_server != null) return true;
    _lastError = '';

    HttpServer? bound;
    Object? lastBindError;
    for (var candidate = preferredPort; candidate < preferredPort + 10; candidate++) {
      try {
        bound = await HttpServer.bind(
          InternetAddress.anyIPv4,
          candidate,
          shared: true,
        );
        break;
      } catch (error) {
        lastBindError = error;
      }
    }

    if (bound == null) {
      _lastError = 'Could not start phone scanner server: $lastBindError';
      notifyListeners();
      return false;
    }

    _server = bound;
    _addresses = await _localIpv4Addresses();
    if (_addresses.isEmpty) {
      _lastError =
          'Scanner started, but no local Wi-Fi/LAN IPv4 address was found.';
    }
    _serve(bound);
    notifyListeners();
    return true;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _addresses = const [];
    if (server != null) {
      await server.close(force: true);
    }
    notifyListeners();
  }

  void injectCode(String raw, {String client = 'Local test'}) {
    final code = raw.trim();
    if (code.isEmpty) return;
    _lastCode = code;
    _lastClient = client;
    _lastScanAt = DateTime.now();
    _scanCount += 1;
    _lastError = '';
    _codes.add(code);
    notifyListeners();
  }

  void _serve(HttpServer server) {
    unawaited(() async {
      try {
        await for (final request in server) {
          await _handleRequest(request);
        }
      } catch (error) {
        if (_server != null) {
          _lastError = 'Phone scanner server stopped unexpectedly: $error';
          _server = null;
          notifyListeners();
        }
      }
    }());
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _cors(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    if (path == '/' || path == '/scanner') {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_scannerHtml());
      await request.response.close();
      return;
    }

    if (path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'service': 'ProfitGPS Phone Scanner',
          'scanCount': _scanCount,
        }),
      );
      await request.response.close();
      return;
    }

    if (path == '/return') {
      final code = (request.uri.queryParameters['code'] ?? '').trim();
      if (code.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('No barcode returned');
        await request.response.close();
        return;
      }

      final client = request.connectionInfo?.remoteAddress.address ?? 'Phone';
      injectCode(code, client: 'Binary Eye • $client');
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        '/scanner?sent=${Uri.encodeQueryComponent(code)}',
      );
      await request.response.close();
      return;
    }

    if (path == '/scan') {
      var code = request.uri.queryParameters['code'] ?? '';
      if (code.trim().isEmpty && request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        if (body.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(body);
            if (decoded is Map<String, dynamic>) {
              code = decoded['code']?.toString() ?? '';
            }
          } catch (_) {
            final form = Uri.splitQueryString(body);
            code = form['code'] ?? body;
          }
        }
      }

      if (code.trim().isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'ok': false, 'error': 'No barcode'}));
        await request.response.close();
        return;
      }

      final client = request.connectionInfo?.remoteAddress.address ?? 'Phone';
      injectCode(code, client: client);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'ok': true, 'code': code.trim()}));
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not found');
    await request.response.close();
  }

  void _cors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
  }

  Future<List<String>> _localIpv4Addresses() async {
    final values = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final network in interfaces) {
        for (final address in network.addresses) {
          final value = address.address;
          if (value.startsWith('169.254.')) continue;
          values.add(value);
        }
      }
    } catch (error) {
      _lastError = 'Could not read local network address: $error';
    }

    final list = values.toList();
    list.sort((a, b) {
      int score(String value) {
        if (value.startsWith('192.168.')) return 0;
        if (value.startsWith('10.')) return 1;
        if (value.startsWith('172.')) return 2;
        return 3;
      }

      final scoreCompare = score(a).compareTo(score(b));
      return scoreCompare != 0 ? scoreCompare : a.compareTo(b);
    });
    return list;
  }

  String _scannerHtml() => r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>ProfitGPS Phone Scanner</title>
<style>
:root{color-scheme:dark;font-family:Inter,system-ui,-apple-system,Segoe UI,sans-serif;background:#07111f;color:#f8fafc}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at top,#13243a 0,#07111f 55%);min-height:100vh;padding:18px}
.wrap{max-width:560px;margin:0 auto}.brand{font-size:28px;font-weight:900}.brand span{color:#ff5a36}.sub{color:#9fb0c5;margin:6px 0 18px}
.card{background:#0d1828;border:1px solid #263850;border-radius:20px;padding:18px;box-shadow:0 16px 40px #0006;margin-bottom:14px}
.good{background:#0d2a22;border-color:#1f6f54}.title{font-size:19px;font-weight:850;margin-bottom:8px}.muted{color:#9fb0c5;font-size:14px;line-height:1.45}
button,.pick{width:100%;border:0;border-radius:14px;padding:15px 14px;font-size:16px;font-weight:850;cursor:pointer}.primary{background:#ff5a36;color:white}.blue{background:#1664ff;color:white}.secondary{background:#17253a;color:#e8eef8;border:1px solid #30445e;margin-top:9px}
input[type=text]{width:100%;background:#091322;border:1px solid #31455f;color:#fff;border-radius:14px;padding:15px;font-size:18px;margin:9px 0 10px}
input[type=file]{position:absolute;left:-9999px}.pick{display:block;text-align:center;background:#1664ff;color:white;margin-top:10px}.status{margin-top:12px;padding:12px;border-radius:12px;background:#08121f;color:#9fb0c5;min-height:44px}
.code{font-size:24px;font-weight:900;color:#71f2b1;word-break:break-all}.steps{padding-left:19px;color:#c8d4e3}.steps li{margin:8px 0}.tiny{font-size:12px;color:#75889f;margin-top:9px}
#reader{width:100%;overflow:hidden;border-radius:16px;margin-top:12px;background:#050b13}#reader video{border-radius:14px}.row{display:flex;gap:9px}.row>*{flex:1}
</style>
<script src="https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js"></script>
</head>
<body>
<div class="wrap">
  <div class="brand">Profit<span>GPS</span> Scanner</div>
  <div class="sub">Phone camera → Windows ProfitGPS over the same Wi-Fi.</div>

  <div class="card good">
    <div class="title">Connected to ProfitGPS</div>
    <div class="muted">Keep a scanner field open in Billing or Purchases. A successful scan is sent directly to that field.</div>
  </div>

  <div class="card">
    <div class="title">Real live scanner — Android</div>
    <div class="muted">Recommended when Chrome blocks camera access on this local HTTP page. ProfitGPS opens the free Binary Eye scanner app, then the scanned barcode is returned directly to ProfitGPS.</div>
    <button class="blue" onclick="openBinaryEye()">Open real barcode scanner</button>
    <a class="pick secondary" style="text-decoration:none" href="https://play.google.com/store/apps/details?id=de.markusfisch.android.binaryeye" target="_blank">Install Binary Eye if needed</a>
    <div id="nativeStatus" class="status">Ready.</div>
    <div class="tiny">After scanning, Binary Eye returns to this page and sends the barcode to the active ProfitGPS scanner field.</div>
  </div>

  <div class="card">
    <div class="title">Photo barcode scanner</div>
    <div class="muted">Take a close, sharp photo. Keep the full barcode visible and avoid glare.</div>
    <label class="pick" for="barcodePhoto">📷 Take barcode photo</label>
    <input id="barcodePhoto" type="file" accept="image/*" capture="environment">
    <div id="photoStatus" class="status">Ready for a barcode photo.</div>
    <div class="tiny">ProfitGPS first tries the phone/browser barcode detector when available, then falls back to the scanner library.</div>
  </div>

  <div class="card">
    <div class="title">Manual / scanner-app test</div>
    <input id="manualCode" type="text" inputmode="numeric" autocomplete="off" placeholder="Barcode number">
    <button class="primary" onclick="sendManual()">Send barcode to ProfitGPS</button>
    <div id="sendStatus" class="status">Waiting.</div>
  </div>

  <div class="card">
    <div class="title">Test flow</div>
    <ol class="steps">
      <li>Open Scan / Code in ProfitGPS Billing or the scanner icon in New Purchase.</li>
      <li>Scan a real product here.</li>
      <li>Existing inventory product → ProfitGPS selects/adds it.</li>
      <li>Unknown product → ProfitGPS tries an online product-catalog lookup and keeps it out of billing until it is added to inventory.</li>
    </ol>
  </div>
</div>
<script>
let liveScanner=null;
let sending=false;
let lastSent='';
let lastSentAt=0;

async function sendCode(code){
  code=(code||'').trim();
  if(!code)return;
  const now=Date.now();
  if(sending || (code===lastSent && now-lastSentAt<1800))return;
  sending=true;
  const target=document.getElementById('sendStatus');
  target.textContent='Sending '+code+'…';
  try{
    const r=await fetch('/scan?code='+encodeURIComponent(code),{cache:'no-store'});
    const j=await r.json();
    if(!j.ok)throw new Error(j.error||'Send failed');
    lastSent=code;lastSentAt=Date.now();
    target.innerHTML='<div class="code">✓ '+escapeHtml(code)+'</div>Sent to ProfitGPS';
    if(navigator.vibrate)navigator.vibrate(80);
  }catch(e){target.textContent='Could not send: '+e;}
  finally{sending=false;}
}
function escapeHtml(value){return String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function sendManual(){sendCode(document.getElementById('manualCode').value);}
document.getElementById('manualCode').addEventListener('keydown',e=>{if(e.key==='Enter')sendManual();});

function openBinaryEye(){
  const status=document.getElementById('nativeStatus');
  const callback=location.origin+'/return?code={RESULT}';
  const link='binaryeye://scan?ret='+encodeURIComponent(callback);
  status.textContent='Opening Binary Eye…';
  window.location.href=link;
  setTimeout(()=>{
    status.innerHTML='If the scanner did not open, install Binary Eye once using the button above, then try again.';
  },1400);
}

const returnedCode=new URLSearchParams(location.search).get('sent');
if(returnedCode){
  const target=document.getElementById('sendStatus');
  target.innerHTML='<div class="code">✓ '+escapeHtml(returnedCode)+'</div>Sent to ProfitGPS';
  const nativeStatus=document.getElementById('nativeStatus');
  if(nativeStatus) nativeStatus.innerHTML='<div class="code">✓ '+escapeHtml(returnedCode)+'</div>Native scan returned successfully.';
}

async function startLiveScanner(){
  const status=document.getElementById('liveStatus');
  if(typeof Html5Qrcode==='undefined'){
    status.textContent='Live scanner library could not load. Check phone internet once, then reload this page.';
    return;
  }
  if(!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia){
    status.textContent='This browser blocks live camera access on the local scanner address. Use Take barcode photo below.';
    return;
  }
  if(liveScanner)return;
  const reader=document.getElementById('reader');
  reader.style.display='block';
  status.textContent='Starting rear camera…';
  try{
    liveScanner=new Html5Qrcode('reader');
    await liveScanner.start(
      {facingMode:'environment'},
      {fps:12,qrbox:{width:300,height:160},aspectRatio:1.777778},
      async decoded=>{
        status.innerHTML='<div class="code">'+escapeHtml(decoded)+'</div>Barcode detected.';
        await sendCode(decoded);
      },
      ()=>{}
    );
    document.getElementById('startLive').disabled=true;
    document.getElementById('stopLive').disabled=false;
    status.textContent='Camera running. Hold the barcode steady inside the scan area.';
  }catch(e){
    liveScanner=null;
    reader.style.display='none';
    status.textContent='Could not start live camera: '+e+'. Use Take barcode photo below.';
  }
}

async function stopLiveScanner(){
  const status=document.getElementById('liveStatus');
  const reader=document.getElementById('reader');
  if(liveScanner){
    try{await liveScanner.stop();}catch(_){ }
    try{liveScanner.clear();}catch(_){ }
  }
  liveScanner=null;
  reader.style.display='none';
  document.getElementById('startLive').disabled=false;
  document.getElementById('stopLive').disabled=true;
  status.textContent='Live scanner stopped.';
}

async function detectWithNative(file){
  if(!('BarcodeDetector' in window) || typeof createImageBitmap!=='function')return '';
  try{
    const formats=['ean_13','ean_8','upc_a','upc_e','code_128','code_39','itf'];
    const detector=new BarcodeDetector({formats});
    const bitmap=await createImageBitmap(file);
    const results=await detector.detect(bitmap);
    if(bitmap.close)bitmap.close();
    return results&&results.length?results[0].rawValue||'':'';
  }catch(_){return '';}
}

async function detectWithHtml5(file){
  if(typeof Html5Qrcode==='undefined')return '';
  const temp=document.createElement('div');
  temp.id='fileReader_'+Date.now();
  temp.style.display='none';
  document.body.appendChild(temp);
  const reader=new Html5Qrcode(temp.id);
  try{return await reader.scanFile(file,true);}catch(_){return '';}
  finally{try{reader.clear();}catch(_){ }temp.remove();}
}

document.getElementById('barcodePhoto').addEventListener('change',async e=>{
  const file=e.target.files&&e.target.files[0];
  const status=document.getElementById('photoStatus');
  if(!file)return;
  status.textContent='Reading barcode from photo…';
  let text=await detectWithNative(file);
  if(!text)text=await detectWithHtml5(file);
  if(text){
    status.innerHTML='<div class="code">'+escapeHtml(text)+'</div>Barcode detected.';
    await sendCode(text);
  }else{
    status.textContent='Barcode not detected. Retake closer, keep all bars visible, avoid glare, and make sure the barcode is sharp.';
  }
  e.target.value='';
});
</script>
</body>
</html>''';

}
