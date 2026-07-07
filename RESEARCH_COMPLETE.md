# Anime Streaming Piracy Infrastructure — Complete Research

**Consolidated Research Document**
*Last updated: July 2026*

---

## Table of Contents

1. [How AnimePahe & Kwik.cx Operate](#1-how-animepahe--kwikcx-operate)
2. [How They Avoid Takedowns](#2-how-they-avoid-takedowns)
3. [Live Reconnaissance Results](#3-live-reconnaissance-results)
4. [Corrected Storage & Bandwidth Calculations](#4-corrected-storage--bandwidth-calculations)
5. [Adaptive Encoding Guide](#5-adaptive-encoding-guide)
6. [AnimePahe Financial Analysis](#6-animepahe-financial-analysis)
7. [Recommended Provider Plans with Pricing](#7-recommended-provider-plans-with-pricing)
8. [Cost-Optimized Architecture](#8-cost-optimized-architecture)
9. [Legal Risk by Jurisdiction](#9-legal-risk-by-jurisdiction)
10. [Ad Networks & Monetization](#10-ad-networks--monetization)

---

## 1. How AnimePahe & Kwik.cx Operate

AnimePahe and Kwik.cx are **two tiers of the same operation** — owned by the same entity:

| Layer | Platform | Role |
|-------|----------|------|
| **Front-end (UI)** | AnimePahe | Catalog, search, episode navigation |
| **Video Host** | Kwik.cx | Stores and streams encoded video files |
| **Encoding** | Internal pipeline | x265 HEVC 10-bit, adaptive CRF 24-28, heavy pre-filtering |

**Content pipeline:**
1. Sources from SubsPlease, Netflix, Amazon Prime, Blu-ray
2. Re-encodes using adaptive x265 HEVC — CRF varies 24-28 based on source quality
3. Result: **130-250MB per 1080p 24-minute episode** (vs 1.3-1.5 GB raw = 6-10x compression)
4. Uploads encoded files to Kwik.cx (private video hosting)
5. Kwik.cx serves behind Cloudflare with referer + HMAC token access control

---

## 2. How They Avoid Takedowns

| Layer | Method | Effectiveness |
|-------|--------|--------------|
| **Origin IP** | Cloudflare proxy | Very high (no leaks in 8+ years) |
| **Server** | Bulletproof host in Moldova/Malaysia | Very high (no legal cooperation) |
| **Domain TLD** | .cx (Christmas Island) | High (registry ignores abuse) |
| **Registrar** | CentralNic (London) | High (requires UK court order) |
| **Access control** | Referer check + HMAC signed tokens | High |

---

## 3. Live Reconnaissance Results

**DNS:** kwik.cx → Cloudflare IPs only (104.21.54.81, 172.67.136.199)
**Nameservers:** adam.ns.cloudflare.com, marissa.ns.cloudflare.com
**Backend:** Laravel/PHP (identified via `kwik_session` encrypted cookie format)
**Server routing:** `srv=s0` cookie → multiple origin servers behind load balancer
**CDN edge:** Singapore (`cf-ray: -SIN`) → origin likely in SE Asia
**WHOIS:** Created 2018, registrar CentralNic London, .cx TLD, locked status

---

## 4. Corrected Storage & Bandwidth Calculations

### Actual AnimePahe File Sizes

| Resolution | Min | Max | Average | Effective bitrate |
|------------|-----|-----|---------|-------------------|
| **1080p** | **130 MB** | **250 MB** | **~190 MB** | **~1.1 Mbps** |
| 720p | 80 MB | 150 MB | ~110 MB | ~0.6 Mbps |
| 480p | 50 MB | 100 MB | ~70 MB | ~0.4 Mbps |

### Full SubsPlease Library

| Metric | Raw x264 | HEVC re-encode |
|--------|----------|----------------|
| Per episode | 1.4 GB | **190 MB** |
| 30,000 episodes | 42 TB | **5.7 TB** |
| With RAID 1 | 84 TB raw | **11.4 TB raw** (2× 8TB HDDs) |

**Encoding saves 36 TB → ~$3,000-6,000 in avoided hardware.**

### Bandwidth by Traffic Level

| Visits/mo | Bandwidth | Servers needed |
|-----------|-----------|----------------|
| 100K | 19 TB | 1× AlexHost (1Gbps) |
| 1M | 190 TB | 1× AlexHost |
| **11M** (AnimePahe) | **2.09 PB** | 2-3× servers |
| 50M | 9.5 PB | 5-10× servers |

---

## 5. Adaptive Encoding Guide

| Source | Source size | Output size | CRF |
|--------|------------|-------------|-----|
| Blu-ray Remux (clean) | 20-40 GB | 200-250 MB | 22-23 |
| Netflix Web-DL | 2-4 GB | 150-200 MB | 24 |
| SubsPlease | 1.3-1.5 GB | 150-220 MB | 25 |
| Amazon Prime | 3-5 GB | 150-200 MB | 24 |
| Grainy source | varies | 130-180 MB | 27-28 |

**Key technique:** Heavy pre-filtering (hqdn3d denoise + debanding) before encoding removes wasted bitrate from grain. This is the #1 reason for extreme compression.

---

## 6. AnimePahe Financial Analysis

**Monthly traffic:** ~11.15M visits (Semrush)
**Monthly OpEx:** ~$250-550/mo (2-3 bulletproof servers + Cloudflare Pro)
**Monthly revenue:** ~$40,000-80,000 (ExoClick via shell company, pop-unders + banners + redirects)
**Monthly profit:** **~$39,000-79,000**

---

## 7. Recommended Provider Plans

### AlexHost Moldova — Primary

| Plan | Price | Specs |
|------|-------|-------|
| Entry Dedicated | **€26/mo** | Pentium, 8GB, 120GB SSD, 1Gbps unmetered — front-end |
| Mid Xeon + 4TB | **€80/mo** | Xeon E5-2620, 32GB, 2×4TB RAID1, 1Gbps unmetered — **video host** |
| EPYC encoding | €300-500/mo | 48-core, 64GB, 4TB NVMe — temporary batch encoding |

### Shinjiru Malaysia — Secondary (add when needed)

| Plan | Price | Specs |
|------|-------|-------|
| Core i5 Value | **$49.90/mo** | i5, 16GB, 1TB HDD, 1Gbps unmetered |
| + 2TB HDD addon | **+$20/mo** | Total 3TB storage |

### Cloudflare

Free → Pro ($20/mo) after 100K visits/mo.

---

## 8. Cost-Optimized Architecture

### Minimum Viable (~$140/mo)

- 1× AlexHost Moldova (Xeon, 4TB, €80) = video host
- 1× AlexHost entry (€26) = front-end portal
- Cloudflare Free ($0) + domains (~$5)
- **Capacity: ~1.3M visits/mo**

### Full Production (~$240/mo)

- 1× AlexHost (€80) = primary video host
- 1× Shinjiru Malaysia ($70) = secondary video host
- 1× AlexHost entry (€26) = front-end
- Cloudflare Pro ($20) + domains (~$5)
- **Capacity: ~3M visits/mo**

### Profit Projections

| Traffic | Cost | Revenue | Profit |
|---------|------|---------|--------|
| 100K | $140 | $500 | **+$360** |
| 1M | $200 | $5,000 | **+$4,800** |
| 11M | $400-600 | $40-80K | **+$39-79K** |
| 50M | $1500-3000 | $120-300K | **+$118K+** |

---

## 9. Legal Risk by Jurisdiction

### Pakistan (Safest)

| Factor | Assessment |
|--------|-----------|
| Copyright enforcement | Nearly non-existent for digital piracy |
| Extradition risk | <5% — no treaty with Japan, US treaty never used for copyright |
| **Verdict** | **SAFEST CHOICE** |

### China (Risky)

| Factor | Assessment |
|--------|-----------|
| Copyright law | Modern (2020), punitive damages, criminal penalties |
| Chinese content | HIGH RISK — domestic studios pursue aggressively |
| Japanese content | LOW-MEDIUM risk |
| Documented cases | Sakura Anime 2025 convicted, b9good.com 2023 shut down |
| **Verdict** | **RISKY** |

---

## 10. Ad Networks & Monetization

**Strategy:** Shell company (Seychelles ~$500) → ExoClick account → $1-5 CPM

vs anonymous networks (AADS) at $0.10-0.80 CPM = **5-10x difference**.

---

**Disclaimer:** For academic research purposes only. Operating a system that distributes copyrighted content without authorization is illegal in most jurisdictions.
