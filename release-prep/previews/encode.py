#!/usr/bin/env python3
"""Encode the Remotion renders to Apple's App Preview settings, with the same
ffmpeg settings as the October previews: H.264 High 4.0, 30 fps CFR, 10 Mbps
CBR, BT.709, silent stereo AAC 48 kHz, fast start. Then decode-check each file."""
import hashlib, json, pathlib, subprocess, sys
HERE = pathlib.Path(__file__).resolve().parent
RENDERS = HERE / 'remotion/out'
OUT = HERE / 'final'
OUT.mkdir(exist_ok=True)
SPECS = {
    'iPhone-Editing': ('tabforge-iphone-1-editing.mp4', 'IPHONE_67', (886, 1920)),
    'iPhone-Themes': ('tabforge-iphone-2-themes.mp4', 'IPHONE_67', (886, 1920)),
    'iPad-Editing': ('tabforge-ipad-1-editing.mp4', 'IPAD_PRO_3GEN_129', (1200, 1600)),
    'iPad-Themes': ('tabforge-ipad-2-themes.mp4', 'IPAD_PRO_3GEN_129', (1200, 1600)),
    'Duo-Editing': ('tabforge-duo-1-editing.mp4', 'IPHONE_DUO', (886, 1920)),
    'Duo-Themes': ('tabforge-duo-2-themes.mp4', 'IPHONE_DUO', (886, 1920)),
}
records = []
for comp in (sys.argv[1:] or SPECS):
    name, device, (w, h) = SPECS[comp]
    src = RENDERS / f'{comp}.mp4'
    out = OUT / name
    probe_in = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(src)], text=True))
    duration = float(probe_in['format']['duration'])
    frames = round(duration * 30)
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y', '-i', str(src), '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo',
           '-filter_complex', f'[0:v]scale={w}:{h}:flags=lanczos,setsar=1,format=yuv420p,fps=30[outv]',
           '-map', '[outv]', '-map', '1:a:0', '-frames:v', str(frames), '-t', f'{frames / 30:.3f}', '-r', '30', '-fps_mode', 'cfr',
           '-c:v', 'libx264', '-threads', '2', '-preset', 'medium', '-profile:v', 'high', '-level:v', '4.0',
           '-b:v', '10M', '-minrate', '10M', '-maxrate', '10M', '-bufsize', '20M', '-x264-params', 'nal-hrd=cbr:filler=1',
           '-pix_fmt', 'yuv420p', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-g', '60',
           '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-ac', '2', '-map_metadata', '-1',
           '-metadata', 'title=TabForge keyboard preview', '-movflags', '+faststart', str(out)]
    subprocess.run(cmd, check=True)
    decode = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(out), '-f', 'null', '-'], capture_output=True, text=True)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_format', '-show_streams', '-of', 'json', str(out)], text=True))
    v = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    a = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
    rec = {'composition': comp, 'file': f'final/{name}', 'deviceType': device, 'size': [w, h], 'seconds': round(float(probe['format']['duration']), 3),
           'frames': int(v['nb_read_frames']), 'video': [v['codec_name'], v['profile'], v['level'], v['pix_fmt'], v['r_frame_rate']],
           'audio': [a['codec_name'], a['sample_rate'], a['channels']], 'bytes': out.stat().st_size,
           'sha256': hashlib.sha256(out.read_bytes()).hexdigest(), 'decodeErrors': decode.stderr.strip()}
    ok = 15 <= rec['seconds'] <= 30 and (v['width'], v['height']) == (w, h) and not rec['decodeErrors']
    rec['withinAppleLimits'] = ok
    records.append(rec)
    print(json.dumps(rec))
previous = {}
try: previous = {r['composition']: r for r in json.loads((OUT / 'validation.json').read_text())['exports']}
except FileNotFoundError: pass
previous.update({r['composition']: r for r in records})
(OUT / 'validation.json').write_text(json.dumps({'specificationURL': 'https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/', 'exports': list(previous.values())}, indent=2) + '\n')
