import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

# Count current escaped dollars (backslash before $)
import re
count = len(re.findall(r'\\\$', content))
print(f'Escaped dollars before fix: {count}')

# Show what they look like
for i, line in enumerate(content.splitlines()):
    if re.search(r'\\\$', line):
        print(f'  Line {i+1}: {line[:100]}')

# Replace \$ with $ in the specific locations
# The issue is pcm.length and wav.length template vars
content2 = re.sub(r'\\\$\{', '${', content)
count2 = len(re.findall(r'\\\$', content2))
print(f'Escaped dollars after fix: {count2}')

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(content2)

print('Done')
