#!/usr/bin/env python3
"""Готовит update.json — описание версии, по которому программа находит обновление.

Файл выкладывается на сайт рядом с программой. Поля:
  build       — номер сборки, программа сравнивает его со своим;
  version     — что показать человеку;
  url/sha256  — самораспаковывающийся файл и его контрольная сумма;
  msi_url/msi_sha256 — то же для пакета MSI (им обновляются копии, поставленные пакетом);
  notes       — что изменилось.

Запуск: python eleroz/make_update_json.py --build 7 --version 1.4.9 \
        --dir SignOutput --base https://eleroz.ru/upload/eleroz-connect/ --out SignOutput/update.json
"""
import argparse
import hashlib
import json
import pathlib
import sys


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=int)
    parser.add_argument("--version", required=True)
    parser.add_argument("--dir", required=True, help="папка с готовыми файлами")
    parser.add_argument("--base", required=True, help="адрес папки на сайте")
    parser.add_argument("--out", required=True)
    parser.add_argument("--notes", default="")
    args = parser.parse_args()

    folder = pathlib.Path(args.dir)
    base = args.base if args.base.endswith("/") else args.base + "/"
    manifest = {"build": args.build, "version": args.version, "notes": args.notes}

    for pattern, url_key, sum_key in (("*.exe", "url", "sha256"), ("*.msi", "msi_url", "msi_sha256")):
        files = sorted(folder.glob(pattern))
        if not files:
            continue
        if len(files) > 1:
            print(f"ERROR: more than one {pattern} in {folder}", file=sys.stderr)
            return 1
        manifest[url_key] = base + files[0].name
        manifest[sum_key] = sha256(files[0])

    if "url" not in manifest:
        print(f"ERROR: no exe in {folder}", file=sys.stderr)
        return 1

    pathlib.Path(args.out).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"update.json: build {args.build}, {manifest['url']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
