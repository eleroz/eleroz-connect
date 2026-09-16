"""ЭЛЕРОЗ Коннект: брендирование подмодуля libs/hbb_common перед сборкой.

Подмодуль берётся из официального репозитория RustDesk без изменений, поэтому
название, сервер и ключ задаются здесь. Скрипт падает, если нужная строка
не найдена ровно один раз: молча собрать программу с чужим сервером нельзя.
"""
import pathlib
import sys

CONFIG = pathlib.Path(__file__).resolve().parent.parent / "libs" / "hbb_common" / "src" / "config.rs"

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
        "pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();",
        'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("hide-powered-by-me".to_owned(), "Y".to_owned())]));',
    ),
]


def main() -> int:
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
    print("hbb_common branded: APP_NAME=ElerozConnect, server=connect.eleroz.com, ELEROZ key")
    return 0


if __name__ == "__main__":
    sys.exit(main())
