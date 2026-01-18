#!/usr/bin/env python3
import struct
import zlib

def create_png(width, height, color_rgba):
    """Create a minimal valid PNG file with a solid color."""

    # PNG header
    signature = b'\x89PNG\r\n\x1a\n'

    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data)
    ihdr = struct.pack('>I', 13) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)

    # IDAT chunk (image data)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # filter byte
        for x in range(width):
            raw_data += bytes(color_rgba)

    compressed = zlib.compress(raw_data, 9)
    idat_crc = zlib.crc32(b'IDAT' + compressed)
    idat = struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc)

    # IEND chunk
    iend_crc = zlib.crc32(b'IEND')
    iend = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)

    return signature + ihdr + idat + iend

# Create a 22x22 icon - for macOS template icons, use black with alpha
icon_data = create_png(22, 22, [0, 0, 0, 200])

with open('src-tauri/icons/tray.png', 'wb') as f:
    f.write(icon_data)

# Also create app icons with Anthropic tan color
icon_32 = create_png(32, 32, [212, 165, 116, 255])
icon_128 = create_png(128, 128, [212, 165, 116, 255])
icon_256 = create_png(256, 256, [212, 165, 116, 255])

with open('src-tauri/icons/32x32.png', 'wb') as f:
    f.write(icon_32)
with open('src-tauri/icons/128x128.png', 'wb') as f:
    f.write(icon_128)
with open('src-tauri/icons/128x128@2x.png', 'wb') as f:
    f.write(icon_256)

print("Icons created successfully")
