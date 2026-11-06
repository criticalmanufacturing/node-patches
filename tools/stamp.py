# Stamps CM build metadata into a configured Node.js source tree (run after
# configure, before the build). Works with Python 2.7 and 3.x.
#   - config.gypi: adds variables cm_build and cm_patches; Node embeds this
#     file as process.config, so they show up as process.config.variables.*
#   - src/res/node.rc: adds a "Comments" field to the Windows file properties
# Usage: stamp.py <srcdir> <cm_build> <cm_patches>
#   e.g. stamp.py work/v12.22.12 12.22.12+cm.20261105 CVE-2026-111497
import ast
import io
import os
import pprint
import sys

src, cm_build, cm_patches = sys.argv[1:4]

gypi = os.path.join(src, 'config.gypi')
# Keep config.gypi's timestamp: if it became newer than out/Makefile, make would
# re-run gyp without configure's -Dpython=..., which fails on Node.js 20.
st = os.stat(gypi)
with io.open(gypi, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()
header = [l for l in lines if l.startswith('#')]
config = ast.literal_eval('\n'.join(l for l in lines if not l.startswith('#')))
config['variables']['cm_build'] = cm_build
config['variables']['cm_patches'] = cm_patches
text = '\n'.join(header) + '\n' + pprint.pformat(config, indent=2) + '\n'
with io.open(gypi, 'w', encoding='utf-8', newline='\n') as f:
    f.write(text if isinstance(text, type(u'')) else text.decode('utf-8'))
os.utime(gypi, (st.st_atime, st.st_mtime))

rc = os.path.join(src, 'src', 'res', 'node.rc')
if os.path.exists(rc):
    with io.open(rc, 'r', encoding='utf-8', newline='') as f:
        s = f.read()
    nl = u'\r\n' if u'\r\n' in s else u'\n'
    anchor = u'            VALUE "LegalCopyright"'
    if u'VALUE "Comments"' not in s and anchor in s:
        line = u'            VALUE "Comments", "CM build %s. Includes fixes: %s"' % (
            cm_build, cm_patches)
        s = s.replace(anchor, line + nl + anchor, 1)
        with io.open(rc, 'w', encoding='utf-8', newline='') as f:
            f.write(s)

print('stamped %s: cm_build=%s cm_patches=%s' % (src, cm_build, cm_patches))
