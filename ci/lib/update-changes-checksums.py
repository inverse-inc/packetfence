import hashlib, os, sys, re

changes_file = sys.argv[1]
changes_dir = os.path.dirname(changes_file)

with open(changes_file, 'r') as f:
    content = f.read()

deb_files = re.findall(r'^\s+[a-f0-9]+\s+\d+\s+\S+\s+\S+\s+(.*\.deb)\s*$', content, re.MULTILINE)

hashes = {}
for deb_name in deb_files:
    deb_path = os.path.join(changes_dir, deb_name)
    if not os.path.exists(deb_path):
        continue
    with open(deb_path, 'rb') as f:
        data = f.read()
    hashes[deb_name] = {
        'md5': hashlib.md5(data).hexdigest(),
        'sha1': hashlib.sha1(data).hexdigest(),
        'sha256': hashlib.sha256(data).hexdigest(),
        'size': len(data),
    }
    print(f"  Updating {deb_name}: size={len(data)}")

SECTION_HASH = {'Files': 'md5', 'Checksums-Sha1': 'sha1', 'Checksums-Sha256': 'sha256'}

lines = content.splitlines(True)
current_section = None
result = []

for line in lines:
    stripped = line.rstrip('\n')
    if stripped and not stripped[0].isspace():
        current_section = stripped.rstrip(':') if stripped.endswith(':') else None

    if current_section in SECTION_HASH and stripped and stripped[0].isspace():
        algo = SECTION_HASH[current_section]
        for deb_name, h in hashes.items():
            escaped = re.escape(deb_name)
            if current_section == 'Files':
                m = re.match(r'^(\s+)[a-f0-9]+\s+\d+\s+(\S+\s+\S+\s+)' + escaped + r'\s*$', stripped)
                if m:
                    line = m.group(1) + h[algo] + ' ' + str(h['size']) + ' ' + m.group(2) + deb_name + '\n'
                    break
            else:
                m = re.match(r'^(\s+)[a-f0-9]+\s+\d+\s+' + escaped + r'\s*$', stripped)
                if m:
                    line = m.group(1) + h[algo] + ' ' + str(h['size']) + ' ' + deb_name + '\n'
                    break

    result.append(line)

with open(changes_file, 'w') as f:
    f.writelines(result)

print(f"Updated checksums in {changes_file}")
