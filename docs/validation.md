# Lokale validatie — 9 november 2026

Omgeving: Docker Desktop op een Linux AMD64-host. ARM64 is gebouwd en getest onder emulatie.

| Controle | Resultaat |
| --- | --- |
| AMD64-build | Geslaagd; lokale tag `dfirdocker:local` |
| ARM64-build | Geslaagd; lokale tag `dfirdocker:arm64-test` |
| Volatility 3 2.28.2 | Op beide architecturen laden alle 197 ingebouwde plugins zonder importfouten |
| Full-dependencies | Imports van YARA, Capstone, PyCryptodome, LeechCore en Pillow slagen |
| MultiYara | Import en CLI-help slagen op beide architecturen; inhoudelijke analyse niet gevalideerd |
| Synthetische tests | YARA-matching, SQLite-query, strings, SHA-256 en verwerking van een geldig leeg PCAP slagen op beide architecturen |
| Launcher op AMD64 | Schrijven naar de evidence-mount wordt geweigerd met `EROFS`; output blijft op de host met UID 1000; cache en gedownloade-symbolenmap zijn schrijfbaar |
| Netwerk launcher | Verbinding naar een extern IP faalt met `ENETUNREACH` bij de standaardinstelling `--network none` |
| Dockerfile | `docker build --check` slaagt zonder waarschuwingen |
| Workflow | `actionlint` 1.7.12 slaagt |
| Scripts | Bash-/POSIX-shellsyntaxis en Python-parsing slagen |

De ARM64-build compileert LeechCore uit broncode; daarvoor bevat de builder onder meer `build-essential`, `pkg-config` en `libusb-1.0-0-dev`. Deze buildtools worden niet naar de runtime-image gekopieerd.

Lokaal gebouwde image-ID's:

- AMD64: `sha256:18e832f4d35d54be5047431f7cbc6e61f1e7f38b7e665363d6c5a7ac76a1d61f`
- ARM64: `sha256:19b9c333fd20fd0059bfd99d3684c913edb64a05461c1f5fe351944707fbae3e`

Dit zijn lokale image-ID's, geen gepubliceerde GHCR-digests. GitHub Actions en GHCR-publicatie zijn tijdens deze lokale controle niet uitgevoerd. Er zijn geen echte geheugendumps of casusbestanden gebruikt. Pluginimports en synthetische tests bewijzen niet dat iedere plugin elk type evidence correct verwerkt.

## Herhalen

```bash
docker build --check .
docker build --platform linux/amd64 -t dfirdocker:local .
docker run --rm --network none dfirdocker:local python /opt/dfir/smoke.py
docker build --platform linux/arm64 -t dfirdocker:arm64-test .
```

De `RUN python /opt/dfir/smoke.py`-stap in de Dockerfile test iedere doelarchitectuur. Gebruik `--no-cache` als je die stap opnieuw wilt uitvoeren bij een verder ongewijzigde build. Voor ARM64 op een AMD64-host is emulatie nodig; Docker Desktop bood die tijdens deze controle aan.
