#!/usr/bin/env python3
"""Compila un APK signat. La contrasenya només es passa en l'entorn del procés."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
keystore = Path.home() / '.local/share/eduweb-signing/upload-keystore.jks'
try:
    result = subprocess.run(['pass', 'show', 'eduweb/android-upload-keystore'], capture_output=True, check=True)
    password = result.stdout.decode().splitlines()[0]
    if not keystore.exists():
        raise FileNotFoundError()
except Exception:
    print('Falta la clau de signatura local d’EduWeb.', file=sys.stderr)
    sys.exit(1)
env = os.environ.copy()
env.update(EDUWEB_KEYSTORE_PATH=str(keystore), EDUWEB_STORE_PASSWORD=password, EDUWEB_KEY_PASSWORD=password)
flutter = Path(env.get('FLUTTER_ROOT', str(Path.home() / 'development/flutter'))) / 'bin/flutter'
result = subprocess.run([str(flutter), 'build', 'apk', '--release', '--target-platform', 'android-arm,android-arm64'], cwd=root, env=env)
sys.exit(result.returncode)
