#!/usr/bin/env python3
"""Incremental parallel GCC compilation for the native Switch build.

Each object stores the digest of compiler flags, its C source, and every
header in GCC's dependency file. Generated sources can be republished with
new timestamps without causing needless recompilation. Cached objects are
never reused when an input's bytes differ.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import threading


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dependencies(path):
    text = path.read_text(encoding="utf-8")
    # GCC Makefile syntax: a backslash-newline joins lines, and escaped spaces
    # are part of the path rather than a dependency separator.
    text = text.replace("\\\n", " ")
    if ": " not in text:
        raise ValueError("invalid GCC dependency file")
    tail = text.split(": ", 1)[1]
    return [Path(word.replace("\\ ", " ")) for word in re.findall(r"(?:\\ |[^\s])+", tail)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cc", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--", dest="extra", nargs="*")
    args, flags = parser.parse_known_args()
    if flags and flags[0] == "--":
        flags = flags[1:]
    if not flags:
        parser.error("compiler flags must follow --")
    jobs = max(1, min(args.jobs, 4))
    jobspecs = []
    with open(args.manifest, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line:
                source, object_file = line.split("\t", 1)
                jobspecs.append((Path(source), Path(object_file)))
    if not jobspecs:
        parser.error("empty source manifest")
    compiler = Path(args.cc).resolve()
    stat = compiler.stat()
    flagkey = sha(repr((str(compiler), stat.st_size, stat.st_mtime_ns, flags)).encode())
    lock = threading.Lock()
    digest_cache = {}

    def digest(path):
        path = path.resolve()
        stat = path.stat()
        key = (str(path), stat.st_size, stat.st_mtime_ns)
        with lock:
            cached = digest_cache.get(key)
        if cached is not None:
            return cached
        output = sha(path.read_bytes())
        with lock:
            digest_cache[key] = output
        return output

    def signature(source, depfile):
        dep_paths = [source]
        if depfile.exists():
            dep_paths.extend(dependencies(depfile))
        else:
            return None
        checks = [flagkey]
        for path in sorted(set(x.resolve() for x in dep_paths)):
            checks.append(str(path))
            checks.append(digest(path))
        return sha("\n".join(checks).encode())

    def compile_one(entry):
        source, obj = entry
        if not source.is_file():
            raise FileNotFoundError(source)
        obj.parent.mkdir(parents=True, exist_ok=True)
        dep = Path(str(obj) + ".d")
        marker = Path(str(obj) + ".sha256")
        cached_sig = None
        if obj.is_file() and marker.is_file():
            try:
                cached_sig = signature(source, dep)
                if marker.read_text().strip() == cached_sig:
                    return "cached", source
            except (OSError, ValueError):
                pass
        temp_obj = Path(str(obj) + ".tmp")
        temp_dep = Path(str(dep) + ".tmp")
        try:
            proc = subprocess.run(
                [args.cc, *flags, "-MD", "-MF", str(temp_dep), "-MT",
                 str(obj), "-c", str(source), "-o", str(temp_obj)],
                check=False, capture_output=True, text=True,
            )
            if proc.returncode:
                raise RuntimeError(
                    f"{source}: compiler exited {proc.returncode}\n{proc.stdout}{proc.stderr}"
                )
            # Install both outputs before calculating the final dependency
            # checksum. On interruption a missing marker forces recompilation.
            marker.unlink(missing_ok=True)
            os.replace(temp_obj, obj)
            os.replace(temp_dep, dep)
            new_sig = signature(source, dep)
            if new_sig is None:
                raise RuntimeError(f"{source}: GCC produced no dependencies")
            marker.write_text(new_sig + "\n")
            return "built", source
        finally:
            temp_obj.unlink(missing_ok=True)
            temp_dep.unlink(missing_ok=True)

    reused = built = 0
    print(f"ARM64 incremental build: {len(jobspecs)} files, {jobs} parallel job(s)", flush=True)
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = [pool.submit(compile_one, spec) for spec in jobspecs]
        failures = []
        for future in as_completed(futures):
            try:
                status, source = future.result()
                if status == "built":
                    built += 1
                    print(f"[{built} built] {source.name}", flush=True)
                else:
                    reused += 1
            except Exception as exc:
                failures.append(str(exc))
        if failures:
            for failure in failures:
                print(failure, file=sys.stderr)
            print(f"Compilation failed in {len(failures)} source(s)", file=sys.stderr)
            return 1
    print(f"ARM64 result: {built} compiled, {reused} reused", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
