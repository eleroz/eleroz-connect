"""ЭЛЕРОЗ Коннект: брендирование подмодуля libs/hbb_common перед сборкой.

Подмодуль берётся из официального репозитория RustDesk без изменений, поэтому
название, сервер и ключ задаются здесь. Скрипт падает, если нужная строка
не найдена ровно один раз: молча собрать программу с чужим сервером нельзя.
"""
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG = ROOT / "libs" / "hbb_common" / "src" / "config.rs"
BUILD_FILE = ROOT / "src" / "eleroz_build.rs"

REPLACEMENTS = [
    (
        'pub static ref APP_NAME: RwLock<String> = RwLock::new("RustDesk".to_owned());',
        'pub static ref APP_NAME: RwLock<String> = RwLock::new("ElerozConnect".to_owned());',
    ),
    (
        'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];',
        'pub const RENDEZVOUS_SERVERS: &[&str] = &["connect.eleroz.com"];',
    ),
    (
        'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";',
        'pub const RS_PUB_KEY: &str = "WoplkmUEldqZorDC4MBK+ddFXZEAcnkS9umzrb3m7Rc=";',
    ),
    (
        "pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
        'pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(['
        '("allow-auto-update".to_owned(), "Y".to_owned())]));',
    ),
    (
        "pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
        'pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from(['
        '("disable-ab".to_owned(), "Y".to_owned()), ("disable-account".to_owned(), "Y".to_owned())]));',
    ),
    (
        "pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
        'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("hide-powered-by-me".to_owned(), "Y".to_owned())]));',
    ),
]


def write_build_number() -> int:
    """Номер сборки из CI: по нему программа сравнивает себя с версией на сайте."""
    build = os.environ.get("ELEROZ_BUILD", "0").strip() or "0"
    if not build.isdigit():
        print(f"ERROR: ELEROZ_BUILD is not a number: {build}", file=sys.stderr)
        return -1
    text = BUILD_FILE.read_text(encoding="utf-8")
    lines = [
        line if not line.startswith("pub const BUILD") else f"pub const BUILD: u32 = {build};"
        for line in text.splitlines()
    ]
    BUILD_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return int(build)


def main() -> int:
    build = write_build_number()
    if build < 0:
        return 1
    text = CONFIG.read_text(encoding="utf-8")
    for old, new in REPLACEMENTS:
        if new in text:
            continue
        found = text.count(old)
        if found != 1:
            print(f"ERROR: pattern found {found} times: {old}", file=sys.stderr)
            return 1
        text = text.replace(old, new)
    CONFIG.write_text(text, encoding="utf-8")
    print("hbb_common branded: APP_NAME=ElerozConnect, server=connect.eleroz.com, ELEROZ key,"
          f" address book and account disabled, build {build}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
