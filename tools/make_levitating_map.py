#!/usr/bin/env python3
"""Build a local practice beatmap from the user-supplied live recording.
Requires the onset analysis at .tools/levitating-analysis.npz (10 ms spectral flux).
This is an automatic draft, not a hand-authored beatmap.
"""
from pathlib import Path
import sys,json,zipfile,hashlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/audio-python'))
import numpy as np
import soundfile as sf
analysis=np.load(ROOT/'.tools/levitating-analysis.npz')
onset=analysis['onset'];times=analysis['times'];fps=float(analysis['fps']);bpm=float(analysis['bpm'])
period=fps*60/bpm
# Dynamic programming balances measured attacks with a slowly changing beat period.
lags=np.arange(round(period*.65),round(period*1.4)+1)
penalty=80*np.log(lags/period)**2
cumulative=np.zeros(len(onset));previous=np.full(len(onset),-1,dtype=int)
for i in range(len(onset)):
 valid=lags<=i
 if not valid.any():cumulative[i]=onset[i];continue
 candidates=i-lags[valid]
 scores=cumulative[candidates]-penalty[valid]
 best=int(np.argmax(scores))
 if scores[best]>0:previous[i]=candidates[best];cumulative[i]=scores[best]+onset[i]
 else:cumulative[i]=onset[i]
# Do not map the trailing crowd/fade; preserve the complete audio untouched.
last=int(np.searchsorted(times, len(times)/fps-5))
end=max(0,last-round(2*period))+int(np.argmax(cumulative[max(0,last-round(2*period)):last]))
beats=[]
while end>=0:
 beats.append(end);end=previous[end]
beats=np.asarray(beats[::-1]);beat_times=times[beats]
keep=(beat_times>=2.0)&(beat_times<=times[-1]-6.0)
beats=beats[keep];beat_times=beat_times[keep]
assert len(beats)>300
intervals=np.diff(beat_times)
assert np.all((intervals>.35)&(intervals<.9))
audio,sr=sf.read(ROOT/'.tools/levitating-source.mp3',dtype='float32')
dest=ROOT/'artifacts/LevitatingLiveAutoMapV2';dest.mkdir(parents=True,exist_ok=True)
with sf.SoundFile(dest/'song.ogg', 'w', samplerate=sr, channels=audio.shape[1], format='OGG', subtype='VORBIS') as out:
 for offset in range(0, len(audio), 16384): out.write(audio[offset:offset+16384])
# Authored eight-stroke motifs, mirrored for the right hand. Each hand alternates
# downward/upward cuts, leaving time to recover without repeated wrist resets.
# Tuples: left-hand lane, layer, cut direction (0 up, 1 down, 4/5 up diagonals,
# 6/7 down diagonals). Keep each hand on its own side; no crossover or overheads.
motifs=[
 [(1,1,1),(1,0,0),(0,1,1),(0,0,0),(1,1,1),(1,0,0),(0,1,1),(1,0,0)],
 [(1,1,6),(0,0,5),(1,1,1),(1,0,0),(1,1,6),(0,0,5),(1,1,1),(1,0,0)],
 [(0,1,7),(1,0,4),(0,1,1),(0,0,0),(0,1,7),(1,0,4),(0,1,1),(0,0,0)],
 [(1,2,1),(1,0,0),(0,1,6),(0,0,5),(1,2,1),(1,0,0),(0,1,6),(0,0,5)],
 [(0,1,1),(0,0,5),(1,2,6),(0,0,0),(1,1,1),(1,0,4),(0,2,7),(1,0,0)],
 [(1,1,6),(0,0,0),(0,2,7),(1,0,0),(1,1,6),(0,0,5),(1,2,1),(1,0,0)],
]
mirror={0:0,1:1,4:5,5:4,6:7,7:6}
difficulties=[];counts={};variety={}
for name,rank,stride in [('Easy',1,2),('Normal',3,1)]:
 selected=beat_times[::stride]
 notes=[]
 for index,t in enumerate(selected):
  hand=index%2
  stroke=index//2
  phrase=stroke//8
  # Easy changes motif every 16 notes; Normal cycles more complex patterns.
  motif=motifs[phrase % (4 if name=='Easy' else len(motifs))]
  lane,layer,direction=motif[stroke%8]
  if name=='Easy':layer=min(layer,1)
  if hand:lane,direction=3-lane,mirror[direction]
  notes.append({'_time':round(float(t)*bpm/60,6),'_lineIndex':lane,'_lineLayer':layer,'_type':hand,'_cutDirection':direction})
 # Check variety and flow independently of the game parser.
 assert {n['_lineIndex'] for n in notes}=={0,1,2,3}
 assert len({n['_lineLayer'] for n in notes})>=2
 assert len({n['_cutDirection'] for n in notes})>=4
 assert all(n['_cutDirection']!=8 for n in notes)
 for hand in (0,1):
  hand_notes=[n for n in notes if n['_type']==hand]
  for a,b in zip(hand_notes,hand_notes[1:]):
   assert (a['_cutDirection'] in (1,6,7)) != (b['_cutDirection'] in (1,6,7))
   assert (b['_time']-a['_time'])*60/bpm>.7
 variety[name]={'lanes':sorted({n['_lineIndex'] for n in notes}),
                'layers':sorted({n['_lineLayer'] for n in notes}),
                'directions':sorted({n['_cutDirection'] for n in notes})}
 chart={'_version':'2.0.0','_notes':notes,'_obstacles':[],'_events':[]}
 filename=name+'Standard.dat';(dest/filename).write_text(json.dumps(chart,separators=(',',':')))
 difficulties.append({'_difficulty':name,'_difficultyRank':rank,'_beatmapFilename':filename,
                      '_noteJumpMovementSpeed':10 if name=='Easy' else 12,'_noteJumpStartBeatOffset':0})
 counts[name]=len(notes)
info={'_version':'2.0.0','_songName':'Levitating','_songSubName':'Live From Mexico - Flow v2',
      '_songAuthorName':'Dua Lipa','_levelAuthorName':'OpenSaberPlus Auto Draft',
      '_beatsPerMinute':round(bpm,4),'_songTimeOffset':0,'_shuffle':0,'_shufflePeriod':.5,
      '_previewStartTime':30,'_previewDuration':10,'_songFilename':'song.ogg','_coverImageFilename':'cover.png',
      '_environmentName':'DefaultEnvironment','_customData':{'_colorLeft':{'r':.9,'g':.12,'b':.2},'_colorRight':{'r':.08,'g':.48,'b':1}},
      '_difficultyBeatmapSets':[{'_beatmapCharacteristicName':'Standard','_difficultyBeatmaps':difficulties}]}
(dest/'Info.dat').write_text(json.dumps(info,indent=2))
(dest/'cover.png').write_bytes((ROOT/'artifacts/SyncTest120/cover.png').read_bytes())
report={'estimated_bpm':bpm,'duration_seconds':len(audio)/sr,'notes':counts,'pattern_variety':variety,
        'first_note_seconds':float(beat_times[0]),'last_note_seconds':float(beat_times[-1]),
        'median_beat_interval_seconds':float(np.median(intervals)),
        'beat_interval_p05_p95':np.percentile(intervals,[5,95]).tolist(),
        'source_sha256':hashlib.sha256((ROOT/'.tools/levitating-source.mp3').read_bytes()).hexdigest(),
        'method':'Spectral-flux onset envelope plus tempo-penalized dynamic programming; note times follow estimated local beats.',
        'validation':'Structural checks only; not auditioned or hand-reviewed. Not a synchronization reference.',
        'rights':'Audio provided by user; no claim to audio ownership.'}
(dest/'mapping-report.json').write_text(json.dumps(report,indent=2))
(dest/'README.txt').write_text('Practice map from your supplied recording: Flow v2.\nEasy: sparse directional notes, four lanes and two heights.\nNormal: six mirrored flow motifs, four lanes and three heights.\nBoth alternate down/up strokes per hand; no dot notes, bombs or walls.\nTiming is estimated, not manually verified.\nUse SYNC TEST 120 for device calibration; do not calibrate against this automatic map.\n')
archive=ROOT/'artifacts/Levitating-Live-Flow-v2.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for file in sorted(dest.iterdir()):z.write(file,file.name)
print(json.dumps(report,indent=2));print(archive,archive.stat().st_size)
# Verify conversion does not shift the file duration or add a header offset.
decoded,newrate=sf.read(dest/'song.ogg',dtype='float32')
assert newrate==sr and len(decoded)==len(audio)
