"""Erzeugt FUNCTION_MATRIX.md und function_matrix.csv aus den Teil-Dateien m1..m5."""
import csv, importlib.util, pathlib, sys
here = pathlib.Path(__file__).parent
parts = [("Hauptfenster, Fenster, Werkzeugleiste, Register, Statusleiste", "m1_ui"),
         ("Menüs Datei, Bearbeiten, Ansicht, Bild, Ebenen, Hilfe", "m2_menus"),
         ("Werkzeuge, Farben, Verlauf, Ebenenfenster", "m3_tools"),
         ("Korrekturen und Effekte", "m4_adj_fx"),
         ("Einstellungen, Mischmodi, Formate, Tastatur, Plugins, Mac-Ergänzungen", "m5_misc")]
head = ["Funktions-ID", "Menüpfad", "Beschreibung", "Referenzverhalten", "Erforderliche Eingaben", "Standardwerte",
        "Zustandsänderung", "Fehlerfälle", "Mac-Umsetzung", "Testfall", "Status"]
STATUS = "nicht implementiert"
rows_all, sections, ids = [], [], set()
for title, mod in parts:
    spec = importlib.util.spec_from_file_location(mod, here / f"{mod}.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    rows = []
    for r in m.ROWS:
        assert len(r) == 10, (r[0], len(r))
        assert r[0] not in ids, "doppelte ID " + r[0]; ids.add(r[0])
        rows.append(list(r) + [STATUS])
    sections.append((title, rows)); rows_all += rows
esc = lambda s: str(s).replace("|", "\\|").replace("\n", " ")
unk = sum(1 for r in rows_all if "ungeklärt" in " ".join(r))
out = [
"# FUNCTION_MATRIX.md",
"",
"**Referenz:** Paint.NET 5.1.12 · **Quelle:** offizielle Dokumentation paint.net/doc/latest (57 Seiten, abgerufen 04.11.2026), Menü-Screenshots der Doku (Texterkennung), Release-Notes 5.0/5.1. Seitennamen in Klammern verweisen auf `https://paint.net/doc/latest/<Seite>.html`.",
"",
f"**Umfang:** {len(rows_all)} Funktionen · davon {unk} mit mindestens einem als **ungeklärt** markierten Punkt · Status aller Einträge: *{STATUS}* (Phase 1).",
"",
"## Lesehinweise",
"- **Standardwerte:** Die Dokumentation nennt fast keine Standardwerte und keine Wertebereiche. Werte aus Screenshots sind als *Beispiel* bzw. *Screenshot-Zustand* gekennzeichnet und **nicht** als Werkseinstellung belegt. Sie werden erst nach Messung an einer echten Paint.NET-5.1.12-Installation übernommen (siehe KNOWN_ISSUES, Punkt R-1).",
"- **Widersprüche in der Doku** sind vermerkt (z. B. Startwerkzeug Pinsel vs. Rechteckauswahl, AVIF-Maximalgröße, ältere Seiten mit „9 Korrekturen / 33 Effekte“ gegenüber aktuellem Menü mit 13 Korrekturen und 40 Effekten in 9 Untermenüs).",
"- **Tastenkürzel:** Strg → Cmd, Alt → Option. Konflikte mit macOS-Systemkürzeln sind in der Spalte *Mac-Umsetzung* und in KNOWN_ISSUES aufgeführt.",
"- **Status-Stufen** (Abschnitt 34): implementiert und getestet · implementiert, nicht getestet · teilweise implementiert · nicht implementiert · technisch nicht möglich · wegen fehlender Referenz ungeklärt.",
"- Maschinenlesbare Fassung: `function_matrix.csv` (gleiche Spalten).",
"",
]
for title, rows in sections:
    out += [f"## {title} ({len(rows)})", "", "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(esc(c) for c in r) + " |" for r in rows]
    out.append("")
dst = here.parent
(dst / "FUNCTION_MATRIX.md").write_text("\n".join(out))
with open(dst / "function_matrix.csv", "w", newline="") as f:
    w = csv.writer(f, delimiter=";"); w.writerow(head); w.writerows(rows_all)
print(len(rows_all), "Funktionen,", unk, "mit ungeklärten Punkten")
