"""Check QRC URLs and contents across XML layouts at the Qt handoff boundary."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import posixpath
import subprocess
import xml.etree.ElementTree as xml


def run(command, log):
    command = [str(value) for value in command]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    log.write_text(json.dumps(command) + "\n" + result.stdout + result.stderr, encoding="utf-8")
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def xml_entries(path):
    entries = []
    for group in xml.parse(path).getroot().findall("qresource"):
        for node in group.findall("file"):
            filename = node.text or ""
            source = (path.parent / filename).resolve()
            url = ":/" + posixpath.normpath(
                group.get("prefix", "").strip("/") + "/" + node.get("alias", filename)).lstrip("/")
            entries.append({
                "url": url, "source": str(source),
                "file_attributes": {key: value for key, value in node.attrib.items() if key != "alias"},
                "group_attributes": {key: value for key, value in group.attrib.items() if key != "prefix"},
                "is_qml": source.suffix in (".qml", ".js", ".mjs"),
                "content": digest(source),
            })
    return entries


def manifests():
    # The oracle is the QRC resource contract: formatting and comments cannot
    # change URLs, while language and per-file attributes remain significant.
    assets = """<qresource prefix="/assets">
<file alias="icon.txt" compress="1" threshold="0">asset.txt</file>
<file alias="placeholder.txt" empty="true">empty.txt</file>
</qresource>
<qresource prefix="/assets" lang="fr">
<file alias="icon.txt" compression-algorithm="none">asset_fr.txt</file>
</qresource>
"""
    ordinary = """<RCC>
<qresource prefix="/first">
<file alias="ui/One.qml">One.qml</file>
</qresource>
<qresource prefix="/next">
<file alias="ui/Two.qml">Two.qml</file>
</qresource>
""" + assets + "</RCC>\n"
    return {
        "ordinary": {"resources.qrc": ordinary},
        "compact": {"resources.qrc": ordinary.replace("\n", "")},
        "omitted_prefix": {"resources.qrc": ordinary.replace('<qresource prefix="/next">', "<qresource>")},
        "split_prefix": {"resources.qrc": ordinary.replace(
            '<qresource prefix="/next">', '<qresource\n prefix="/next">')},
        "split_file": {"resources.qrc": ordinary.replace(
            '<file alias="ui/Two.qml">Two.qml</file>', '<file\n alias="ui/Two.qml">Two.qml</file>')},
        "comment_alias": {"resources.qrc": ordinary.replace(
            '<file alias="ui/One.qml">One.qml</file>',
            '<!-- retired alias="Old.qml" --><file alias="ui/One.qml">One.qml</file>')},
        "comment_prefix": {"resources.qrc": ordinary.replace(
            '<file alias="ui/One.qml">One.qml</file>',
            '<!-- example <qresource prefix="/wrong"> -->\n<file alias="ui/One.qml">One.qml</file>')},
        "multiple_aliases": {"resources.qrc": ordinary.replace(
            '<file alias="ui/One.qml">One.qml</file>',
            '<file alias="ui/One.qml">One.qml</file><file alias="other/One.qml">One.qml</file>')},
        "across_manifests": {
            "first.qrc": '<RCC>\n<qresource prefix="/first">\n<file>One.qml</file>\n</qresource>\n</RCC>\n',
            "second.qrc": '<RCC>\n<qresource>\n<file>Two.qml</file>\n<file>qmldir</file>\n</qresource>\n'
            + assets + '</RCC>\n',
        },
        "xml_escaping": {"resources.qrc": ordinary.replace(
            'alias="ui/One.qml"', "alias='ui/One.qml'").replace(
            '>asset.txt<', '>a &amp; ${keep} ]=].txt<').replace(
            'alias="icon.txt"', 'alias="icon &amp; image.txt"')},
    }


def check_case(args, name, inputs):
    case = args.work / name
    source_dir = case / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    for filename, content in {
        "One.qml": "import QtQuick\nItem { objectName: 'first' }\n",
        "Two.qml": "import QtQuick\nItem { objectName: 'second' }\n",
        "asset.txt": "base icon\n", "asset_fr.txt": "French icon\n",
        "empty.txt": "discard this content\n", "qmldir": "module Contract\nTwo 1.0 Two.qml\n",
        "a & ${keep} ]=].txt": "literal XML and CMake characters\n",
    }.items():
        (source_dir / filename).write_text(content, encoding="utf-8")
    expected = []
    qrcs = []
    for filename, content in inputs.items():
        path = source_dir / filename
        path.write_text(content, encoding="utf-8")
        qrcs.append(path)
        expected.extend(xml_entries(path))

    build = case / "build"
    configure_command = [
        args.cmake, "-S", args.provider / "tests/qml_xml", "-B", build, "-G", args.generator,
        "-DCMAKE_MAKE_PROGRAM=" + args.make_program, "-DCMAKE_BUILD_TYPE=Debug",
        "-DPROVIDER_SOURCE=" + str(args.provider), "-DINPUT_QRCS=" + ";".join(str(path) for path in qrcs),
    ]
    configured = run(configure_command, case / "configure.log")
    if configured.returncode:
        raise AssertionError(configured.stdout + configured.stderr)
    actual_qml = []
    for line in (build / "qml_handoff.tsv").read_text().splitlines():
        alias, copied = line.split("\t", 1)
        actual_qml.append({"url": ":/" + alias, "content": digest(Path(copied))})
    expected_qml = [{"url": item["url"], "content": item["content"]} for item in expected if item["is_qml"]]
    if sorted(actual_qml, key=str) != sorted(expected_qml, key=str):
        raise AssertionError("QML handoff differs: " + repr(actual_qml) + " expected " + repr(expected_qml))

    actual_assets = []
    residuals = [Path(line) for line in (build / "asset_handoff.txt").read_text().splitlines()]
    if [path.name for path in residuals] != [path.name for path in qrcs]:
        raise AssertionError("Manifest basenames or Qt asset handoff order changed")
    for path in residuals:
        actual_assets.extend(xml_entries(path))
    expected_assets = [item for item in expected if not item["is_qml"]]
    if sorted(actual_assets, key=str) != sorted(expected_assets, key=str):
        raise AssertionError("Asset URLs, locales, attributes, sources or contents differ")
    if name == "across_manifests":
        if (build / "qml_modules/probe/qmldir").read_bytes() != (source_dir / "qmldir").read_bytes():
            raise AssertionError("Root qmldir was not copied to Qt tooling directory")
    if (build / "qml_modules/other/qmldir").read_text(encoding="utf-8") != "module Other\n":
        raise AssertionError("Default qmldir was not kept target-local")

    # A reconfigure must not invalidate Qt cache generation or rcc when the
    # selected inputs have not changed. Use old timestamps, not a sleep, so
    # this detects rewrites even on filesystems with coarse timestamp precision.
    generated = list((build / "qml_modules").rglob("qmldir"))
    generated.extend((build / "qml_sources").rglob("*"))
    generated.extend((build / "qml_assets").rglob("*"))
    generated = [path for path in generated if path.is_file()]
    for path in generated:
        os.utime(path, (946684800, 946684800))
    before = {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in generated}
    configured = run(configure_command, case / "reconfigure.log")
    if configured.returncode:
        raise AssertionError(configured.stdout + configured.stderr)
    deferred_qmldir = (build / "deferred_qmldir.txt").read_text() == "TRUE"
    for path, state in before.items():
        if not deferred_qmldir and name == "across_manifests" and path == build / "qml_modules/probe/qmldir":
            # CMake < 3.19 retains immediate writes across separate calls.
            if path.read_bytes() != state[0]:
                raise AssertionError("Unchanged reconfigure changed " + str(path))
            continue
        if (path.read_bytes(), path.stat().st_mtime_ns) != state:
            raise AssertionError("Unchanged reconfigure rewrote " + str(path))

    if name == "multiple_aliases":
        changed = b"import QtQuick\nItem { objectName: 'changed' }\n"
        (source_dir / "One.qml").write_bytes(changed)
        configured = run(configure_command, case / "qml_edit.log")
        if configured.returncode:
            raise AssertionError(configured.stdout + configured.stderr)
        aliases = [build / "qml_sources/probe/first" / alias
                   for alias in ("ui/One.qml", "other/One.qml")]
        for path, state in before.items():
            if path in aliases:
                if path.read_bytes() != changed:
                    raise AssertionError("QML edit did not update alias " + str(path))
            elif (path.read_bytes(), path.stat().st_mtime_ns) != state:
                raise AssertionError("QML edit invalidated unrelated output " + str(path))

    if name == "across_manifests":
        qmldir = build / "qml_modules/probe/qmldir"
        changed = b"module Contract\nTwo 2.0 Two.qml\n"
        (source_dir / "qmldir").write_bytes(changed)
        configured = run(configure_command, case / "qmldir_edit.log")
        if configured.returncode:
            raise AssertionError(configured.stdout + configured.stderr)
        if qmldir.read_bytes() != changed:
            raise AssertionError("Supplied qmldir edit did not reach the tooling directory")
        # Removing the owner-supplied file must select the fallback, even when
        # the previous configure left a custom qmldir in the build directory.
        second = source_dir / "second.qrc"
        second.write_text(second.read_text().replace("<file>qmldir</file>", ""), encoding="utf-8")
        configured = run(configure_command, case / "qmldir_remove.log")
        if configured.returncode:
            raise AssertionError(configured.stdout + configured.stderr)
        if qmldir.read_text(encoding="utf-8") != "module Contract\n":
            raise AssertionError("Removing supplied qmldir did not restore the default")
        if any(item["url"] == ":/qmldir" for item in xml_entries(build / "qml_assets/probe/second.qrc")):
            raise AssertionError("Removing supplied qmldir did not update the residual QRC")
    print(name + ": PASS", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    parser.add_argument("--generator", required=True)
    parser.add_argument("--make-program", required=True)
    args = parser.parse_args()
    for name, inputs in manifests().items():
        check_case(args, name, inputs)


if __name__ == "__main__":
    main()
