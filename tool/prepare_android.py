"""Приводит сгенерированный android/ к application id com.aitarot.app.

Запускается из корня проекта, идемпотентен: повторный запуск ничего не ломает.
"""

import pathlib
import re
import shutil

APP_ID = 'com.aitarot.app'
APP_LABEL = 'AI Tarot'

root = pathlib.Path('.')

# 1. applicationId + namespace в Gradle-конфиге (Kotlin DSL или Groovy)
for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    gradle = root / name
    if not gradle.exists():
        continue
    text = gradle.read_text(encoding='utf-8')
    for key in ('applicationId', 'namespace'):
        text = re.sub(
            key + r'(\s*=\s*|\s+)(["\'])[^"\']*\2',
            key + r'\g<1>"' + APP_ID + '"',
            text,
        )
    gradle.write_text(text, encoding='utf-8')
    print('patched ' + name)

# 2. MainActivity должен лежать в пакете, совпадающем с namespace
kotlin_root = root / 'android/app/src/main/kotlin'
if kotlin_root.exists():
    target = kotlin_root.joinpath(*APP_ID.split('.')) / 'MainActivity.kt'
    for activity in list(kotlin_root.rglob('MainActivity.kt')):
        text = re.sub(
            r'^package .*$',
            'package ' + APP_ID,
            activity.read_text(encoding='utf-8'),
            count=1,
            flags=re.MULTILINE,
        )
        moved = activity.resolve() != target.resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8')
        if moved:
            activity.unlink()
        print('MainActivity -> ' + str(target))

    # чистим опустевшие каталоги старого пакета
    for path in sorted(kotlin_root.rglob('*'), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            shutil.rmtree(path, ignore_errors=True)

# 3. Манифест: название приложения и доступ в интернет
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    text = re.sub(
        r'android:label="[^"]*"',
        'android:label="' + APP_LABEL + '"',
        text,
        count=1,
    )
    if 'android.permission.INTERNET' not in text:
        text = text.replace(
            '<application',
            '<uses-permission android:name="android.permission.INTERNET"/>'
            '\n\n    <application',
            1,
        )
    manifest.write_text(text, encoding='utf-8')
    print('patched AndroidManifest.xml')

print('Готово: application id = ' + APP_ID)
