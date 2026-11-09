"""Exercise plugin discovery and small forensic operations without real evidence."""
import hashlib
import importlib
import pathlib
import shutil
import sqlite3
import subprocess
import tempfile

from volatility3 import framework, plugins
import yara


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)


failures = framework.import_files(plugins, True)
assert not failures, f"Built-in plugins could not load: {failures}"
available = framework.list_plugins()
for name in ("windows.info.Info", "windows.pslist.PsList", "linux.pslist.PsList",
             "mac.pslist.PsList", "yarascan.YaraScan"):
    assert name in available, f"Missing plugin: {name}"
for module in ("capstone", "Crypto", "leechcorepyc", "PIL.Image", "Evtx.Evtx", "regipy", "oletools.olevba"):
    importlib.import_module(module)
for command in ("vol", "volshell", "tshark", "capinfos", "fls", "mmls", "icat",
                "ewfinfo", "yara", "exiftool", "sqlite3", "strings", "jq", "rg",
                "olevba", "regipy-parse-header", "evtx_dump"):
    assert shutil.which(command), f"Missing executable: {command}"
help_text = run("vol", "--help")
assert "windows.pslist.PsList" in help_text
assert "could not be loaded" not in help_text, help_text
community_help = run("vol-community", "Silva_Multi_Yara", "multiyara.MultiYara", "--help")
assert "--yara-file" in community_help
with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    sample = root / "sample.txt"
    sample.write_bytes(b"DFIR_SMOKE_TEST\n")
    rules = yara.compile(source='rule smoke { strings: $a = "DFIR_SMOKE_TEST" condition: $a }')
    assert rules.match(str(sample))
    assert "DFIR_SMOKE_TEST" in run("strings", str(sample))
    assert hashlib.sha256(sample.read_bytes()).hexdigest() in run("sha256sum", str(sample))
    db = root / "sample.db"
    with sqlite3.connect(db) as connection:
        connection.execute("CREATE TABLE evidence (name TEXT)")
        connection.execute("INSERT INTO evidence VALUES ('smoke')")
    assert run("sqlite3", str(db), "SELECT name FROM evidence;").strip() == "smoke"
    # A valid empty little-endian Ethernet PCAP, processed without capture privileges.
    capture = root / "empty.pcap"
    capture.write_bytes(bytes.fromhex("d4c3b2a1020004000000000000000000ffff000001000000"))
    assert run("tshark", "-r", str(capture), "-T", "fields", "-e", "frame.number").strip() == ""
print(f"Smoke test passed: {len(available)} built-in Volatility plugins load; YARA, SQLite, strings, hashing and PCAP parsing work.")
