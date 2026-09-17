#!/usr/bin/env python3
"""Готовит MSI ЭЛЕРОЗ Коннект: зовёт res/msi/preprocess.py с нашими названиями.

Названия лежат здесь, а не в сценарии сборки: кириллица через YAML и оболочку
Windows доходит по-разному, а из Python она передаётся процессу как есть.

Запуск из корня репозитория: python eleroz/build_msi.py <версия>
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MSI_DIR = ROOT / "res" / "msi"

APP_NAME = "ElerozConnect"  # папка установки, служба, файл программы
DISPLAY_NAME = "ЭЛЕРОЗ Коннект"  # то, что видит человек
VENDOR = "ЭЛЕРОЗ"
SITE = "https://eleroz.ru/udalennaya-pomoshch/"
SOURCES = "https://github.com/eleroz/eleroz-connect"

# Строки для «Программ и компонентов»
ARP = {
    "Comments": {"msi": "ARPCOMMENTS", "t": "string", "v": "!(loc.AR_Comment)"},
    "Contact": {"msi": "ARPCONTACT", "v": SITE},
    "HelpLink": {"msi": "ARPHELPLINK", "v": SITE},
    "ReadMe": {"msi": "ARPREADME", "v": SOURCES},
}


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else ""
    cmd = [
        sys.executable,
        "preprocess.py",
        "--arp",
        "-d",
        "../../rustdesk",
        "--app-name",
        APP_NAME,
        "--display-name",
        DISPLAY_NAME,
        "-m",
        VENDOR,
        "--custom-arp",
        json.dumps(ARP, ensure_ascii=True),
    ]
    if version:
        cmd += ["-v", version]
    print(f"msi preprocess: app={APP_NAME}, version={version or 'from exe'}")
    subprocess.run(cmd, cwd=MSI_DIR, check=True)


if __name__ == "__main__":
    main()
