"""Separate QML compiler inputs from a QRC without changing its asset metadata."""

import argparse
from pathlib import Path
import posixpath
import sys
import xml.etree.ElementTree as xml


def cmake_value(value):
    # Bracket arguments keep XML-decoded paths literal, including ${...} and quotes.
    delimiter = "="
    while "]" + delimiter + "]" in value:
        delimiter += "="
    return "[" + delimiter + "[" + value + "]" + delimiter + "]"


def local_name(element):
    return element.tag.rsplit("}", 1)[-1]


def write_if_different(path, content):
    try:
        if path.read_bytes() == content:
            return
    except FileNotFoundError:
        pass
    path.write_bytes(content)


def transform(qrc, assets, entries):
    tree = xml.parse(qrc)
    handoffs = []
    for group in tree.getroot():
        if local_name(group) != "qresource":
            continue
        prefix = group.get("prefix", "").strip("/")
        for node in list(group):
            if local_name(node) != "file":
                continue
            filename = node.text or ""
            if not filename.strip():
                continue
            source = (qrc.parent / filename).absolute().as_posix()
            alias = node.get("alias", filename)
            # rcc cleans the alias, strips leading parent components, then adds
            # the group's prefix. Empty path components do not form URL nodes.
            clean_alias = posixpath.normpath(alias)
            while clean_alias.startswith("../"):
                clean_alias = clean_alias[3:]
            resource_url = "/" + "/".join(
                part for part in (prefix + "/" + clean_alias).split("/") if part)
            handoffs.append((source, resource_url))
            if Path(filename).suffix in (".qml", ".js", ".mjs"):
                group.remove(node)
            else:
                # An implicit alias is relative to the input QRC. Keep it when
                # making the source absolute for the relocated residual QRC.
                node.set("alias", alias)
                node.text = source

    assets.parent.mkdir(parents=True, exist_ok=True)
    write_if_different(assets, xml.tostring(tree.getroot(), encoding="utf-8", xml_declaration=True))
    statements = ["set(vnm_qrc_entries " + cmake_value(
        ";".join(str(index) for index in range(len(handoffs)))) + ")\n"]
    for index, (source, resource_url) in enumerate(handoffs):
        statements.append("set(vnm_qrc_source_" + str(index) + " " + cmake_value(source) + ")\n")
        statements.append("set(vnm_qrc_url_" + str(index) + " " + cmake_value(resource_url) + ")\n")
    write_if_different(entries, "".join(statements).encode("utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("qrc", type=Path)
    parser.add_argument("assets", type=Path)
    parser.add_argument("entries", type=Path)
    args = parser.parse_args()
    try:
        transform(args.qrc, args.assets, args.entries)
    except (OSError, xml.ParseError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
