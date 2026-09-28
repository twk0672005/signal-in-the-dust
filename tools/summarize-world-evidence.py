"""Audit exact Web hashes and unfiltered callback interval statistics from QA receipts."""
import argparse,hashlib,json,math,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--artifact',required=True,type=Path);p.add_argument('--evidence',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in a.artifact.iterdir() if f.is_file()}
rows=[]
for file in sorted(a.evidence.glob('*/receipt.json')):
    r=json.loads(file.read_text(encoding='utf-8-sig'))
    if not r.get('artifactFiles'): continue
    bound=all(hashes.get(x['name'])==x['sha256'] for x in r['artifactFiles'])
    row={'path':str(file),'mode':r.get('mode'),'passed':r.get('passed'),'outcome':r.get('outcome'),'hashesMatchArtifact':bound,'checks':r.get('checks'),'error':r.get('error'),'partialReasons':r.get('partialReasons',[])}
    if r.get('profiles'):
        row['profiles']=[]
        for x in r['profiles']:
            m=x['measurement'];raw=m.get('rawFrameMs',[]);valid=bool(raw) and all(isinstance(v,(int,float)) and math.isfinite(v) and v>=0 for v in raw)
            intervals=sorted(raw);n=len(raw);total=sum(raw)/1000 if valid else 0
            actual={'frames':n,'seconds':total,'meanFps':n/total if total else None,'p95ms':intervals[int((n-1)*.95)] if n else None,'p99ms':intervals[int((n-1)*.99)] if n else None,'worstMs':max(raw) if n else None}
            w=x.get('workload',{});trace=w.get('trace',[])
            row['profiles'].append({'profile':x['profile'],'region':x['region'],'canvas':x['canvas'],'recomputed':actual,'rawValid':valid,'rawSecondsMatch':abs(total-m['seconds'])<.002,'full30Seconds':total>=30,'distance':w.get('distance'),'movingFraction':w.get('movingFraction'),'visitedRegions':sorted(set(y.get('region','unknown') for y in trace)),'inputs':w.get('inputs'),'fixedView':m.get('fixedViewNotJourney'),'reportedFpsMatch':bool(total) and abs(actual['meanFps']-m['meanFps'])<.01,'reportedP95Match':n>0 and abs(actual['p95ms']-m['p95ms'])<.001})
    rows.append(row)
result={'artifact':str(a.artifact.resolve()),'hashes':hashes,'receipts':rows,'limits':'Receipt flags are claims; raw equality and hash binding are mechanical evidence, not visual or user acceptance.'}
a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'receipts':len(rows),'bound':sum(r['hashesMatchArtifact'] for r in rows),'output':str(a.output)}))

