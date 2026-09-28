"""Bound an owned browser harness and retain output, including timeout evidence."""
import argparse, json, subprocess, time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--timeout',type=float,default=600);p.add_argument('--log',required=True,type=Path);p.add_argument('args',nargs=argparse.REMAINDER);a=p.parse_args()
args=a.args[1:] if a.args and a.args[0]=='--' else a.args
a.log.parent.mkdir(parents=True,exist_ok=True)
started=time.time()
with a.log.open('w',encoding='utf-8') as log:
    child=subprocess.Popen(['node',str(Path(__file__).with_name('world-web-qa.mjs')),*args],stdout=log,stderr=subprocess.STDOUT,cwd=Path(__file__).resolve().parents[1])
    print(json.dumps({'pid':child.pid,'started':started,'timeout':a.timeout,'log':str(a.log)}),flush=True)
    timed_out=False
    try: code=child.wait(timeout=a.timeout)
    except subprocess.TimeoutExpired:
        timed_out=True
        # The exact PID was created above and is still live. Kill only its tree.
        if child.poll() is None: subprocess.run(['taskkill','/PID',str(child.pid),'/T','/F'],stdout=log,stderr=subprocess.STDOUT,timeout=20)
        code=124
receipt={'pid':child.pid,'started':started,'ended':time.time(),'seconds':time.time()-started,'exitCode':code,'timedOut':timed_out,'args':args}
a.log.with_suffix('.supervisor.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt),flush=True)
raise SystemExit(code)

