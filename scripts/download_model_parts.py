# -*- coding: utf-8 -*-
"""分段下载 Qwen3-Embedding-0.6B model.safetensors（hf-mirror，不稳定连接自适应）。

用法: python download_model_parts.py
- 每段 64MB，4 线程并行，每段独立重试，支持断点续传。
- 完成后合并为 model.safetensors 并清理分段文件。
"""
import os
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

URL = "https://hf-mirror.com/Qwen/Qwen3-Embedding-0.6B/resolve/main/model.safetensors"
DEST_DIR = r"C:\Users\yangwei\Desktop\RepoMind\.data\models\Qwen3-Embedding-0.6B"
DEST = os.path.join(DEST_DIR, "model.safetensors")
PART_DIR = os.path.join(DEST_DIR, ".parts")
CHUNK = 64 * 1024 * 1024  # 64MB
THREADS = 4
TIMEOUT = 180


def get_total_size():
    req = urllib.request.Request(URL, method="HEAD")
    with urllib.request.urlopen(req, timeout=30) as r:
        # hf-mirror 302 后 HEAD 可能无 Content-Length，改发带 Range 的 GET
        length = r.headers.get("Content-Length")
        if length:
            return int(length)
    req = urllib.request.Request(URL)
    req.add_header("Range", "bytes=0-0")
    with urllib.request.urlopen(req, timeout=30) as r:
        content_range = r.headers.get("Content-Range", "")
        # bytes 0-0/1191247888
        total = content_range.split("/")[-1]
        return int(total)


def download_part(idx, start, end):
    part_file = os.path.join(PART_DIR, f"part_{idx:03d}")
    expected = end - start + 1
    while True:
        done = os.path.getsize(part_file) if os.path.exists(part_file) else 0
        if done >= expected:
            return idx, True
        resume_start = start + done
        try:
            req = urllib.request.Request(URL)
            req.add_header("Range", f"bytes={resume_start}-{end}")
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                with open(part_file, "ab") as f:
                    while True:
                        data = resp.read(1024 * 1024)
                        if not data:
                            break
                        f.write(data)
            done = os.path.getsize(part_file)
            if done >= expected:
                return idx, True
            print(f"[part {idx}] incomplete {done}/{expected}, resuming", flush=True)
        except Exception as e:
            print(f"[part {idx}] retry after error: {e}", flush=True)
            time.sleep(2)


def main():
    os.makedirs(PART_DIR, exist_ok=True)
    if os.path.exists(DEST):
        cur = os.path.getsize(DEST)
        if cur >= get_total_size():
            print(f"model.safetensors already complete: {cur}")
            return
    total = get_total_size()
    print(f"total: {total} bytes ({total/1024/1024:.1f} MB)", flush=True)
    parts = []
    start = 0
    while start < total:
        end = min(start + CHUNK - 1, total - 1)
        parts.append((start, end))
        start = end + 1
    print(f"parts: {len(parts)}", flush=True)

    with ThreadPoolExecutor(max_workers=THREADS) as ex:
        futures = {ex.submit(download_part, i, s, e): i for i, (s, e) in enumerate(parts)}
        for fut in as_completed(futures):
            idx, ok = fut.result()
            print(f"[part {idx}] done", flush=True)

    print("merging parts...", flush=True)
    with open(DEST, "wb") as out:
        for i in range(len(parts)):
            part_file = os.path.join(PART_DIR, f"part_{i:03d}")
            with open(part_file, "rb") as pf:
                while True:
                    data = pf.read(8 * 1024 * 1024)
                    if not data:
                        break
                    out.write(data)
    final = os.path.getsize(DEST)
    print(f"MERGED: {final} bytes ({final/1024/1024:.1f} MB)", flush=True)

    import shutil
    shutil.rmtree(PART_DIR, ignore_errors=True)
    print("parts cleaned", flush=True)


if __name__ == "__main__":
    sys.exit(main())
