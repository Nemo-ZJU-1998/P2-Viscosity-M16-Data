"""Create a separately configured copy of the simulation sources; never run jobs."""
from pathlib import Path
import argparse, hashlib, json, re, shutil

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--runtime-root',required=True,help='Absolute Linux path where the configured copy will run')
    args=parser.parse_args(); root=Path(__file__).resolve().parent
    runtime=args.runtime_root.rstrip('/')
    if not re.fullmatch(r'/[A-Za-z0-9_./-]+',runtime) or '..' in Path(runtime).parts:
        parser.error('Use an absolute Linux path without whitespace, shell metacharacters or parent traversal.')
    out=args.output.absolute()
    if out.exists():parser.error('Output already exists; choose a new directory.')
    manifest=json.loads((root/'SOURCE_MANIFEST.json').read_text(encoding='utf-8'))
    for item in manifest:
        p=root/item['path']
        if hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:
            raise SystemExit('Source checksum mismatch: '+item['path'])
    out.mkdir(parents=True)
    for folder in ['Viscosity_cal','dataprocess','reference_charges','variants']:
        shutil.copytree(root/folder,out/folder)
    changes=[]
    for p in out.rglob('*'):
        if not p.is_file() or p.suffix not in {'.py','.sh','.slurm','.bsh','.tcl'}:continue
        old=p.read_bytes();text=old.decode('utf-8-sig')
        text=text.replace('/work/home/xuwenhao/Viscosity_cal/21_EEMPA',runtime+'/Viscosity_cal/21')
        text=text.replace('/work/home/xuwenhao/',runtime+'/')
        p.write_text(text,encoding='utf-8',newline='\n');p.chmod(0o755)
        if p.read_bytes()!=old:changes.append({'path':p.relative_to(out).as_posix(),'source_sha256':hashlib.sha256(old).hexdigest(),'configured_sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    (out/'PATH_CONFIGURATION.json').write_text(json.dumps({'runtime_root':runtime,'files':changes,'jobs_submitted':0,'note':'Review scheduler resources, software environment paths, restart state and historical dependencies before running.'},indent=2),encoding='utf-8')
    print('Configured source copy:',out)
    print('No jobs submitted. Review the run requirements in README.md.')
if __name__=='__main__':main()
