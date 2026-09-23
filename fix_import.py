import sys, os

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

# Add the missing import
OLD = "import 'ring_reply_sender.dart';"
NEW = "import 'ring_reply_sender.dart';\nimport 'tool_executor_service.dart';"

if OLD in content:
    content = content.replace(OLD, NEW, 1)
    with open(TARGET, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed — tool_executor_service import added')
else:
    print('ERROR: could not find target string')
    print('Looking for:', repr(OLD))
