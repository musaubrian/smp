import json

with open("./font/lucide-font/info.json") as f:
    info = json.load(f)

names = ["ICON_" + name.upper().replace("-", "_") for name in info]
max_len = max(len(n) for n in names)

lines = [
    "// This is a generated file,\n// Any changes you make may be overwritten\n",
    "package lx\n\n",
    'ICON_FONT_DATA :: #load("./font/lucide-font/lucide.ttf")\n\n',
]

codepoints = set()
for name, (_, data) in zip(names, info.items()):
    cp = int(data["encodedCode"].replace("\\e", ""), 16) + 0xE000
    codepoints.add(cp)
    escaped = "".join(f"\\x{b:02X}" for b in chr(cp).encode("utf-8"))
    lines.append(f'{name:<{max_len}} :: "{escaped}" // U+{cp:04X}\n')

cp_list = ", ".join(f"0x{cp:04X}" for cp in sorted(codepoints))
lines.append(f"\nICON_CODEPOINTS :: []rune{{{cp_list}}}\n")

with open("./icons.odin", "w") as f:
    f.writelines(lines)
