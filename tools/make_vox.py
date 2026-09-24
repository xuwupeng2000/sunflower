import math
import os
import struct

ROOT = os.path.join(os.path.dirname(__file__), "..", "models")


def write_vox(path, voxels):
    voxels = unique(voxels)
    xs = [v[0] for v in voxels]
    ys = [v[1] for v in voxels]
    zs = [v[2] for v in voxels]
    size = struct.pack("<iii", max(xs) + 1, max(ys) + 1, max(zs) + 1)
    xyzi = struct.pack("<i", len(voxels))
    for x, y, z, color in voxels:
        xyzi += struct.pack("<BBBB", x, y, z, color)
    rgba = b""
    for index in range(256):
        rgba += struct.pack("<BBBB", *PALETTE[index])
    children = chunk(b"SIZE", size) + chunk(b"XYZI", xyzi) + chunk(b"RGBA", rgba)
    data = b"VOX " + struct.pack("<i", 150) + chunk(b"MAIN", b"", children)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)


def chunk(tag, content, children=b""):
    return tag + struct.pack("<ii", len(content), len(children)) + content + children


def palette_from(colors):
    rows = [(0, 0, 0, 0)] * 256
    for index, color in colors.items():
        rows[index - 1] = (*color, 255)
    rows[255] = (0, 0, 0, 0)
    return rows


PALETTE = []


def set_palette(colors):
    global PALETTE
    PALETTE = palette_from(colors)


def unique(voxels):
    cells = {}
    for x, y, z, color in voxels:
        if x < 0 or y < 0 or z < 0:
            continue
        cells[(x, y, z)] = color
    return [(x, y, z, color) for (x, y, z), color in cells.items()]


def disc(voxels, cx, cy, z, radius, color, inner=0):
    limit = int(radius) + 1
    for y in range(cy - limit, cy + limit + 1):
        for x in range(cx - limit, cx + limit + 1):
            dist = (x - cx) ** 2 + (y - cy) ** 2
            if inner * inner <= dist <= radius * radius:
                voxels.append((x, y, z, color))


def stem_model():
    voxels = []
    cx, cy = 8, 8
    for z in range(8):
        for y in range(cx - 4, cx + 5):
            for x in range(cy - 4, cy + 5):
                dist = (x - cx) ** 2 + (y - cy) ** 2
                if dist <= 5:
                    if x >= cx + 1 and dist <= 2:
                        color = 3
                    elif dist >= 4:
                        color = 1
                    else:
                        color = 2
                    voxels.append((x, y, z, color))
    for i in range(9):
        width = max(0, int(round(2.4 * math.sin(i / 8.0 * math.pi))))
        z = 2 + i // 3
        for side in range(-width, width + 1):
            color = 6 if side == 0 else 4
            voxels.append((cx + 3 + i, cy + side, z, color))
            if width > 0 and abs(side) == width:
                voxels.append((cx + 3 + i, cy + side, z + 1, 5))
    return unique(voxels)


def flower_model():
    voxels = []
    cx, cy = 20, 20
    for z in range(4):
        disc(voxels, cx, cy, z, 2.2, 2)
    for angle_index in range(8):
        angle = angle_index / 8.0 * math.tau
        for i in range(5):
            x = int(round(cx + math.cos(angle) * (3 + i)))
            y = int(round(cy + math.sin(angle) * (3 + i)))
            voxels.append((x, y, 3, 12))
    rings = (
        (0.0, 11, 8, 3),
        (0.26, 9, 7, 4),
    )
    for offset, count, length, width in rings:
        for index in range(count):
            angle = offset + index / count * math.tau
            dx, dy = math.cos(angle), math.sin(angle)
            px, py = -dy, dx
            for step in range(length):
                t = step / max(1, length - 1)
                spread = 1 + int(round(width * math.sin(t * math.pi)))
                droop = 1 if t > 0.78 else 0
                color = 7 if t > 0.72 else (9 if t < 0.28 else 8)
                z = 5 + int(t * 2) - droop
                for side in range(-spread, spread + 1):
                    x = int(round(cx + dx * (3 + step) + px * side * 0.55))
                    y = int(round(cy + dy * (3 + step) + py * side * 0.55))
                    voxels.append((x, y, z, color))
                    if abs(side) <= 1 and t < 0.85:
                        voxels.append((x, y, z + 1, 9 if t < 0.4 else 8))
    for z, radius in ((6, 5.2), (7, 4.4), (8, 3.3), (9, 2.1)):
        limit = int(radius) + 1
        for y in range(cy - limit, cy + limit + 1):
            for x in range(cx - limit, cx + limit + 1):
                dist = (x - cx) ** 2 + (y - cy) ** 2
                if dist <= radius * radius:
                    color = 10 if (x * 2 + y * 3) % 3 == 0 else 11
                    voxels.append((x, y, z, color))
    return unique(voxels)


def pot_model():
    voxels = []
    cx, cy = 12, 12
    for z in range(9):
        if z == 8:
            radius, inner = 8.2, 5.2
            color = 15
        elif z == 0:
            radius, inner = 5.2, -1
            color = 13
        else:
            radius = 6.2 + math.sin(z / 7.0 * math.pi) * 1.3
            inner = radius - 1.7
            color = 14
        limit = int(radius) + 2
        for y in range(cy - limit, cy + limit + 1):
            for x in range(cx - limit, cx + limit + 1):
                dist = (x - cx) ** 2 + (y - cy) ** 2
                if inner * inner <= dist <= radius * radius:
                    shade = 13 if x < cx - 2 else color
                    voxels.append((x, y, z, shade))
    disc(voxels, cx, cy, 8, 5.0, 16)
    for x, y in ((cx - 2, cy), (cx + 2, cy + 1), (cx, cy - 2)):
        voxels.append((x, y, 8, 17))
    return unique(voxels)


def main():
    flowers = {
        "sunflower": {
            1: (46, 92, 38), 2: (62, 122, 46), 3: (118, 168, 72),
            4: (48, 110, 42), 5: (74, 146, 58), 6: (168, 196, 86),
            7: (214, 122, 28), 8: (242, 186, 42), 9: (255, 224, 96),
            10: (92, 48, 22), 11: (138, 78, 32), 12: (36, 86, 34),
        },
        "orange": {
            1: (52, 96, 36), 2: (70, 118, 40), 3: (130, 160, 64),
            4: (56, 108, 38), 5: (86, 140, 48), 6: (170, 190, 80),
            7: (186, 62, 24), 8: (230, 112, 36), 9: (255, 168, 72),
            10: (110, 42, 20), 11: (150, 64, 28), 12: (40, 82, 30),
        },
        "lemon": {
            1: (78, 120, 48), 2: (104, 146, 58), 3: (168, 186, 90),
            4: (70, 128, 50), 5: (120, 164, 70), 6: (198, 214, 110),
            7: (214, 176, 48), 8: (236, 214, 86), 9: (252, 244, 170),
            10: (120, 72, 28), 11: (168, 110, 46), 12: (64, 110, 42),
        },
    }
    pots = {
        "clay": {13: (112, 58, 32), 14: (168, 86, 48), 15: (196, 112, 68), 16: (92, 58, 32), 17: (64, 40, 24)},
        "white": {13: (186, 180, 170), 14: (232, 228, 220), 15: (248, 246, 242), 16: (120, 92, 60), 17: (78, 58, 36)},
        "blue": {13: (28, 48, 92), 14: (46, 82, 146), 15: (92, 132, 188), 16: (70, 50, 32), 17: (46, 32, 20)},
    }
    for name, colors in flowers.items():
        set_palette(colors)
        write_vox(os.path.join(ROOT, "stem_%s.vox" % name), stem_model())
        write_vox(os.path.join(ROOT, "flower_%s.vox" % name), flower_model())
    for name, colors in pots.items():
        set_palette(colors)
        write_vox(os.path.join(ROOT, "pot_%s.vox" % name), pot_model())
    print("wrote", len(flowers) * 2 + len(pots), "vox files")


if __name__ == "__main__":
    main()
