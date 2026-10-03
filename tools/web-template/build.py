import os,pathlib,subprocess,sys,json,datetime,time
ROOT=pathlib.Path(__file__).resolve().parent
env=os.environ.copy()
sdk=ROOT/'emsdk'
env['EM_CONFIG']=str(sdk/'.emscripten')
env['EMSDK']=str(sdk)
env['EMSDK_NODE']=str(sdk/'node/22.16.0_64bit/bin/node.exe')
env['EMSDK_PYTHON']=str(sdk/'python/3.13.3_64bit/python.exe')
env['PYTHONPATH']=str(ROOT/'pytools')
env['PATH']=str(sdk/'upstream/emscripten')+os.pathsep+str(sdk)+os.pathsep+env['PATH']
env['TEMP']=env['TMP']=str(ROOT/'tmp')
env['PYTHONPYCACHEPREFIX']=str(ROOT/'tmp/pycache')
env['GODOT_VERSION_BUILD']='custom_parallel_scene'
args=[sys.executable,'-m','SCons','platform=web','target=template_release','arch=wasm32','threads=no','dlink_enabled=no','vulkan=no','opengl3=yes','use_closure_compiler=no','debug_symbols=no','lto=thin','-j6']
start=datetime.datetime.now(datetime.timezone.utc).isoformat()
t=time.monotonic()
with (ROOT/'build.log').open('w',encoding='utf-8') as log:
    log.write('COMMAND: '+str(args)+'\n');log.flush()
    proc=subprocess.Popen(args,cwd=ROOT/'godot',env=env,stdout=log,stderr=subprocess.STDOUT)
    print('Build process',proc.pid,'started',start,flush=True)
    code=proc.wait()
receipt={'start_utc':start,'end_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'elapsed_s':round(time.monotonic()-t,3),'command':args,'cwd':str(ROOT/'godot'),'exit_code':code,'child_pid':proc.pid,'local_configuration':{key:env[key] for key in ['EM_CONFIG','EMSDK','EMSDK_NODE','EMSDK_PYTHON','PYTHONPATH','TEMP','TMP','GODOT_VERSION_BUILD']}}
(ROOT/'build-result.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('Build finished',code,'elapsed',receipt['elapsed_s'],flush=True)
sys.exit(code)
