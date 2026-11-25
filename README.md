# SkyMap64 v1.1 – osobní planetárium pro C64

*English version: see [README_EN.md](README_EN.md).*

SkyMap64 zobrazí hvězdnou oblohu ve stylu SkySafari na Commodore 64. Zobrazí oblohu pro zadané datum, čas a místo. Ukáže 1041 hvězd do 4,5 magnitudy, čáry a české názvy 89 souhvězdí, jména jasných hvězd, všech 110 objektů Messierova katalogu, Slunce, Měsíc a planety Merkur až Saturn. K tomu obzor se zemí, světové strany a denní modrou oblohu, když je Slunce nad obzorem.

## Spuštění

**Emulátor VICE:** otevřete `skymap64.d64` (nebo přímo `skymap64.prg`) přes *File → Smart attach*, případně spusťte `x64sc skymap64.d64`.

**Skutečné C64:** nahrajte `skymap64.d64` na SD2IEC, Ultimate, Kung Fu Flash apod. a pak:

```
LOAD"SKYMAP64",8
RUN
```

Program má asi 30 kB. Z obyčejné 1541 bez fastloaderu se nahrává zhruba minutu.

## Úvodní obrazovka a zadání údajů

Po spuštění se objeví úvodní obrazovka s logem SkyMap64 a označením verze. Pokračuje se klávesou RETURN.


Po spuštění se program zeptá na den, měsíc, rok, hodinu, minutu, časové pásmo a zeměpisnou polohu. **RETURN ponechá zobrazenou hodnotu.** Výchozí je Praha (50,08° s. š., 14,42° v. d.).

- Časové pásmo: v zimě `1` (SEČ), v létě `2` (SELČ).
- Zeměpisná šířka je kladná na severní polokouli, délka kladná na východ od Greenwiche.

Po zadání se zobrazí návod k ovládání a za 3 sekundy výzva „stiskni klávesu“. Po stisku se objeví nápis „Počítám polohy těles“. V BASICu se spočítají polohy Slunce, Měsíce a planet a časy západů (dohromady asi 23 sekund). Pak se ukáže přehled západů a po další klávese obloha.

## Ovládání

| Klávesa | Funkce |
|---|---|
| kurzorové klávesy / joystick v portu 2 | otáčení pohledu |
| `+` `-` | přiblížit / oddálit (zorné pole 120°, 90°, 60°, 40°, 25°, 15°) |
| `S` `V` `J` `Z` | pohled na sever / východ / jih / západ |
| `,` `.` | čas −/+ 10 minut |
| `:` `;` | čas −/+ 1 hodina |
| `RETURN` | přepočítat polohy planet pro aktuální čas |
| `H` | hledat objekt (viz níže) |
| `I` | přehled: západ Slunce, astronomická noc, západ Měsíce |
| `C` | zapnout/vypnout čáry souhvězdí |
| `N` | zapnout/vypnout názvy |
| `M` | zapnout/vypnout Messierovy objekty |
| `D` | nové datum, čas nebo místo |
| `Q` | konec |

Spodní řádek ukazuje směr pohledu a azimut, výšku nad obzorem, zorné pole, datum a čas, například `JV 135° VYS+30° ZP 90° 24.11.2026 22:00`. Datum se při posouvání času mění i přes konec měsíce a roku. **Hvězdička `*`** znamená, že jste posunuli čas, ale planety a Měsíc jsou pořád spočítané pro původní čas. Hvězdy se pohybují správně, planety přepočítá RETURN.

Jedno překreslení oblohy trvá asi 2,5 sekundy.

## Hvězdy a Messierovy objekty

Kolik hvězd je vidět, záleží na zorném poli: při 120° hvězdy do 4,0 mag, při 90° do 4,5 mag, od 60° všechny včetně slabších hvězd ve vrcholech čar souhvězdí.

Messierovy objekty se kreslí od zorného pole 90° níž a mají zelené popisky (M31, M42…). Značka podle typu:

- ovál – galaxie,
- tečkovaný kroužek – otevřená hvězdokupa,
- kroužek s křížkem – kulová hvězdokupa,
- čtvereček – mlhovina (difuzní, planetární, pozůstatek supernovy).

## Západy a astronomická noc

Přehled (při startu a klávesou `I`) ukazuje pro zadané datum a místo:

- **západ Slunce**: horní okraj na obzoru, se započtenou refrakcí (výška středu −0,833°),
- **astronomickou noc**: od večerního do ranního průchodu Slunce 18° pod obzorem. V Praze kolem letního slunovratu nenastává, protože Slunce klesne jen na −16,5°, a program pak napíše „nenastává“,
- **západ Měsíce**: nejbližší západ po zadaném čase (výška středu +0,125°, zahrnuje paralaxu, refrakci a poloměr).

Pokud událost nastane až další den, je u ní „(zítra)“. Časy se počítají iterací hodinového úhlu se zjednodušenými vzorci pro Slunce a Měsíc. Proti PyEphem sedí na 1 minutu. Když jste posunul čas, klávesa `I` nejdřív vše přepočítá pro nový čas (asi 23 s). Jinak se přehled ukáže hned.

## Hledání objektů

Po stisku `H` napište do spodního řádku název a potvrďte RETURN. Pohled se natočí na objekt a ten se označí zaměřovacím kroužkem. Stačí začátek názvu: `MAR` najde Mars, `VEL` Velkou medvědici. Messierovy objekty se hledají přesným označením bez mezery, například `M31` nebo `M45`. Hledá se v tomto pořadí: planety (SLUNCE, MESIC, MERKUR, VENUSE, MARS, JUPITER, SATURN), pojmenované hvězdy (SIRIUS, VEGA, POLARKA…), Messierovy objekty a souhvězdí (ORION, LABUT, KASIOPEJA…). Na klávesnici C64 se píše bez diakritiky a hledání ji ignoruje: `LABUT` najde LABUŤ, `POLAR` POLÁRKU. DEL maže, RUN/STOP nebo `←` ruší hledání. Prázdné hledání potvrzené RETURN zaměřovač odstraní. Když je objekt pod obzorem, pohled se sklopí nejvýš na −20° a kroužek ukáže jeho polohu pod zemí.

## Přesnost

V emulátoru jsem polohy ověřil proti knihovně PyEphem. Hvězdy a obzor sedí na 1–3 pixely. Planety používají zjednodušené Keplerovy dráhy (vzorce Paula Schlytera) s přesností zhruba do 1°. Měsíc zahrnuje hlavní poruchové členy a paralaxu pozorovatele. Program se hodí na orientaci na obloze, ne na přesná měření.

## Jak to funguje

- **BASIC** (řádky 10–3200) načte údaje, spočítá hvězdný čas a jednotkové vektory Slunce, Měsíce a planet a předá je strojovému kódu přes paměť od `$2003` (`SYS 8192`).
- **Strojový kód 6502** (`planet.asm`, assembler ACME):
  - hires bitmapa 320×200 na `$E000`, VIC banka 3,
  - výpočty v pevné řádové čárce s1.14,
  - rychlé násobení čtvrtinovými čtverci se samomodifikujícím kódem,
  - stereografická projekce (jako SkySafari),
  - hvězdy rozdělené do 40 zón pro rychlé vyřazení neviditelných oblastí,
  - čáry ořezávané dělením úsečky a kreslené Bresenhamovým algoritmem,
  - země se barví po buňkách 8×8 podle výšky jejich středu nad obzorem.
- Data obsahují 1041 hvězd (včetně slabších hvězd ve vrcholech čar), 743 úseček souhvězdí, 89 názvů souhvězdí a 110 Messierových objektů. Písmo je vlastní, nepoužívá znakovou ROM. Obsahuje všechna česká velká písmena s diakritikou (Á Č Ď É Ě Í Ň Ó Ř Š Ť Ú Ů Ý Ž) na kódech 96–110, takže názvy souhvězdí, hvězd a planet se v grafice píšou česky (LABUŤ, POLÁRKA, MĚSÍC…). Textové obrazovky BASICu (zadání údajů, návod) používají znakovou ROM C64, a proto zůstávají bez diakritiky.

Mapa paměti: BASIC `$0801`, strojový kód a data `$2000–$96F0`, pracovní pole hvězd `$A000` (pod ROM BASICu), tabulky `$C000–$CBFF`, barvy `$CC00`, bitmapa `$E000`.

## Anglická verze

Na disketě `skymap64en.d64` (soubor `SKYMAP64EN`) je samostatná anglická verze. Má latinské názvy souhvězdí (URSA MAJOR, CYGNUS…), anglická jména hvězd a planet, datum ve formátu RRRR-MM-DD a výchozí místo Greenwich (51,48° s. š., 0°, UTC+0). Klávesy se v ní liší: světové strany jsou `N E S W`, názvy se přepínají klávesou `L` a hledá se klávesou `F`.

## Sestavení ze zdrojáků

Potřebujete `acme`, `petcat` a `c1541` (z balíku VICE) a Python 3 s NumPy.

```
cd src
./build.sh
```

Skript vyrobí obě jazykové verze z jednoho zdrojáku. Jazyk vybírá přepínač `LANG` v assembleru (`acme -DLANG=1` = anglicky) a proměnná `SKYLANG` pro `gen_data.py`. Anglický BASIC `planet_en.bas` vzniká z českého skriptem `make_en_bas.py`, který jen přeloží texty.

Skript `gen_data.py` vyrábí `data.asm` z JSON dat projektu [d3-celestial](https://github.com/ofrohn/d3-celestial): `stars.6.json`, `constellations.lines.json`, `constellations.json` a `messier.json` uložené ve složce `data/` vedle `src/`. Do stejné složky patří i `title.svg` (návrh úvodní obrazovky, přiložený v `src/`), ze kterého se berou hvězdy a čáry na úvodní obrazovce. Vygenerovaný `data.asm` je přiložený, takže pro samotný překlad assembleru JSON soubory nepotřebujete.

## Zdroje dat

- Hvězdy, čáry a názvy souhvězdí, Messierův katalog: d3-celestial (licence BSD-3), vychází z katalogu Hipparcos a ze Stellaria.
- Vzorce pro planety: Paul Schlyter, *How to compute planetary positions*.

## Historie verzí

- **1.1** – přehled časů: západ Slunce, astronomická noc (začátek a konec), západ Měsíce (klávesa `I`). Návod ve dvou sloupcích s popisy žlutě, nápis „Počítám polohy těles“, rychlejší řešení Keplerovy rovnice. Nová samostatná anglická verze.
- **1.0** – první vydání: hvězdy do 4,5 mag, 89 souhvězdí s českými názvy včetně diakritiky, Slunce, Měsíc a planety, Messierův katalog, hledání objektů, datum a čas ve stavovém řádku, úvodní obrazovka.
