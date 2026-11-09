# Communityplugincontrole

Gecontroleerd op 9 november 2026 met Volatility 3 2.28.2, Python 3.12 en de Linux AMD64-image. De volledige broncollectie staat onder `/opt/community3`; deze tabel beschrijft enkele daadwerkelijk gecontroleerde pluginmappen, niet alle externe projecten waarnaar de collectie verwijst.

| Map | Bevinding |
| --- | --- |
| `Silva_Multi_Yara` | Import en `multiyara.MultiYara --help` werken met de toegevoegde dependency `pygit2`. Er verschijnt een waarschuwing over de verouderde `PluginRequirement`-API. De broncode bevat vaste Windows- en `/yara`-paden; de analysefunctionaliteit is niet gevalideerd. |
| `Stelte_Evtx` | Import faalt: verwijst naar het oude Python-package `volatility`. De aparte tool `evtx_dump` is wel geïnstalleerd voor EVTX-bestanden op schijf; die vervangt geen geheugen-carvingplugin. |
| `Gerhart_Hyper_V` | Verwacht onder meer `hvlib`, de Windows-module `msvcrt` en aangepaste Hyper-V-lagen. Geen werkende Linux-plugininstallatie in deze image. |
| `Sheffer_Shaked_Docker/plugins` | Verwacht oudere Linux-plugins en symbolen, waaronder `linux.mount` en `net_device`. De meegeleverde frameworkpatches worden niet over de actuele Volatility-installatie gekopieerd. |
| `Moreira_Mountinfo/vol3_mountinfo_plugin_files/volatility/framework/plugins/linux` | Import faalt door een verwijzing naar het oude package `volatility`. De huidige ingebouwde Linux-plugins blijven beschikbaar. |

De build faalt bij een importprobleem in de **ingebouwde** Volatility-plugins. Voor de extra MultiYara-plugin wordt ook de helpaanroep getest. De overige communitybestanden zijn beschikbaar voor afzonderlijke beoordeling, aanpassing en uitbreiding; ze worden niet automatisch in de standaardpluginset geladen.

Voorbeeld voor diagnose:

```bash
./scripts/dfir vol-community Stelte_Evtx -vv --help
```

Upstream beschrijft dezelfde beperkingen in de [community3 README](https://github.com/volatilityfoundation/community3). Er zijn geen echte geheugendumps gebruikt om de community-analyseresultaten te valideren.
