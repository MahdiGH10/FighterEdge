from pathlib import Path
import re,json,sys
repo=Path(sys.argv[1]).resolve()
text=(repo/'lib/theme/app_colors.dart').read_text(encoding='utf-8')
definitions=dict(re.findall(r'static const Color (\w+) = (.*?);',text))
def value(name):
    expr=definitions[name]
    return int(re.search(r'0x([0-9A-Fa-f]+)',expr)[1],16) if expr.startswith('Color') else value(expr)
colors={k:value(k) for k in definitions}
def rgb(v): return [(v>>16&255)/255,(v>>8&255)/255,(v&255)/255]
def luminance(c):
    linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    return sum(a*b for a,b in zip(linear,[.2126,.7152,.0722]))
def contrast(fg,bg):
    a=(fg>>24&255)/255
    c=[x*a+y*(1-a) for x,y in zip(rgb(fg),rgb(bg))]
    x,y=sorted([luminance(c),luminance(rgb(bg))])
    return (y+.05)/(x+.05)
foregrounds=['textPrimary','textSecondary','textMuted','primary','accentText','positive','warning','negative','premium','carbs','crimson400','series4','series5','series6']
backgrounds=['background','backgroundRaised','surface','surfaceAlt','surfaceElevated']
rows=[{'foreground':f,'background':b,'ratio':contrast(colors[f],colors[b]),'normal_text_pass':contrast(colors[f],colors[b])>=4.5} for f in foregrounds for b in backgrounds]
for f,b in [('onPrimary','primary'),('onPrimary','primaryFill'),('onPrimary','primaryDark'),('googleText','googleSurface'),('googleBorder','googleSurface'),('border','surface'),('borderStrong','surface')]: rows.append({'foreground':f,'background':b,'ratio':contrast(colors[f],colors[b])})
uses={name:[] for name in colors}
for path in (repo/'lib').rglob('*.dart'):
    if path.name=='app_colors.dart':continue
    for line_number,line in enumerate(path.read_text(encoding='utf-8').splitlines(),1):
        for name in re.findall(r'AppColors\.(\w+)',line):
            if name in uses: uses[name].append(f'{path.relative_to(repo).as_posix()}:{line_number}')
out={'colors':{k:f'#{v:08X}' for k,v in colors.items()},'usage':uses,'contrast':rows}
Path(__file__).with_name('palette.json').write_text(json.dumps(out,indent=2))
for r in rows:
    if r['background'] in ('surface','surfaceElevated','primary','primaryFill','primaryDark','googleSurface'):print(f"{r['foreground']} / {r['background']}: {r['ratio']:.3f}")
