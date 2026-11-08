import subprocess, sys
# Times (s) when the code text region changes, ignoring single-frame cursor blinks.
take, x, y, w, h, t0, t1 = sys.argv[1], *map(float, sys.argv[2:8])
W, Hh = 160, 40
raw = subprocess.run(['ffmpeg','-v','error','-ss',str(t0),'-to',str(t1),'-i',f'{take}-take.mp4','-vf',f'crop={int(w)}:{int(h)}:{int(x)}:{int(y)},scale={W}:{Hh},fps=20,format=gray','-f','rawvideo','-'],capture_output=True).stdout
n = W*Hh; frames = [raw[i:i+n] for i in range(0, len(raw)-n+1, n)]
prev = None
for i, f in enumerate(frames):
    if prev is not None:
        d = sum(abs(a-b) for a, b in zip(f, prev)) / n
        if d > float(sys.argv[8] if len(sys.argv) > 8 else 0.3): print(f'{t0 + i/20:7.2f}  diff {d:5.1f}')
    prev = f
