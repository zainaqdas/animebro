# AnimePahe + Kwik.cx Architecture: Complete Implementation Guide

**Research Reference Document** — Infrastructure patterns study

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Phase 1: Infrastructure & Domain Setup](#2-phase-1-infrastructure--domain-setup)
3. [Phase 2: Video Host (Kwik.cx Equivalent)](#3-phase-2-video-host-kwikcx-equivalent)
4. [Phase 3: Encoding Pipeline](#4-phase-3-encoding-pipeline)
5. [Phase 4: Front-end Portal (AnimePahe Equivalent)](#5-phase-4-front-end-portal-animepahe-equivalent)
6. [Phase 5: Security & Hardening](#6-phase-5-security--hardening)
7. [Phase 6: Operations & Maintenance](#7-phase-6-operations--maintenance)
8. [Appendix: Setup Script Reference](#8-appendix-setup-script-reference)

---

## 1. System Architecture Overview

### High-Level Design

```
                    ┌──────────────────────────────────────────────────┐
                    │                  Cloudflare                       │
                    │  (CDN, DDoS Protection, Origin IP Masking, WAF)  │
                    │  Nameservers: adam.ns.cloudflare.com              │
                    │               marissa.ns.cloudflare.com           │
                    └──────────────┬─────────────────────┬─────────────┘
                                   │                     │
                          ┌────────▼────────┐    ┌───────▼──────────┐
                          │  Front-end      │    │   Video Host     │
                          │  portal.com     │    │   video-host.com │
                          │  (AnimePahe)    │    │   (Kwik.cx)      │
                          │  Laravel PHP    │    │   Laravel PHP     │
                          │  MySQL/Redis    │    │   Nginx X-Accel   │
                          │  Cloudflare     │    │   File Storage    │
                          └────────┬────────┘    └───────┬──────────┘
                                   │                     │
                                   │     (Referer auth)   │
                                   └──────────┬──────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │   Encoding Pipeline  │
                                   │   (Offline/Internal) │
                                   │   x265 HEVC 10-bit   │
                                   │   VapourSynth+FFmpeg │
                                   └─────────────────────┘
```

### Two-Tier Separation Principle

| Tier | Domain | Role | Legal Argument |
|------|--------|------|---------------|
| **Front-end** | `portal.com` | UI, catalog, search | "We don't host videos, just links" |
| **Video Host** | `video-host.com` | Stores and streams files | Hidden behind Cloudflare + offshore host |

**Key insight:** Even though both are owned by the same entity, they appear legally separate. The front-end can credibly claim they're just a directory service. The video host relies on Cloudflare + offshore hosting to resist takedowns.

---

## 2. Phase 1: Infrastructure & Domain Setup

### 2.1 Domain Registration Strategy

Register **two separate domains** with different registrars:

| Domain | Purpose | Recommended TLD | Registrar |
|--------|---------|-----------------|-----------|
| `portal-domain.com` | Front-end website | `.com`, `.net`, `.to` | Namecheap / Cloudflare Registrar |
| `video-host-domain.com` | Video hosting | `.cx`, `.si`, `.ru`, `.pw` | CentralNic / offshore registrar |

**TLD selection guide:**
- `.cx` (Christmas Island) — Registry cxDA is notoriously slow to respond to copyright complaints
- `.si` (Slovenia) — Weak IP enforcement, cheap
- `.pw` (Palau) — Used by many pirate sites
- `.ru` (Russia) — Nearly impossible to enforce foreign copyright

**Do not** register both domains with the same registrar or same WHOIS contact info.

### 2.2 Cloudflare Setup

Create two Cloudflare accounts (or use the same account with different organizations):

1. Add both domains to Cloudflare
2. Change nameservers to Cloudflare's
3. **Enable proxied (orange cloud)** on all DNS records
4. Set SSL/TLS mode to **Full (Strict)**
5. Generate **Origin CA certificates** for each domain
6. Set up **WAF rules** to block non-Cloudflare traffic
7. Enable **Under Attack Mode** for the video host domain

### 2.3 Server Provisioning

**Hardware requirements per origin server:**

| Component | Video Host Server | Front-end Server | Encoding Server |
|-----------|------------------|------------------|-----------------|
| CPU | 8+ cores | 4+ cores | 32+ cores (AMD EPYC/Threadripper) |
| RAM | 32+ GB | 8+ GB | 64+ GB |
| Storage | 40TB+ HDD/SSD (video files) | 100GB SSD (app + DB) | 4TB NVMe (scratch) |
| Bandwidth | 10 Gbps unmetered | 1 Gbps | 1 Gbps |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |

**Hosting provider options (for the video host origin):**

| Provider | Location | DMCA stance | Bandwidth | Monthly cost |
|----------|----------|-------------|-----------|-------------|
| Shinjiru | Malaysia | Ignored | 100TB+ on 10Gbps | $200-500 |
| AlexHost | Moldova | Ignored | Unmetered 10Gbps | $150-400 |
| FlokiNET | Iceland/Romania | Ignored | Unmetered | $300-800 |
| Private colo | Vietnam/Cambodia | Unknown | Custom | $500-2000 |

**Do NOT** use AWS, Google Cloud, or Azure — they will terminate your account on first DMCA notice.

---

## 3. Phase 2: Video Host (Kwik.cx Equivalent)

### 3.1 Server Stack

```
Ubuntu 24.04 LTS
├── Nginx (reverse proxy, X-Accel, secure links)
├── PHP 8.3 + PHP-FPM
├── Laravel 11 (application framework)
├── Redis (session caching, rate limiting)
└── MySQL 8 / PostgreSQL 16 (user/session DB)
```

### 3.2 Nginx Configuration

**Main config (`/etc/nginx/sites-available/video-host`):**

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name video-host-domain.com;

    # Cloudflare Origin CA certificate
    ssl_certificate /etc/ssl/certs/origin-cert.pem;
    ssl_certificate_key /etc/ssl/private/origin-key.pem;
    ssl_client_certificate /etc/ssl/certs/cloudflare-ca.pem;
    ssl_verify_client on;

    root /var/www/video-host/public;

    # Laravel entry point
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Protected video files (only accessible via X-Accel from Laravel)
    location /protected-videos/ {
        internal;
        alias /var/www/video-host/storage/app/videos/;
    }

    # HLS streaming segments
    location /protected-hls/ {
        internal;
        alias /var/www/video-host/storage/app/hls/;
        add_header Access-Control-Allow-Origin "https://portal-domain.com";
    }

    # Auth endpoint for video access
    location /api/stream/ {
        try_files $uri /index.php?$query_string;
    }

    # Block direct access to storage
    location ~ /\.(env|git|storage) {
        deny all;
        return 404;
    }

    access_log /var/log/nginx/video-host-access.log;
    error_log /var/log/nginx/video-host-error.log;
}
```

### 3.3 Laravel Video Host Application

**Directory structure:**
```
/var/www/video-host/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── VideoController.php
│   │   │   ├── AuthController.php
│   │   │   └── EmbedController.php
│   │   └── Middleware/
│   │       └── RefererValidation.php
│   ├── Models/
│   │   ├── Video.php
│   │   └── AccessToken.php
│   └── Services/
│       ├── VideoStreamService.php
│       └── TokenService.php
├── storage/
│   └── app/
│       └── videos/    (symlinked to actual storage)
└── config/
    └── stream.php
```

**Core controller logic for video streaming:**

```php
<?php
// app/Http/Controllers/VideoController.php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Video;
use App\Services\VideoStreamService;

class VideoController extends Controller
{
    public function stream(Request $request, string $slug)
    {
        // 1. Validate access token
        $token = $request->query('token');
        if (!$this->validateToken($token, $slug)) {
            abort(403, 'Invalid or expired token');
        }

        // 2. Find the video file
        $video = Video::where('slug', $slug)->firstOrFail();

        // 3. Generate X-Accel redirect to Nginx
        $filePath = $video->getStoragePath();

        return response('', 200)
            ->header('X-Accel-Redirect', '/protected-videos/' . $filePath)
            ->header('Content-Type', $video->mime_type)
            ->header('Content-Disposition', 'inline')
            ->header('X-Accel-Buffering', 'yes')
            ->header('X-Accel-Expires', '86400');
    }

    public function streamHls(Request $request, string $slug)
    {
        // Validate token (same as above)
        $token = $request->query('token');
        if (!$this->validateToken($token, $slug)) {
            abort(403, 'Invalid or expired token');
        }

        $video = Video::where('slug', $slug)->firstOrFail();

        return response('', 200)
            ->header('X-Accel-Redirect', '/protected-hls/' . $video->hls_path . '/playlist.m3u8')
            ->header('Content-Type', 'application/vnd.apple.mpegurl');
    }

    // Referer validation middleware for embed endpoint
    public function embed(Request $request, string $slug)
    {
        // This endpoint is called when the front-end embeds a video
        // It generates a short-lived token and renders the player HTML
        $token = $this->generateToken($slug, 3600); // 1 hour expiry

        $video = Video::where('slug', $slug)->firstOrFail();

        return view('video-embed', [
            'video' => $video,
            'token' => $token,
            'host' => 'https://video-host-domain.com'
        ]);
    }

    private function validateToken(string $token, string $slug): bool
    {
        // HMAC-based token validation
        $expected = hash_hmac('sha256', $slug . '|' . floor(time() / 3600), config('stream.secret'));
        return hash_equals($expected, $token);
    }

    private function generateToken(string $slug, int $ttl): string
    {
        $expiry = time() + $ttl;
        $data = $slug . '|' . $expiry;
        $signature = hash_hmac('sha256', $data, config('stream.secret'));
        return base64_encode($data . '|' . $signature);
    }
}
```

**Referer validation middleware:**

```php
<?php
// app/Http/Middleware/RefererValidation.php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class RefererValidation
{
    private array $allowedHosts = [
        'portal-domain.com',
        'www.portal-domain.com',
        // Add backup/mirror domains
    ];

    public function handle(Request $request, Closure $next)
    {
        // Bypass for API endpoints with valid tokens
        if ($request->has('token') && $this->validateToken($request->token)) {
            return $next($request);
        }

        $referer = $request->headers->get('referer');
        if (!$referer) {
            abort(403, 'Direct access not allowed');
        }

        $host = parse_url($referer, PHP_URL_HOST);
        if (!in_array($host, $this->allowedHosts)) {
            abort(403, 'Unauthorized referer');
        }

        return $next($request);
    }

    private function validateToken(string $token): bool
    {
        // HMAC validation
        $parts = explode('|', base64_decode($token));
        if (count($parts) !== 3) return false;

        [$slug, $expiry, $signature] = $parts;
        if (time() > (int)$expiry) return false;

        $expected = hash_hmac('sha256', $slug . '|' . $expiry, config('stream.secret'));
        return hash_equals($expected, $signature);
    }
}
```

### 3.4 Video Serving Architecture

```
User's Browser
    │
    ▼
Front-end Portal (portal-domain.com)
    │  Embed page with iframe pointing to video-host-domain.com/embed/{slug}
    ▼
Video Host (video-host-domain.com)
    │  Referer check: Is referer portal-domain.com?
    │  Yes → Generate short-lived token, render player HTML
    │  No  → 403 Forbidden
    ▼
Browser loads player → Player requests stream URL:
    /api/stream/{slug}?token=abc123
    │
    ▼
Laravel validates token → Nginx X-Accel-Redirect
    │
    ▼
Nginx serves video file from /protected-videos/
    (internal location - not directly accessible)
```

### 3.5 Database Schema (Video Host)

```sql
-- Videos table
CREATE TABLE videos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(64) UNIQUE NOT NULL,         -- e.g., "naruto-ep1-720p"
    title VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    storage_path VARCHAR(512) NOT NULL,        -- relative path in storage
    hls_path VARCHAR(512) NULL,                -- HLS variant if available
    file_size BIGINT UNSIGNED NOT NULL,         -- in bytes
    mime_type VARCHAR(64) NOT NULL DEFAULT 'video/mp4',
    duration_seconds INT UNSIGNED NULL,
    resolution VARCHAR(16) NULL,               -- "1920x1080"
    codec VARCHAR(32) NULL,                    -- "hevc", "h264"
    crc_hash VARCHAR(64) NOT NULL,             -- file integrity check
    upload_status ENUM('pending','processing','ready','failed') DEFAULT 'pending',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_status (upload_status),
    INDEX idx_active (is_active)
);

-- Access tokens (ephemeral)
CREATE TABLE access_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    video_id BIGINT UNSIGNED NOT NULL,
    token_hash VARCHAR(64) NOT NULL,           -- sha256 of token for lookup
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE,
    INDEX idx_token (token_hash),
    INDEX idx_expires (expires_at)
);

-- Access logs (for monitoring)
CREATE TABLE access_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    video_id BIGINT UNSIGNED NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    referer VARCHAR(512),
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE,
    INDEX idx_video (video_id),
    INDEX idx_ip (ip_address),
    INDEX idx_accessed (accessed_at)
);
```

---

## 4. Phase 3: Encoding Pipeline

### 4.1 Toolchain Installation

```bash
# Install FFmpeg with x265 support
sudo apt update
sudo apt install -y ffmpeg x265 libx265-dev vapoursynth \
    python3-pip python3-numpy python3-opencv

# Install vapoursynth plugins
pip3 install vs-placebo vs-tools

# Verify x265 support
ffmpeg -encoders 2>/dev/null | grep x265
```

### 4.2 Encoding Script

```python
#!/usr/bin/env python3
"""
AnimePahe-style encoding pipeline
Optimized for high compression on animated content
"""
import os
import sys
import json
import subprocess
import argparse
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor

# Encoding profiles
PROFILES = {
    "1080p": {
        "video_codec": "libx265",
        "video_params": [
            "-crf", "22",
            "-preset", "slow",
            "-tune", "animation",
            "-pix_fmt", "yuv420p10le",  # 10-bit color
            "-x265-params", (
                "profile=main10:"
                "level=5.1:"
                "keyint=240:"
                "min-keyint=24:"
                "bframes=8:"
                "no-sao=1:"
                "aq-mode=3:"
                "aq-strength=0.8:"
                "deblock=-1,-1:"
                "no-open-gop=1:"
                "weightb=1:"
                "merange=57:"
                "subme=5:"
                "no-strong-intra-smoothing=1"
            )
        ],
        "audio_codec": "libopus",
        "audio_params": ["-b:a", "96k"],
        "resolution": "1920:1080"
    },
    "720p": {
        "video_codec": "libx265",
        "video_params": [
            "-crf", "23",
            "-preset", "slow",
            "-tune", "animation",
            "-pix_fmt", "yuv420p10le",
            "-x265-params", (
                "profile=main10:"
                "keyint=240:"
                "min-keyint=24:"
                "bframes=8:"
                "no-sao=1:"
                "aq-mode=3:"
                "aq-strength=0.8:"
                "deblock=-1,-1:"
                "no-open-gop=1"
            )
        ],
        "audio_codec": "libopus",
        "audio_params": ["-b:a", "80k"],
        "resolution": "1280:720"
    },
    "480p": {
        "video_codec": "libx265",
        "video_params": [
            "-crf", "24",
            "-preset", "medium",
            "-tune", "animation",
            "-pix_fmt", "yuv420p10le",
            "-x265-params", (
                "profile=main10:"
                "keyint=240:"
                "no-sao=1:"
                "aq-mode=3:"
                "aq-strength=0.8"
            )
        ],
        "audio_codec": "libopus",
        "audio_params": ["-b:a", "64k"],
        "resolution": "854:480"
    }
}


def pre_filter(input_path: str, temp_dir: str) -> str:
    """
    Apply pre-filtering using VapourSynth to remove noise/grain
    This makes the video much easier to compress, reducing file size
    """
    filtered_path = os.path.join(temp_dir, "filtered.mkv")

    # Simple FFmpeg-based filtering (VapourSynth would be used for advanced)
    filter_cmd = [
        "ffmpeg", "-i", input_path,
        "-vf", "hqdn3d=1.5:1:1.5:1,fps=24000/1001",  # Denoise + frame rate normalization
        "-c:v", "libx265",
        "-preset", "fast",
        "-crf", "18",
        "-pix_fmt", "yuv420p10le",
        "-an",  # Drop audio during filtering pass
        "-y", filtered_path
    ]

    print(f"[FILTER] Pre-processing: {input_path}")
    subprocess.run(filter_cmd, check=True, capture_output=True)
    return filtered_path


def encode_video(input_path: str, output_path: str, profile: str, temp_dir: str):
    """Encode a single video file using the specified profile"""
    if profile not in PROFILES:
        raise ValueError(f"Unknown profile: {profile}")

    config = PROFILES[profile]

    # Step 1: Pre-filter
    filtered = pre_filter(input_path, temp_dir)

    # Step 2: Main encode
    print(f"[ENCODE] Encoding to {profile}...")
    encode_cmd = [
        "ffmpeg", "-i", filtered,
        "-c:v", config["video_codec"],
    ] + config["video_params"] + [
        "-c:a", config["audio_codec"],
    ] + config["audio_params"] + [
        "-vf", f"scale={config['resolution']}:flags=lanczos",
        "-movflags", "+faststart",  # Web-optimized MP4
        "-y", output_path
    ]

    subprocess.run(encode_cmd, check=True)

    # Step 3: Generate checksum
    output_size = os.path.getsize(output_path)
    print(f"[DONE] {output_path} ({output_size / 1024 / 1024:.1f} MB)")

    return output_path


def batch_encode(input_dir: str, output_dir: str, profile: str = "720p", parallel: int = 1):
    """Batch encode all video files in a directory"""
    input_dir = Path(input_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    temp_dir = output_dir / "_temp"
    temp_dir.mkdir(exist_ok=True)

    video_files = list(input_dir.glob("*.mkv")) + list(input_dir.glob("*.mp4"))
    video_files.sort()

    if not video_files:
        print(f"No video files found in {input_dir}")
        return

    print(f"Found {len(video_files)} files to encode")

    with ProcessPoolExecutor(max_workers=parallel) as executor:
        futures = []
        for video_file in video_files:
            output_file = output_dir / f"{video_file.stem}.mp4"
            if output_file.exists():
                print(f"Skipping {video_file.name} (already encoded)")
                continue

            futures.append(executor.submit(
                encode_video,
                str(video_file),
                str(output_file),
                profile,
                str(temp_dir)
            ))

        for future in futures:
            try:
                future.result()
            except Exception as e:
                print(f"Encoding failed: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Anime encoding pipeline")
    parser.add_argument("input", help="Input file or directory")
    parser.add_argument("-o", "--output", default="./encoded", help="Output directory")
    parser.add_argument("-p", "--profile", default="720p", choices=PROFILES.keys())
    parser.add_argument("--parallel", type=int, default=1, help="Parallel encodings")

    args = parser.parse_args()

    if os.path.isdir(args.input):
        batch_encode(args.input, args.output, args.profile, args.parallel)
    else:
        os.makedirs(args.output, exist_ok=True)
        temp = Path(args.output) / "_temp"
        temp.mkdir(exist_ok=True)
        output = os.path.join(args.output, Path(args.input).stem + ".mp4")
        encode_video(args.input, output, args.profile, str(temp))
```

### 4.3 Upload Script (Encoding Server → Video Host)

```python
#!/usr/bin/env python3
"""
Upload encoded videos to the video host server
Uses SCP/rsync or API-based upload
"""
import os
import sys
import json
import hashlib
import subprocess
import requests
import argparse
from pathlib import Path

def compute_checksum(filepath: str) -> str:
    """Compute SHA-256 checksum for integrity verification"""
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            sha256.update(chunk)
    return sha256.hexdigest()

def upload_via_rsync(local_file: str, remote_host: str, remote_path: str):
    """Upload via rsync over SSH (for bulk/internal uploads)"""
    cmd = [
        "rsync", "-avzP",
        "--progress",
        local_file,
        f"root@{remote_host}:{remote_path}"
    ]
    subprocess.run(cmd, check=True)

def upload_via_api(local_file: str, api_url: str, api_key: str):
    """Upload via HTTP API (for automated pipelines)"""
    checksum = compute_checksum(local_file)

    with open(local_file, 'rb') as f:
        response = requests.post(
            f"{api_url}/api/upload",
            files={'video': f},
            data={'checksum': checksum},
            headers={'Authorization': f'Bearer {api_key}'}
        )

    if response.status_code == 200:
        result = response.json()
        print(f"Uploaded: {result['slug']} ({result['file_size']} bytes)")
        return result
    else:
        print(f"Upload failed: {response.status_code} - {response.text}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Upload encoded videos")
    parser.add_argument("source", help="Source file or directory")
    parser.add_argument("--mode", choices=['rsync', 'api'], default='rsync')
    parser.add_argument("--remote", default="root@video-host-domain.com")
    parser.add_argument("--remote-path", default="/var/www/video-host/storage/app/videos/")
    parser.add_argument("--api-url", help="API endpoint URL")
    parser.add_argument("--api-key", help="API key for upload")

    args = parser.parse_args()

    if os.path.isdir(args.source):
        files = sorted(Path(args.source).glob("*.mp4"))
    else:
        files = [Path(args.source)]

    for filepath in files:
        print(f"Uploading: {filepath}")

        if args.mode == 'rsync':
            upload_via_rsync(str(filepath), args.remote, args.remote_path)
        elif args.mode == 'api':
            upload_via_api(str(filepath), args.api_url, args.api_key)

    print("Upload complete!")

if __name__ == "__main__":
    main()
```

---

## 5. Phase 4: Front-end Portal (AnimePahe Equivalent)

### 5.1 Laravel Application

```bash
# Create Laravel project
composer create-project laravel/laravel portal
cd portal

# Install required packages
composer require laravel/scout           # Full-text search
composer require laravel/sanctum         # API tokens
composer require predis/predis           # Redis
composer require spatie/laravel-medialibrary  # Thumbnails/images

# Install Node.js dependencies for frontend
npm install
npm install -D tailwindcss @tailwindcss/forms
```

### 5.2 Database Schema (Portal)

```sql
-- Anime series
CREATE TABLE anime_series (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(128) UNIQUE NOT NULL,
    synopsis TEXT,
    poster_url VARCHAR(512),
    banner_url VARCHAR(512),
    season VARCHAR(16),                    -- "Spring 2025"
    year YEAR,
    status ENUM('ongoing','completed','upcoming') DEFAULT 'ongoing',
    session_id VARCHAR(64) UNIQUE NOT NULL, -- AnimePahe-style session ID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FULLTEXT INDEX ft_search (title, synopsis)
);

-- Episodes
CREATE TABLE episodes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    anime_id BIGINT UNSIGNED NOT NULL,
    episode_number INT UNSIGNED NOT NULL,
    title VARCHAR(255),
    slug VARCHAR(128) UNIQUE NOT NULL,     -- "naruto-ep-1"
    session_id VARCHAR(64) NOT NULL,        -- per-episode session ID
    video_slug VARCHAR(64) NOT NULL,        -- references video host slug
    video_resolution VARCHAR(16) DEFAULT '720p',
    duration_seconds INT UNSIGNED,
    air_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (anime_id) REFERENCES anime_series(id) ON DELETE CASCADE,
    INDEX idx_anime_ep (anime_id, episode_number),
    INDEX idx_video (video_slug),
    INDEX idx_active (is_active)
);

-- Genre tags
CREATE TABLE genres (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) UNIQUE NOT NULL,
    slug VARCHAR(64) UNIQUE NOT NULL
);

-- Anime-Genre pivot
CREATE TABLE anime_genre (
    anime_id BIGINT UNSIGNED NOT NULL,
    genre_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (anime_id, genre_id),
    FOREIGN KEY (anime_id) REFERENCES anime_series(id) ON DELETE CASCADE,
    FOREIGN KEY (genre_id) REFERENCES genres(id) ON DELETE CASCADE
);
```

### 5.3 Front-end Controller

```php
<?php
// app/Http/Controllers/EpisodeController.php

namespace App\Http\Controllers;

use App\Models\Episode;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class EpisodeController extends Controller
{
    /**
     * Show the episode page with embedded video from the video host
     */
    public function show(string $seriesSlug, string $episodeSlug)
    {
        $episode = Episode::where('slug', $episodeSlug)
            ->with('anime')
            ->firstOrFail();

        // Generate embed URL for the video host
        $embedUrl = $this->generateEmbedUrl($episode);

        return view('episode.show', [
            'episode' => $episode,
            'series' => $episode->anime,
            'embed_url' => $embedUrl,
            // Pre-load next/prev episodes for seamless navigation
            'prev_episode' => $episode->getPrevious(),
            'next_episode' => $episode->getNext(),
        ]);
    }

    /**
     * Generate the embed iframe URL that points to the video host
     * This is the critical link between the two systems
     */
    private function generateEmbedUrl(Episode $episode): string
    {
        $videoHost = config('stream.video_host'); // https://video-host-domain.com
        $slug = $episode->video_slug;

        return "{$videoHost}/embed/{$slug}?ref=" . urlencode(config('app.url'));
    }

    /**
     * Search endpoint
     */
    public function search(Request $request)
    {
        $query = $request->get('q');

        // Use Laravel Scout (Algolia) or MySQL full-text search
        $results = $this->searchSeries($query);

        return response()->json($results);
    }

    private function searchSeries(string $query): array
    {
        return Cache::remember("search:{$query}", 3600, function () use ($query) {
            $series = \App\Models\AnimeSeries::whereRaw(
                'MATCH(title, synopsis) AGAINST(? IN BOOLEAN MODE)', [$query . '*']
            )->take(20)->get();

            return $series->toArray();
        });
    }
}
```

### 5.4 Embed View (Blade Template)

```blade
{{-- resources/views/episode/show.blade.php --}}
@extends('layouts.app')

@section('content')
<div class="container mx-auto px-4 py-8">
    <div class="max-w-4xl mx-auto">
        {{-- Video Player Container --}}
        <div class="aspect-video bg-black rounded-lg overflow-hidden shadow-xl">
            <iframe
                src="{{ $embed_url }}"
                class="w-full h-full"
                frameborder="0"
                scrolling="no"
                allowfullscreen
                allow="encrypted-media; autoplay; fullscreen"
                referrerpolicy="no-referrer-when-downgrade"
            ></iframe>
        </div>

        {{-- Episode Info --}}
        <div class="mt-6">
            <h1 class="text-2xl font-bold">{{ $series->title }}</h1>
            <p class="text-gray-400 mt-2">Episode {{ $episode->episode_number }}
               @if($episode->title) — {{ $episode->title }} @endif
            </p>
        </div>

        {{-- Navigation --}}
        <div class="flex justify-between mt-6">
            @if($prev_episode)
                <a href="{{ route('episode.show', [$series->slug, $prev_episode->slug]) }}"
                   class="px-4 py-2 bg-gray-800 rounded hover:bg-gray-700 transition">
                    ← Previous Episode
                </a>
            @endif

            <a href="{{ route('series.show', $series->slug) }}"
               class="px-4 py-2 bg-blue-600 rounded hover:bg-blue-500 transition">
                All Episodes
            </a>

            @if($next_episode)
                <a href="{{ route('episode.show', [$series->slug, $next_episode->slug]) }}"
                   class="px-4 py-2 bg-gray-800 rounded hover:bg-gray-700 transition">
                    Next Episode →
                </a>
            @endif
        </div>
    </div>
</div>
@endsection
```

### 5.5 Embed Player View (on Video Host)

```blade
{{-- resources/views/video-embed.blade.php --}}
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $video->title }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #000; overflow: hidden; }
        video { width: 100%; height: 100vh; object-fit: contain; }
    </style>
</head>
<body>
    <video
        id="player"
        controls
        autoplay
        playsinline
        preload="metadata"
        poster="https://portal-domain.com/thumbnails/{{ $video->slug }}.jpg"
    >
        @if($video->hls_path)
            <source src="/api/stream/{{ $video->slug }}/hls?token={{ $token }}" type="application/x-mpegURL">
        @else
            <source src="/api/stream/{{ $video->slug }}?token={{ $token }}" type="video/mp4">
        @endif
    </video>

    <script>
        // Generate dynamic tokens for seeking (when using progressive download)
        const player = document.getElementById('player');
        const baseUrl = '/api/stream/{{ $video->slug }}';
        let token = '{{ $token }}';

        // Refresh token periodically (every 55 minutes for 1-hour tokens)
        setInterval(() => {
            fetch('/api/refresh-token', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ slug: '{{ $video->slug }}', token: token })
            })
            .then(r => r.json())
            .then(data => { token = data.token; })
            .catch(() => {});
        }, 55 * 60 * 1000);
    </script>
</body>
</html>
```

---

## 6. Phase 5: Security & Hardening

### 6.1 Cloudflare Configuration

```bash
# Critical: Firewall on origin server — only allow Cloudflare IPs
# Get the latest Cloudflare IP ranges:
CLOUDFLARE_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CLOUDFLARE_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH from your IP only
sudo ufw allow from YOUR_IP to any port 22

# Allow only Cloudflare IPs to ports 80/443
for ip in $CLOUDFLARE_IPV4; do
    sudo ufw allow from $ip to any port 80 proto tcp
    sudo ufw allow from $ip to any port 443 proto tcp
done

for ip in $CLOUDFLARE_IPV6; do
    sudo ufw allow from $ip to any port 80 proto tcp
    sudo ufw allow from $ip to any port 443 proto tcp
done

sudo ufw enable
```

### 6.2 Cloudflare WAF Rules

Create these WAF rules in Cloudflare dashboard:

1. **Block direct IP access** — Block requests not going through Cloudflare
2. **Rate limiting** — Max 100 requests/minute per IP on video endpoints
3. **Geo-blocking** — Block countries with no legitimate traffic (optional)
4. **Browser integrity check** — Enable to block headless browsers/scrapers
5. **Bot fight mode** — Enable for video host domain

### 6.3 Laravel Security

```bash
# .env file — video host
APP_KEY=base64:...   # Generate with: php artisan key:generate
STREAM_SECRET=...    # 64-char random hex

# CORS config (config/cors.php)
'allowed_origins' => ['https://portal-domain.com'],
'supports_credentials' => true,
```

### 6.4 Nginx Anti-hotlinking (Additional Layer)

```nginx
# In the video host Nginx config, add direct file access protection:

# Block hotlinking to video files from unauthorized sites
location ~* \.(mp4|mkv|webm|m3u8|ts)$ {
    valid_referers none blocked server_names
        ~\.portal-domain\.com
        portal-domain.com;

    if ($invalid_referer) {
        return 403;
    }

    # Additional secure link check
    secure_link $arg_md5,$arg_expires;
    secure_link_md5 "$secure_link_expires$uri$remote_addr SECRET_HERE";

    if ($secure_link = "") { return 403; }
    if ($secure_link = "0") { return 410; }
}
```

---

## 7. Phase 6: Operations & Maintenance

### 7.1 Domain Rotation Plan

When a domain is seized or blocked:

1. **Register new domain** immediately (have 2-3 pre-registered)
2. **Update Cloudflare DNS** on the same account
3. **No server changes needed** — only Cloudflare DNS records change
4. **Announce new domain** via social media / status page
5. **301 redirect** old domain → new domain if possible

### 7.2 Monitoring

```bash
# Install monitoring
sudo apt install -y prometheus node_exporter grafana

# Monitor key metrics:
# - Bandwidth usage (keep under hosting plan limits)
# - Disk usage (add storage when >80% full)
# - PHP-FPM worker saturation
# - Nginx 4xx/5xx error rates
# - Cloudflare analytics
```

### 7.3 Backup Strategy

```bash
#!/bin/bash
# Backup script — run daily via cron

BACKUP_DIR="/backups"
DB_PASSWORD="your_db_password"

# Backup database
mysqldump -u root -p$DB_PASSWORD video_host > $BACKUP_DIR/db-$(date +%Y%m%d).sql

# Backup configs
tar czf $BACKUP_DIR/configs-$(date +%Y%m%d).tar.gz /etc/nginx/ /var/www/

# Keep 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

### 7.4 Load Scaling

When traffic grows past single server capacity:

```
                     ┌──────────────┐
                     │ Load Balancer │
                     │  (Round robin)│
                     └──────┬───────┘
              ┌─────────────┼─────────────┐
              │             │             │
        ┌─────▼─────┐ ┌────▼────┐ ┌─────▼─────┐
        │ Video Svr1 │ │Video Svr2│ │ Video Svr3 │
        │  50TB SSD  │ │  50TB SSD│ │  50TB SSD  │
        └────────────┘ └─────────┘ └────────────┘
              │             │             │
              └─────────────┼─────────────┘
                            │
                     ┌──────▼──────┐
                     │ Distributed  │
                     │ File System  │
                     │  (GlusterFS) │
                     └─────────────┘
```

### 7.5 Full Deployment Checklist

```
☐ Register domains (front-end + video host)
☐ Add both to Cloudflare, set proxied
☐ Provision servers at bulletproof host
☐ Configure UFW to allow only Cloudflare IPs
☐ Install Nginx, PHP, MySQL, Redis, Laravel
☐ Deploy video host application
☐ Deploy front-end portal application
☐ Configure Nginx with X-Accel for protected videos
☐ Generate & install Cloudflare Origin CA certs
☐ Set SSL to Full (Strict) in Cloudflare
☐ Create WAF rules for both domains
☐ Install encoding pipeline on encoding server
☐ Upload test video → verify end-to-end
☐ Set up cron jobs for backup + maintenance
☐ Configure monitoring (bandwidth, disk, errors)
☐ Register backup domains (pre-registered)
```

---

## 8. Appendix: Setup Script Reference

See the accompanying `setup.sh` script for an automated deployment script that provisions a video host server from scratch.

---

**Disclaimer:** This document is for academic research and educational purposes only. Operating a system that distributes copyrighted content without authorization is illegal in most jurisdictions and carries significant legal penalties. This document describes existing infrastructure patterns observed in the wild — it is not an endorsement or instruction to engage in illegal activity.
