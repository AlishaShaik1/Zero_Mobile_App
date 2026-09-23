import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix: replace \\$ with $ (the \\ was a Python escape that ended up as \ in the file, escaping the $)
# In Dart, \$ means literal $, not interpolation. We need $ without backslash.
fixes = [
    ('\\$_kDeepgramKey', '$_kDeepgramKey'),
    ('\\$_kFireworksKey', '$_kFireworksKey'),
    ('\\$_kFireworksUrl', '$_kFireworksUrl'),
    ('\\$_kChatSys', '$_kChatSys'),
    ('\\$pcm.length', '${pcm.length}'),
    ('\\$wav.length', '${wav.length}'),
    ('\\$transcript', '$transcript'),
    ('\\${response.statusCode}', '${response.statusCode}'),
    ('\\${response.body', '${response.body'),
    ('\\$e', '$e'),
    ('\\$chatReply', '$chatReply'),
    ('\\$st', '$st'),
]

for old, new in fixes:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        print(f'Fixed {count}x: {repr(old[:30])} -> {repr(new[:30])}')

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Done. File length: {len(content)} chars')

# Verify
print()
print('Checking remaining \\$ occurrences:')
remaining = [(i+1, l) for i, l in enumerate(content.splitlines()) if '\\$' in l]
for lineno, line in remaining[:10]:
    print(f'  Line {lineno}: {line[:80]}')
if not remaining:
    print('  None! All fixed.')
