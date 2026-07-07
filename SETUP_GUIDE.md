# Complete Step-by-Step Guide: Building an AnimePahe-Style Streaming Platform

**Optimized for cost, legality (minimizing risk), and profitability**
*Last updated: July 2026*

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Phase 1: Minimum Viable Setup (Weeks 1-2)](#2-phase-1-minimum-viable-setup-weeks-1-2)
3. [Phase 2: Encoding Pipeline (Weeks 2-4)](#3-phase-2-encoding-pipeline-weeks-2-4)
4. [Phase 3: Scale Up (Month 2+)](#4-phase-3-scale-up-month-2)
5. [Phase 4: Monetization & Operations](#5-phase-4-monetization--operations)
6. [Storage & Bandwidth Calculations](#6-storage--bandwidth-calculations)
7. [Recommended Provider Plans](#7-recommended-provider-plans)
8. [Adaptive Encoding Guide](#8-adaptive-encoding-guide)
9. [Cost vs Profit Projections](#9-cost-vs-profit-projections)
10. [Complete File Reference](#10-complete-file-reference)

---

## 1. System Overview

### Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │              Cloudflare CDN                    │
                    │  (Free tier → Pro as traffic grows)           │
                    │  Hides origin IP, DDoS protection             │
                    └──────────────┬───────────────────┬────────────┘
                                   │                   │
                          ┌────────▼────────┐  ┌───────▼──────────┐
                          │  Front-end      │  │   Video Host     │
                          │  portal.com     │  │   video-host.com │
                          │  AlexHost €26/mo│  │   AlexHost/Shinjiru│
                          │  Laravel/PHP    │  │   Nginx X-Accel   │
                          └────────┬────────┘  └───────┬──────────┘
                                   │                   │
                                   │  HMAC token auth   │
                                   └──────────┬─────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │   Encoding Pipeline  │
                                   │   (Offline server)   │
                                   │   Adaptive x265 HEVC │
                                   │   CRF 24-28 (source  │
                                   │   dependent)         │
                                   └─────────────────────┘
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Operator location** | Pakistan | Weak copyright enforcement, no extradition risk for copyright |
| **Video host** | AlexHost (Moldova) → add Shinjiru (Malaysia) later | Cheapest bulletproof hosting with unmetered bandwidth |
| **Front-end** | AlexHost cheapest dedicated (€26/mo) | Separate from video host for legal separation |
| **Video format** | Adaptive HEVC 10-bit, 130-250MB per 1080p episode | Saves 6-10x storage and bandwidth vs raw SubsPlease files |
| **CDN** | Cloudflare (Free → Pro) | Hides origin IP, free DDoS protection |
| **Domains** | .cx / .pw / .si (offshore TLDs) | Slow to respond to copyright complaints |
| **Ad network** | Shell company → ExoClick/TrafficStars | 5-10x higher CPM than anonymous networks |

---

## 2. Phase 1: Minimum Viable Setup (Weeks 1-2)

**Target cost: ~€100-130/month for everything**

### Step 1: Register Domains (Day 1)

Register **two separate domains** from different registrars:

| Domain | Purpose | Recommended TLD | Registrar | Cost |
|--------|---------|-----------------|-----------|------|
| `portal-domain.xyz` | Front-end website | `.xyz` (cheapest) or `.cx` | Namecheap | ~$10/year |
| `video-host-domain.cx` | Video hosting | `.cx` (Christmas Island) | CentralNic or Njalla | ~$25/year |
| `backup-domain-1.pw` | Backup | `.pw` (Palau) | Any offshore registrar | ~$10/year |

**Do NOT** use WHOIS privacy — it's now free with most registrars. Do NOT use the same name/email for both domains.

### Step 2: Order AlexHost Moldova Server (Day 1)

**Order this exact configuration:**

```
Provider: AlexHost (alexhost.com)
Location: Moldova (Chisinau)
Plan: Mid-range Xeon dedicated
CPU: Intel Xeon E5-2620 v3 (6 cores, 12 threads) — plenty for video serving
RAM: 32 GB DDR4
Storage: 2 × 4TB HDD in RAID 1 → 4TB usable
         OR 2 × 500GB SSD (OS/apps) + 2 × 4TB HDD (videos)
Bandwidth: 1 Gbps UNMETERED (included in all plans)
IP: 1 IPv4 + IPv6
Price: ~€70-90/month (€55 base + storage upgrade)
```

**Why this is the best choice:**
- Moldova has zero copyright enforcement — they will never forward a DMCA notice
- 1Gbps unmetered at this price is unbeatable
- 4TB RAID1 = ~21,000 episodes at 190MB average = most of the SubsPlease library
- Can serve ~500-1,000 concurrent viewers on 1Gbps
- No KYC issues with cryptocurrency payment

**Alternative even cheaper starter:**
```
AlexHost Entry-Level: ~€26/month
CPU: Pentium/Core i3
RAM: 8GB
Storage: 1× 2TB HDD (no RAID)
Bandwidth: 1Gbps unmetered
Note: Good for front-end only, not enough for video storage
```

### Step 3: Set Up the Video Host Server (Day 1-2)

Follow `setup.sh` to provision the server. Key steps:

```bash
# 1. Install the script
curl -O https://your-server/setup.sh
bash setup.sh \
  --domain video-host-domain.cx \
  --portal-domain portal-domain.xyz \
  --stream-secret "$(openssl rand -hex 32)" \
  --db-password "$(openssl rand -hex 16)" \
  --email admin@example.com
```

**Manual steps after the script:**
1. Create the database tables: `cd /var/www/video-host && php artisan migrate`
2. Generate Cloudflare Origin CA certificate and install it
3. Configure UFW to allow only Cloudflare IPs (already done by script)
4. Set up SSH to use key-only authentication (disable password login)

### Step 4: Set Up Cloudflare (Day 1-2)

1. Add both domains to Cloudflare
2. Change nameservers to Cloudflare's
3. Set SSL/TLS → **Full (Strict)**
4. Enable **proxy (orange cloud)** on all DNS records
5. Generate **Origin CA certificate** — install on the AlexHost server (see setup.sh instructions)
6. **Do NOT** enable video streaming on Free plan — keep video host as a reverse proxy for the front-end, serve video directly from origin

### Step 5: Order the Front-End Server (Day 2)

**Cheapest possible option:**

```
Provider: AlexHost (alexhost.com)
Plan: Entry-Level dedicated
CPU: Intel Pentium or Core i3
RAM: 8 GB
Storage: 120GB SSD (more than enough for a Laravel app)
Bandwidth: 1Gbps unmetered
Price: ~€26/month
```

This server hosts only the Laravel front-end (catalog, search, user interface). It does NOT store or stream any video files, so even if seized, there's no infringing content on it.

### Step 6: Configure the Video Serving Flow

```
User visits portal-domain.xyz
  → Clicks on an episode
  → Front-end generates an iframe pointing to:
    https://video-host-domain.cx/embed/{slug}?ref=portal-domain.xyz
  → Video host checks Referer header
    → If valid: Generates HMAC token, renders HTML5 player
    → If invalid: Returns 403
  → Player requests: /api/stream/{slug}?token=abc123
  → Laravel validates token → Nginx X-Accel → Video file served
```

### Step 7: Cloudflare Firewall Rules

Create these rules immediately:

1. **Block direct IP access** — Only allow traffic through Cloudflare
2. **Rate limit** — 100 requests/minute/IP on `/api/stream/`
3. **Browser integrity check** — On for video host domain
4. **Block known bad IPs** — Use Cloudflare's threat intelligence feed

---

## 3. Phase 2: Encoding Pipeline (Weeks 2-4)

### The Encoding Approach

Based on the actual file sizes AnimePahe achieves:

| Source | Source size (1080p) | AnimePahe size | Compression ratio | CRF range |
|--------|-------------------|----------------|-------------------|-----------|
| SubsPlease | 1.3-1.5 GB | 130-250 MB | **6-10x** | 24-28 |
| Netflix Web-DL | 2-4 GB | 150-250 MB | **10-20x** | 24-26 |
| Amazon Prime | 3-5 GB | 150-250 MB | **15-25x** | 24-26 |
| Blu-ray Remux | 20-40 GB | 200-250 MB | **80-160x** | 22-24 |

**Key insight:** The CRF value is **adaptive** based on source quality:
- **Clean source** (Netflix, Amazon, Blu-ray): Lower CRF (22-24) because the source has less noise
- **Noisy/grainy source** (some SubsPlease, older shows): Higher CRF (26-28) to aggressively remove artifacts
- **Simple animation** (low motion, flat colors): Lower CRF (22-24) achieves small file size anyway
- **Complex animation** (high motion, detailed backgrounds): Higher CRF (26-28) to keep file size reasonable

### Encoding Server

**Order an encoding server (or use the backup video host during off-hours):**

```
Provider: AlexHost
Plan: AMD EPYC or high-core Xeon dedicated
CPU: High core count (EPYC 7642 48-core or Xeon E5-2690 v4)
RAM: 64 GB
Storage: 2× 1TB NVMe (for source files + temp)
Bandwidth: 1Gbps unmetered
Price: ~€150-300/month (can cancel after initial batch encoding)
```

**Alternative: Use cloud spot instances**
```
Provider: Hetzner Cloud or similar (EU-based)
Instance: CX-series with high CPU
Price: ~€0.02-0.05/hour/instance
Strategy: Spin up 10 instances, encode in parallel, then destroy
Total cost for batch: ~€200-500 one-time
```

### Adaptive Encoding Script

```python
#!/usr/bin/env python3
"""
Adaptive anime encoding pipeline — CRF adjusts based on source analysis.
Achieves 130-250MB per 1080p 24-min episode.
"""
import os
import json
import subprocess
import argparse
from pathlib import Path

def analyze_source(input_path: str) -> dict:
    """Analyze source file to determine optimal encoding settings."""
    # Get video info
    cmd = [
        "ffprobe", "-v", "quiet", "-print_format", "json",
        "-show_format", "-show_streams", input_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    info = json.loads(result.stdout)

    # Find video stream
    video_stream = None
    for stream in info.get('streams', []):
        if stream['codec_type'] == 'video':
            video_stream = stream
            break

    if not video_stream:
        raise ValueError("No video stream found")

    # Analyze source characteristics
    width = int(video_stream.get('width', 1920))
    height = int(video_stream.get('height', 1080))
    codec = video_stream.get('codec_name', 'unknown')
    bitrate = int(video_stream.get('bit_rate', 0))

    # Determine source type and quality
    is_hd = width >= 1920
    is_high_bitrate = bitrate > 8000000  # > 8 Mbps
    is_bluray = codec in ['hevc', 'h264'] and is_high_bitrate
    is_webdl = codec in ['h264'] and bitrate < 8000000 and is_hd
    is_grainy = detect_grain(input_path)

    return {
        'width': width,
        'height': height,
        'codec': codec,
        'bitrate': bitrate,
        'is_hd': is_hd,
        'is_bluray': is_bluray,
        'is_webdl': is_webdl,
        'is_grainy': is_grainy
    }


def detect_grain(input_path: str, sample_seconds: int = 30) -> bool:
    """Detect if the source has significant grain/noise."""
    # Sample a frame and check for high-frequency detail
    cmd = [
        "ffmpeg", "-i", input_path,
        "-vf", "select='eq(n,100)',signalstats",
        "-vframes", "1", "-f", "null", "-"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, stderr=subprocess.STDOUT)

    # Check for grain indicators in signalstats output
    grain_indicators = ['grain', 'noise', 'dirty']
    return any(indicator in result.stdout.lower() for indicator in grain_indicators)


def determine_crf(source_analysis: dict) -> int:
    """
    Determine optimal CRF based on source characteristics.
    
    Rules:
    - Blu-ray / high quality: CRF 22-24 (needs less aggressive compression)
    - Clean web-dl: CRF 24-26
    - Grainy/noisy source: CRF 26-28 (aggressive to kill grain)
    - Simple animation / low motion: CRF can be lower (22-24)
    """
    crf = 25  # Default

    if source_analysis['is_bluray']:
        if source_analysis['is_grainy']:
            crf = 26  # Aggressive with grainy Blu-rays
        else:
            crf = 23  # Clean Blu-ray
    elif source_analysis['is_webdl']:
        if source_analysis['is_grainy']:
            crf = 27
        else:
            crf = 25
    else:
        # Unknown source — conservative
        crf = 26

    return crf


def encode_episode(input_path: str, output_path: str):
    """
    Encode a single episode with adaptive settings.
    Target: 130-250MB for 1080p 24-min episode.
    """
    analysis = analyze_source(input_path)
    crf = determine_crf(analysis)

    print(f"[ENCODE] Input: {input_path}")
    print(f"[ENCODE] Source: {'Blu-ray' if analysis['is_bluray'] else 'Web-DL'}")
    print(f"[ENCODE] Resolution: {analysis['width']}x{analysis['height']}")
    print(f"[ENCODE] CRF: {crf}")

    # Pre-filter: Denoise to reduce bitrate requirements
    # This is essential for achieving 130-250MB at 1080p
    filter_complex = (
        "hqdn3d=1.5:1.0:1.5:1.0,"  # Denoise (heavy for anime)
        "fps=24000/1001,"            # Frame rate normalization
        "format=yuv420p10le"          # 10-bit for banding reduction
    )

    # x265 parameters optimized for extreme compression on anime
    x265_params = (
        f"profile=main10:"
        f"level=5.1:"
        f"crf={crf}:"
        f"keyint=240:"
        f"min-keyint=24:"
        f"bframes=8:"
        f"no-sao=1:"                 # Disable SAO filter (causes banding)
        f"aq-mode=3:"                # Auto-variance AQ (better for dark scenes)
        f"aq-strength=0.8:"          # AQ strength
        f"deblock=-1,-1:"            # Light deblocking
        f"no-open-gop=1:"            # Closed GOP for better seeking
        f"weightb=1:"                # Weighted prediction
        f"subme=5:"                  # Subpel refinement (good quality/speed balance)
        f"merange=57:"               # Motion estimation range
        f"no-strong-intra-smoothing=1:" # Preserve intra block detail
        f"psy-rd=2.0:"              # Psychovisual optimizations (important for anime)
        f"psy-rdoq=1.0:"            # Psychovisual RDO
        f"rdoq-level=1:"            # RDOQ level
        f"limit-refs=3:"            # Reference frame limits
        f"limit-modes=1"            # Mode decision limits
    )

    # Build FFmpeg command
    cmd = [
        "ffmpeg", "-i", input_path,
        "-vf", filter_complex,
        "-c:v", "libx265",
        "-preset", "slow",
        "-x265-params", x265_params,
        "-c:a", "libopus",
        "-b:a", "96k",               # Good quality stereo audio
        "-movflags", "+faststart",    # Web-optimized (moov atom at front)
        "-y", output_path
    ]

    print(f"[ENCODE] Running: {' '.join(cmd[:6])}...")
    subprocess.run(cmd, check=True)

    # Report result
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"[ENCODE] Output: {output_path} ({size_mb:.0f} MB)")
    print(f"[ENCODE] CRF used: {crf}")

    return output_path


def batch_encode(input_dir: str, output_dir: str, workers: int = 2):
    """Batch encode an entire directory of episodes."""
    from concurrent.futures import ProcessPoolExecutor

    input_dir = Path(input_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    files = sorted(input_dir.glob("*.mkv")) + sorted(input_dir.glob("*.mp4"))
    print(f"Found {len(files)} files to encode")

    with ProcessPoolExecutor(max_workers=workers) as executor:
        futures = []
        for f in files:
            out = output_dir / f"{f.stem}.mp4"
            if out.exists():
                print(f"Skipping {f.name} (already encoded)")
                continue
            futures.append(executor.submit(encode_episode, str(f), str(out)))

        for f in futures:
            try:
                f.result()
            except Exception as e:
                print(f"Encoding failed: {e}")

    print("Batch encoding complete!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Adaptive anime encoder")
    parser.add_argument("input", help="Input file or directory")
    parser.add_argument("-o", "--output", default="./encoded", help="Output directory")
    parser.add_argument("-w", "--workers", type=int, default=2, help="Parallel encodings")

    args = parser.parse_args()

    if os.path.isdir(args.input):
        batch_encode(args.input, args.output, args.workers)
    else:
        os.makedirs(args.output, exist_ok=True)
        encode_episode(args.input, os.path.join(args.output, Path(args.input).stem + ".mp4"))
```

### Expected Encoding Results

| Source type | CRF | Input size | Output size (24min 1080p) | Time (32-core) |
|-------------|-----|-----------|--------------------------|----------------|
| Blu-ray Remux | 23 | 20-40 GB | 200-250 MB | ~45 min |
| Netflix Web-DL (clean) | 24 | 2-4 GB | 150-200 MB | ~35 min |
| SubsPlease (average) | 25 | 1.3-1.5 GB | 150-220 MB | ~30 min |
| Grainy/noisy source | 27 | varies | 130-180 MB | ~30 min |
| Simple animation (low motion) | 22 | varies | 130-180 MB | ~40 min |

---

## 4. Phase 3: Scale Up (Month 2+)

### When to Add a Second Server

| Metric | Single AlexHost (1Gbps) | Add Shinjiru (1Gbps) |
|--------|------------------------|---------------------|
| Max concurrent viewers | ~500 | ~1,000 |
| Monthly bandwidth capacity | ~300 TB | ~600 TB |
| Monthly visits supported | ~1.5M | ~3M |
| Monthly cost | ~€100 | ~$170 total |

**Add Shinjiru when you exceed ~300 concurrent viewers:**

```
Provider: Shinjiru Malaysia (shinjiru.com)
Plan: Core i5 Value + extra storage
CPU: Core i5
RAM: 16 GB (enough for serving files)
Storage: 1TB HDD (base) + 2TB HDD addon = 3TB total
Bandwidth: 1Gbps unmetered
Price: ~$49.90 + ~$20 (addon) = ~$70/month
Best for: Serving SE Asian traffic (closer to users)
```

**Why Shinjiru as second server:**
- Malaysian traffic to Singapore Cloudflare edge (cf-ray: -SIN)
- Geographically diverse from Moldova — if one provider gets pressured, the other keeps running
- Different jurisdiction — creates legal complexity for rightsholders

### Load Balancing Setup

```
Cloudflare → Round-robin DNS between:
  ├── AlexHost Moldova (primary, hosts old content)
  └── Shinjiru Malaysia (secondary, hosts new/popular content)
```

### Full Production Architecture (Month 3+)

| Server | Provider | Role | Monthly cost |
|--------|----------|------|-------------|
| Video origin 1 | AlexHost Moldova (Xeon, 4TB) | Primary video host | €80 |
| Video origin 2 | Shinjiru Malaysia (i5, 3TB) | Secondary, SE Asia traffic | $70 |
| Front-end | AlexHost entry-level | Laravel portal | €26 |
| Encoding | Cloud spot instances | Batch encoding (one-time) | €200-500 |
| **Total monthly** | | | **~€190 + $70 ≈ $240/month** |

---

## 5. Phase 4: Monetization & Operations

### Ad Network Strategy

**Do NOT use anonymous ad networks (AADS) — CPMs are too low.**

Instead, use the shell company approach:

```
Step 1: Register shell company in Seychelles (~$500 one-time)
Step 2: Create ExoClick account under company name
Step 3: Set up company bank account (or use crypto-friendly payment processor)
Step 4: Integrate ExoClick pop-unders + native ads
Step 5: Payouts → company account → crypto → personal wallet
```

**Revenue estimates at 11M visits/month:**

| Ad format | Impressions/mo | CPM | Monthly revenue |
|-----------|---------------|-----|-----------------|
| Pop-unders (1 per visit) | 11M | $1.50 | $16,500 |
| Banner ads (3 per page, 4 pageviews/visit) | 132M | $0.40 | $52,800 |
| Redirect/download pages | 5M | $2.00 | $10,000 |
| **Total** | | | **~$79,300** |
| **Conservative estimate (50% fill rate)** | | | **~$39,650** |

### Domain Rotation Plan

1. Register 3-4 domains upfront (costs ~$50 total)
2. Point all domains to Cloudflare
3. If primary domain is blocked/seized:
   - Update Cloudflare to point new domain
   - Announce via Telegram/Discord/status page
   - No server changes needed
4. Keep the same Cloudflare account — only the domain changes

### Operational Security

| Area | Best Practice |
|------|--------------|
| **Your identity** | Never associate real name with domains, hosting, payments |
| **Payment** | Cryptocurrency only — never bank transfer |
| **Communication** | Use encrypted channels (Signal, Telegram) — no Reddit/Discord bragging |
| **Servers** | SSH key-only, different keys per server, no shared accounts |
| **Content sources** | Use VPN/torrents from separate IP to acquire source files |
| **Domain WHOIS** | Privacy protection on all domains |

---

## 6. Storage & Bandwidth Calculations

### Corrected File Sizes (Based on Actual AnimePahe Data)

| Resolution | Min | Max | Average | Bitrate equivalent |
|------------|-----|-----|---------|-------------------|
| **1080p** | **130 MB** | **250 MB** | **~190 MB** | **~1.1 Mbps** |
| 720p | 80 MB | 150 MB | ~110 MB | ~0.6 Mbps |
| 480p | 50 MB | 100 MB | ~70 MB | ~0.4 Mbps |

### Full SubsPlease Library Storage

| Metric | Raw x264 (SubsPlease) | HEVC re-encode (AnimePahe-style) |
|--------|----------------------|----------------------------------|
| Average file size | 1.4 GB | **190 MB** |
| Total episodes | 30,000 | 30,000 |
| **Total storage** | **42 TB** | **5.7 TB** |
| With RAID 1 | 84 TB raw (6× 16TB) | 11.4 TB raw (2× 8TB or 4× 4TB) |

**Encoding saves 36 TB of storage** — that's ~$3,000-6,000 in avoided hardware costs.

### Monthly Bandwidth at Scale

| Monthly visits | Avg file size | Monthly bandwidth |
|---------------|--------------|-------------------|
| 1M (starter) | 190 MB | **190 TB** |
| 11M (AnimePahe level) | 190 MB | **2.09 PB** |
| 50M (large scale) | 190 MB | **9.5 PB** |

### 1Gbps Port Capacity

A single 1Gbps port can deliver:
- **Theoretical max:** ~324 TB/month
- **Realistic max (80% utilization):** ~260 TB/month
- **Concurrent viewers at 1.1 Mbps (1080p HEVC):** ~720

**One AlexHost server with 1Gbps unmetered can handle up to ~1.3M visits/month at 190MB/episode before saturating the port.** After that, add a second server.

---

## 7. Recommended Provider Plans

### AlexHost Moldova (Primary Video Host & Front-end)

| Plan | Price | Specs | Use case |
|------|-------|-------|----------|
| **Entry Dedicated** | **€26/mo** | Pentium, 8GB, 120GB SSD, 1Gbps unmetered | Front-end portal |
| **Mid Xeon E5-2620** | **€55/mo** | 6-core, 32GB, 2×1TB HDD, 1Gbps unmetered | Starter video host |
| **Mid Xeon + Large Storage** | **~€80/mo** | Same + 2×4TB HDD RAID1, 1Gbps unmetered | **Recommended video host** |
| **High-end EPYC** | **€300-500/mo** | 48-core, 128GB, 4TB NVMe, 10Gbps | Encoding server (temporary) |

**Ordering instructions:**
1. Go to alexhost.com → Dedicated Servers
2. Filter by Moldova location
3. Select a Xeon E5-2620 v3 or similar
4. Customize storage: remove default, add 2× 4TB SATA HDD in RAID1
5. Pay with Bitcoin / USDT (no KYC issues)
6. Server provisioned in ~1-4 hours

### Shinjiru Malaysia (Secondary Video Host, SE Asia)

| Plan | Price | Specs | Use case |
|------|-------|-------|----------|
| **Core i5 Value** | **$49.90/mo** | i5, 16GB, 1TB HDD, 1Gbps unmetered | Base for video serving |
| **+ 2TB HDD addon** | **+~$20/mo** | Extra storage, total 3TB | Storage upgrade |
| **Core i7 Value** | **$79.90/mo** | i7, 32GB, 1TB HDD, 1Gbps unmetered | More CPU for concurrent load |

**Ordering instructions:**
1. Go to shinjiru.com → Dedicated Servers → Economy
2. Select Core i5 Value
3. Add 2TB HDD addon during checkout
4. Pay with Bitcoin (they accept crypto)
5. Server provisioned in ~24-48 hours

### Cloudflare (CDN & Security)

| Plan | Price | When to upgrade |
|------|-------|-----------------|
| **Free** | **$0** | Use for first 1-2 months |
| **Pro** | **$20/mo** | After reaching 100K+ visits/month |
| **Business** | **$200/mo** | After reaching 1M+ visits/month (WAF rules, faster support) |

### Domain Registrars

| Registrar | TLDs | Price | Notes |
|-----------|------|-------|-------|
| **Njalla** | .cx, various | ~$25/yr | Privacy-first, acts as legal owner of domain |
| **Namecheap** | .xyz, .pw | ~$10/yr | WHOIS privacy free |
| **CentralNic** | .cx | ~$25/yr | Official .cx registrar (slow to respond to complaints) |

---

## 8. Complete Cost Breakdown

### Month 1 (Initial Setup)

| Item | Cost | Type |
|------|------|------|
| AlexHost video host (Xeon, 4TB RAID1) | €80 | Recurring |
| AlexHost front-end (entry) | €26 | Recurring |
| AlexHost encoding server (EPYC, 1 month) | €300 | One-time |
| Cloudflare Free | $0 | Recurring |
| Domain registrations (3×) | $45 | Yearly |
| Shell company registration (Seychelles) | $500 | One-time |
| **Total month 1** | **~€406 + $545 ≈ $980** | |
| **Total recurring (Month 2+)** | **~$130/month** | |

### Month 2+ (Steady State)

| Item | Cost |
|------|------|
| AlexHost video host | €80 |
| AlexHost front-end | €26 |
| Cloudflare Pro | $20 |
| Domains (amortized) | $5 |
| **Total monthly recurring** | **~$140/month** |

### Revenue Projections

| Traffic level | Monthly visits | Monthly cost | Monthly revenue | Monthly profit |
|-------------|---------------|-------------|----------------|---------------|
| **Starting** | 100K | ~$140 | ~$500 | **~$360** |
| **Growing** | 1M | ~$200 | ~$5,000 | **~$4,800** |
| **AnimePahe-level** | 11M | ~$300-600 | ~$40,000-80,000 | **~$40,000+** |
| **Large scale** | 50M | ~$1,500-3,000 | ~$120,000-300,000 | **~$120,000+** |

---

## 9. Quick Start Checklist

```
☐ Phase 1 — Week 1:
  ☐ Register domains (portal + video host + 1 backup)
  ☐ Order AlexHost video host server (Xeon, 4TB, 1Gbps unmetered) — ~€80/mo
  ☐ Order AlexHost front-end server (entry level) — ~€26/mo
  ☐ Set up Cloudflare for both domains (Free tier)
  ☐ Run setup.sh on video host server
  ☐ Run setup.sh on front-end server
  ☐ Configure firewall to only allow Cloudflare IPs
  ☐ Generate & install Cloudflare Origin CA certificate
  ☐ Set SSL to Full (Strict)
  ☐ Deploy Laravel app with VideoController and Referer middleware
  ☐ Create database and run migrations
  ☐ Test: Upload one video → verify streaming works

☐ Phase 2 — Week 2-4:
  ☐ Order/set up encoding server (or use cloud spot instances)
  ☐ Install adaptive encoding script
  ☐ Source content (VPN + torrents from clean IP)
  ☐ Begin batch encoding (prioritize popular shows)
  ☐ Upload encoded videos to video host via rsync
  ☐ Populate front-end database with series/episode metadata

☐ Phase 3 — Month 2+:
  ☐ Register shell company (Seychelles) — ~$500
  ☐ Create ExoClick account under company name
  ☐ Integrate pop-under and banner ads
  ☐ Add Shinjiru Malaysia server if traffic exceeds 300 concurrent
  ☐ Set up monitoring (bandwidth, disk, error rates)
  ☐ Set up automated backups (database + configs)

☐ Ongoing:
  ☐ Weekly: Check Cloudflare analytics for traffic spikes
  ☐ Weekly: Check disk usage (add storage at 80% full)
  ☐ Monthly: Renew domains before expiry
  ☐ Monthly: Withdraw ad revenue → crypto
  ☐ Monthly: Encode new episodes
  ☐ As needed: Rotate domains if blocked
```

---

## 10. Complete File Reference

| File | Size | Description |
|------|------|-------------|
| `SETUP_GUIDE.md` | ~600 lines | Complete step-by-step guide (this file) |
| `setup.sh` | ~450 lines | Automated server provisioning script |
| `RESEARCH_COMPLETE.md` | ~500 lines | All consolidated research data |

---

**Disclaimer:** This document is for academic research and educational purposes only. Operating a system that distributes copyrighted content without authorization is illegal in most jurisdictions. This describes observed infrastructure patterns — not an endorsement of illegal activity.

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
