"""Check release boundaries, complete resource inputs, and accidental secret exposure.

Run from any directory. Uses the Git index to audit exactly what will be published.
No third-party Python packages are required. Diagnostics never print secret values.
"""
from pathlib import Path
import re
import hashlib
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
controls_cmake = (ROOT / "src/QmlControls/CMakeLists.txt").read_text(encoding="utf-8")
# Listing a QML component only in target_sources compiles successfully but does
# not register its type; the root window then fails at runtime on Android.
if re.search(r"\bHQFlight(?:GeoScene|Drone3D)\.qml\b", controls_cmake.split("qt_add_qml_module", 1)[0]):
    raise SystemExit("Flight scene components must be registered in QML_FILES, not target_sources")
for component in ("HQFlightGeoScene.qml", "HQFlightDrone3D.qml"):
    if component not in controls_cmake.split("QML_FILES", 1)[1]:
        raise SystemExit("Missing QML type registration: " + component)
FILES = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"]).decode().split("\0")
FILES = [name for name in FILES if name]
errors = []
# Published upstream TLS test keys are fixtures, not release credentials.
# Hash-pin them so a newly inserted secret is never hidden by a directory allowlist.
fixtures = {
    "test/GPS/NTRIPHttpTransportTest.cc": "d0b0fb897f0a6f845e4d43671a29536b0189e3a96a6d3cbeec0844a86211a113",
    "test/GPS/NTRIPSourceTableControllerTest.cc": "2c87e71ab613a489ffe63476fe2a483246a723be44d21061f0ab6a22cce19af6",
}
excluded = re.compile(r"HQ(?:Swarm|Cluster|QuickTelemetry|GnssProfessional|GnssSourceState|FigureEight|RCInputMonitor|MultiVideo|RemoteIDMonitor)|ClusterMissionGeometry|SwarmFormationGeometry")
secret = re.compile(r"(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}|sk-[A-Za-z0-9]{30,}|AIza[A-Za-z0-9_-]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)")
for name in FILES:
    path = ROOT / name
    if excluded.search(name):
        errors.append(f"Excluded feature file: {name}")
    if any(part in {".android-signing", "artifacts", ".gradle"}  for part in Path(name).parts) or path.suffix.lower() in {".apk", ".p12", ".jks", ".keystore"} or path.name in {"credentials.json", "local.properties", ".qmlls.ini"}:
        errors.append(f"Local/generated file in publication: {name}")
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeError:
        continue
    if secret.search(content) and hashlib.sha256(content.replace("\r\n", "\n").encode()).hexdigest() != fixtures.get(name):
        errors.append(f"Credential-like data: {name}")
    if name.startswith(("src/", "cmake/", "resources/", "android/")):
        if excluded.search(content) or "quickSurvey" in content or "QuickSurvey" in content or "clusterMission" in content:
            errors.append(f"Excluded feature reference: {name}")
    if path.suffix == ".qrc":
        for node in ET.fromstring(content).iter("file"):
            resource = (path.parent / node.text).resolve()
            if not resource.is_file():
                errors.append(f"Missing resource input in {name}: {node.text}")
            elif resource.relative_to(ROOT).as_posix() not in FILES:
                errors.append(f"Resource not included in source: {resource.relative_to(ROOT)}")
    if path.suffix == ".ts":
        ET.fromstring(content)

warehouse = (ROOT / "src/FlyView/HQToolWarehouse.qml").read_text(encoding="utf-8")
keys = set(re.findall(r'\{ key: "([^"]+)"', warehouse))
if keys != {"tuning", "hud", "pid", "dashboard"}:
    errors.append(f"Unexpected flight toolbox inventory: {sorted(keys)}")
for required in ["LICENSE", "LICENSE-GPL", "LICENSE-APACHE", "NOTICE", "BRANDING.md", "README.md", "docs/BUILD_ANDROID.md", "docs/PROVENANCE.md"]:
    if required not in FILES:
        errors.append(f"Missing public distribution document: {required}")

if errors:
    print("Public-source audit failed:")
    print("\n".join(errors))
    sys.exit(1)
print(f"Public-source audit passed: {len(FILES)} tracked files, resource inputs, toolbox inventory, license documents and credential patterns.")
