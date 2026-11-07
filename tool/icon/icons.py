# 生成三个方案的 SVG（108x108，Android adaptive 规格，安全区为中心直径 66）
DEFS = '''<defs>
<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F7A8C8"/><stop offset="1" stop-color="#8E7CF0"/></linearGradient>
<linearGradient id="g2" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8E7CF0"/><stop offset="0.55" stop-color="#F5A3C7"/><stop offset="1" stop-color="#FFD98A"/></linearGradient>
</defs>'''
def A():  # 音符 X
    bg = '<rect width="108" height="108" fill="#161218"/>'
    fg = ('<g stroke="#F5A3C7" stroke-width="8" stroke-linecap="round" fill="none">'
          '<line x1="38" y1="35" x2="70" y2="73"/>'
          '<line x1="70" y1="35" x2="45" y2="65"/>'
          '<path d="M70 35 C78 38 81 44 78 52"/></g>'
          '<ellipse cx="40" cy="71" rx="8.5" ry="6.5" transform="rotate(-25 40 71)" fill="#F5A3C7"/>')
    return bg, fg
def B():  # 唱片 X
    bg = '<rect width="108" height="108" fill="url(#g1)"/>'
    grooves = ''.join(f'<circle cx="54" cy="54" r="{r}" fill="none" stroke="#ffffff" stroke-opacity="0.07" stroke-width="0.8"/>' for r in (16,20,24,28))
    fg = ('<circle cx="54" cy="54" r="32" fill="#141414"/>' + grooves +
          '<path d="M30 40 A28 28 0 0 1 40 30" stroke="#ffffff" stroke-opacity="0.25" stroke-width="2" fill="none" stroke-linecap="round"/>'
          '<circle cx="54" cy="54" r="12" fill="#F5A3C7"/>'
          '<g stroke="#1A0F14" stroke-width="3.2" stroke-linecap="round"><line x1="49" y1="49" x2="59" y2="59"/><line x1="59" y1="49" x2="49" y2="59"/></g>')
    return bg, fg
def C():  # 声波 X（均衡器柱组成的沙漏 X）
    bg = '<rect width="108" height="108" fill="url(#g2)"/>'
    hs = [56, 44, 32, 20, 7, 20, 32, 44, 56]
    w, gap = 4.4, 2.6
    total = len(hs)*w + (len(hs)-1)*gap
    x0 = 54 - total/2
    bars = ''.join(f'<rect x="{x0+i*(w+gap):.2f}" y="{54-h/2:.2f}" width="{w}" height="{h}" rx="{w/2}" fill="#ffffff"/>' for i, h in enumerate(hs))
    return bg, bars
def svg(bg, fg, layer='both'):
    body = (bg if layer in ('both','bg') else '') + (fg if layer in ('both','fg') else '')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">{DEFS}{body}</svg>'
if __name__ == '__main__':
    import json
    print(json.dumps({k: svg(*f()) for k, f in {'A': A, 'B': B, 'C': C}.items()}))

# 单色层（Android 13 主题图标），只用形状，颜色由系统着色
MONO = {
 'A': lambda: A()[1].replace('#F5A3C7', '#FFFFFF'),
 'B': lambda: ('<path fill="#FFFFFF" fill-rule="evenodd" d="M54 22a32 32 0 1 0 0.01 0zM54 42a12 12 0 1 1-0.01 0z"/>'
               '<g stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round"><line x1="50" y1="50" x2="58" y2="58"/><line x1="58" y1="50" x2="50" y2="58"/></g>'),
 'C': lambda: C()[1],
}
def build(k, layer, vb='0 0 108 108', rx=None):
    bg, fg = {'A': A, 'B': B, 'C': C}[k]()
    body = {'bg': bg, 'fg': fg, 'both': bg + fg, 'mono': MONO[k]()}[layer]
    clip = ''
    if rx is not None:
        x, y, w, h = map(float, vb.split())
        clip = f'<clipPath id="cl"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}"/></clipPath>'
        body = f'<g clip-path="url(#cl)">{body}</g>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="100%" height="100%">{DEFS.replace("</defs>", clip + "</defs>")}{body}</svg>'
