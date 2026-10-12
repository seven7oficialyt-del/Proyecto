from PIL import Image, ImageDraw

S = 1024

def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    c1, c2 = (124, 58, 237), (45, 224, 165)  # violeta -> menta
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return img

def bars(draw, box, color):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    heights = [0.38, 0.75, 1.0, 0.62, 0.30]
    n = len(heights)
    bw = w / (n * 2 - 1)
    for i, hh in enumerate(heights):
        bx = x0 + i * 2 * bw
        bh = h * hh
        by = y0 + (h - bh) / 2
        draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=bw / 2, fill=color)

bg = gradient(S)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], radius=230, fill=255)
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
icon.paste(bg, (0, 0), mask)
bars(ImageDraw.Draw(icon), (250, 250, 774, 774), (255, 255, 255, 255))
icon.save("assets/icon.png")

fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bars(ImageDraw.Draw(fg), (330, 330, 694, 694), (255, 255, 255, 255))
fg.save("assets/icon_fg.png")
print("ok")
