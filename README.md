# DFIRdocker

Een Docker-toolbox voor Digital Forensics & Incident Response, met Volatility 3 als basis. Geschikt voor onderzoek van bestaande evidence en voor DFIR-labs.

## Tools

| Onderzoek | Tools |
| --- | --- |
| Geheugen | Volatility 3 **2.28.2**, alle ingebouwde plugins, `volshell` en de officiële `full`-dependencies: YARA-Python, Capstone, PyCryptodome, Pillow en LeechCore |
| Communityplugins | Snapshot van `volatilityfoundation/community3`, op commit `5ae4e232e14667277a0cc74848b87b634b4d8ad1`, onder `/opt/community3`; extra dependency `pygit2` voor MultiYara |
| Schijfimages | The Sleuth Kit (`mmls`, `fls`, `icat`, …), `ewfinfo`, `ewfexport` |
| Windows-artefacten | `python-evtx`, Regipy |
| Bestanden | YARA, ExifTool, `file`, `strings`, SHA-256, SQLite |
| Netwerkcaptures | TShark en `capinfos` voor bestaande PCAP-bestanden |
| Office-documenten | oletools, waaronder `olevba` |
| Hulpmiddelen | Bash, Python 3.12, jq, ripgrep, curl, 7-Zip, unzip |

**“Alle plugins” betekent hier alle ingebouwde plugins van de vastgelegde Volatility 3-versie.** De volledige communityrepository wordt daarnaast meegeleverd als bronarchief. Die collectie bevat ook verwijzingen naar externe projecten, ZIP-bestanden en frameworkaanpassingen; externe projecten achter die links worden niet automatisch geïnstalleerd. De upstreambeheerder garandeert geen compatibiliteit. Communityplugins worden daarom per map geladen, zodat een oude plugin de standaardtools niet verstoort. Plugins voor Volatility 2/Python 2 zijn niet compatibel met Volatility 3.

## Lokaal bouwen

```bash
cd /home/colo/Public/DFIRdocker
docker build --check .
docker build -t dfirdocker:local .
docker run --rm --network none dfirdocker:local python /opt/dfir/smoke.py
```

Docker moet draaien. Als je Docker Desktop gebruikt terwijl je actieve context naar een andere daemon verwijst, zet dan voor deze terminal:

```bash
export DOCKER_CONTEXT=desktop-linux
```

De build voert zelf ook de smoke-test uit. Die controleert dat de ingebouwde plugins laden en test YARA-matching, SQLite, strings, hashing en PCAP-verwerking met kleine synthetische bestanden. Dat is geen validatie van analyseresultaten op echte geheugendumps.

De uitgevoerde lokale controles staan in [docs/validation.md](docs/validation.md).

## Een onderzoek starten

```bash
# Maakt case/evidence, case/output, case/symbols, case/plugins en case/cache aan.
./scripts/dfir vol --help
```

Plaats vervolgens een **werkkopie** van je evidence in `case/evidence/`. Deze map is alleen-lezen in de container. Bewaar het origineel afzonderlijk en noteer de hashes. `case/` wordt uitgesloten van Git én van de Docker-buildcontext.

```bash
./scripts/dfir sha256sum /evidence/memory.raw

# Eerste Windows-analyse: tijdelijke netwerktoegang voor ontbrekende symbolen.
DFIR_NETWORK=bridge ./scripts/dfir vol -f /evidence/memory.raw windows.info

# Vervolgonderzoek met opgeslagen symbolen/cache en zonder netwerk.
./scripts/dfir vol --offline -f /evidence/memory.raw windows.pslist
./scripts/dfir vol --offline -f /evidence/memory.raw windows.pstree
./scripts/dfir vol --offline -f /evidence/memory.raw windows.netscan

# JSON-output op de host opslaan.
./scripts/dfir vol --offline -r json -f /evidence/memory.raw windows.pslist \
  > case/output/pslist.json

# Bestanden die een plugin dumpt, blijven ook op de host bewaard.
./scripts/dfir vol --offline -f /evidence/memory.raw -o /output windows.dumpfiles --pid 1234

# Andere tools.
./scripts/dfir tshark -r /evidence/traffic.pcapng -q -z conv,tcp
./scripts/dfir fls -r /evidence/disk.img
./scripts/dfir exiftool /evidence/document.pdf
./scripts/dfir olevba /evidence/document.docm
./scripts/dfir evtx_dump /evidence/Security.evtx > case/output/Security.xml

# Interactieve shell; typ exit om af te sluiten.
./scripts/dfir
```

De launcher gebruikt je eigen UID/GID zodat outputbestanden van jou blijven. Hij gebruikt standaard geen netwerk, verwijdert Linux-capabilities en geeft geen toegang tot hostdevices of de Docker-socket. Er is geen `--privileged` nodig voor analyse van bestaande bestanden.

Met een afzonderlijke casemap en een gepubliceerde image:

```bash
export DFIR_CASE_DIR=/home/colo/DFIR-cases/case-001
export DFIR_IMAGE=ghcr.io/elidiocolonnapxl/dfirdocker:latest
docker pull "$DFIR_IMAGE"
./scripts/dfir vol --help
```

| Hostmap in de case | In de container | Toegang |
| --- | --- | --- |
| `evidence/` | `/evidence` | Alleen-lezen |
| `output/` | `/output` | Lezen/schrijven, standaardwerkmap |
| `symbols/` | `/symbols` | Alleen-lezen, eigen symbolentabellen |
| `plugins/` | `/plugins` | Alleen-lezen, eigen Volatility 3-plugins |
| `cache/` | `/cache` | Lezen/schrijven, herbruikbare Volatility-cache en gedownloade symbolen |

## Symbolen en plugins

Een geïnstalleerde plugin heeft nog steeds passende evidence en symbolen nodig. Windows-symbolen kunnen bij de eerste analyse via internet worden opgehaald. Voor Linux en macOS heb je symbolentabellen nodig die bij de kernel passen; een universele verzameling voor elke kernel bestaat niet. Plaats ze onder `case/symbols/`, bijvoorbeeld in `linux/` of `mac/`. Zie de [officiële uitleg over symbolen](https://github.com/volatilityfoundation/volatility3#symbol-tables).

```bash
# Ingebouwde plugins en opties.
./scripts/dfir vol --help
./scripts/dfir vol windows.pslist --help

# Meegeleverde communitybroncode bekijken.
./scripts/dfir vol-community --list
./scripts/dfir ls /opt/community3

# MultiYara kan worden geladen; de CLI-help wordt tijdens de build getest.
./scripts/dfir vol-community Silva_Multi_Yara multiyara.MultiYara --help

# Een specifieke collectie laden en importfouten onderzoeken.
# Dit is een compatibiliteitscontrole, geen garantie dat de oude plugin werkt.
./scripts/dfir vol-community Stelte_Evtx -vv --help
```

Eigen plugins in `case/plugins/` worden door `vol` automatisch geladen. `vol`, `vol3` en `volatility3` zijn aliassen met dezelfde standaardpaden. `vol-community` selecteert uitsluitend de opgegeven communitymap naast de ingebouwde plugins. Lees de README van de auteur voor extra dependencies en eventuele vereiste frameworkwijzigingen.

Zie [de concrete communitycontrole](docs/community-compatibility.md) voor gevonden beperkingen. Een geslaagde import of helpaanroep bewijst nog geen correcte analyse.

## GitHub Actions en GHCR

De workflow sluit aan bij het lab **Publish an image with GitHub Actions**:

1. Iedere branchpush en pull request naar `main` bouwt voor `linux/amd64` en `linux/arm64`.
2. De smoke-test draait tijdens beide platformbuilds. Een mislukte test blokkeert publicatie.
3. Alleen een push naar `main` of een handmatige run op `main` publiceert naar GitHub Container Registry (GHCR).
4. De tags zijn `latest` en `sha-<volledige Git-commit>`. De publicatie bevat buildprovenance en een SBOM.

De image heet `ghcr.io/elidiocolonnapxl/dfirdocker`. De workflow gebruikt automatisch `GITHUB_TOKEN` met `packages: write`; je hoeft geen Docker Hub-account of extra repositorysecret toe te voegen. De OCI-source-label koppelt het package aan deze repository.

Een nieuw GHCR-package is standaard **private**, ook bij een publieke bronrepository. Voor anoniem downloaden moet je na de eerste publicatie bij het package via **Package settings → Change visibility → Public** de zichtbaarheid aanpassen. Laat het private als je alleen zelf toegang wilt. Voor het downloaden van een private image meld je je lokaal aan met een personal access token (classic) met `read:packages`; voer dat interactief in met `docker login ghcr.io -u ElidioColonnaPXL`. Zet nooit tokens of evidence in de repository.

Commit en push de projectbestanden op je featurebranch en open een pull request naar `main`. De branch- en PR-builds controleren de image. Zodra de wijzigingen op `main` staan, bouwt en publiceert de workflow de image. Volg de uitvoering via het [Actions-tabblad](https://github.com/ElidioColonnaPXL/DFIRdocker/actions).

Na een geslaagde publicatie:

```bash
docker buildx imagetools inspect ghcr.io/elidiocolonnapxl/dfirdocker:latest
docker pull ghcr.io/elidiocolonnapxl/dfirdocker:latest
docker run --rm --network none ghcr.io/elidiocolonnapxl/dfirdocker:latest vol --help
```

## Versies en licenties

Directe Python-dependencies staan vast in `requirements.txt`; de communitysnapshot staat vast op een commit en de Python-basisimage op een digest. Transitive dependencies en Debian-pakketten kunnen veranderen bij een nieuwe build. Bewaar voor reproduceerbaar onderzoek de gebruikte **image digest**, naast evidencehashes en commando's. De image bevat de feitelijke pakketversies in `/opt/dfir/python-packages.txt` en `/opt/dfir/debian-packages.txt`.

De repositorybestanden vallen onder de bestaande MIT-licentie. Meegeleverde tools en communitybestanden behouden hun eigen licenties; de repositorylicentie herlicentieert die tools niet.

Bronnen: [Volatility 3](https://github.com/volatilityfoundation/volatility3), [community3 en compatibiliteitswaarschuwing](https://github.com/volatilityfoundation/community3), [Docker: multi-platform GitHub Actions](https://docs.docker.com/build/ci/github-actions/multi-platform/), [GitHub: Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
