"""Verify released numerical inputs and optionally regenerate selected figures."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,tempfile,zipfile


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
    p.add_argument('--output',type=Path,default=Path('results'))
    p.add_argument('--plots',action='store_true',help='Requires the versions in requirements.txt.')
    a=p.parse_args();d=a.data.resolve();o=a.output.resolve();code=Path(__file__).resolve().parent
    if sys.flags.optimize:raise SystemExit('Run without -O: the scientific checks use assertions.')
    if not (d/'SHA256.json').is_file():raise SystemExit('Extract P2_viscosity_data_20261028_v1.zip and pass its directory with --data.')
    o.mkdir(parents=True,exist_ok=True)
    checks=[];env=os.environ.copy();env.update(PYTHONIOENCODING='utf-8',MPLCONFIGDIR=str(o/'matplotlib_cache'))
    def run(name,args):
        proc=subprocess.run([sys.executable,str(code/name),*args],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace')
        (o/(name.removesuffix('.py')+'.log')).write_text(proc.stdout+'\n'+proc.stderr,encoding='utf-8')
        checks.append(dict(script=name,exit_code=proc.returncode))
        print(name+': '+('PASS' if proc.returncode==0 else 'FAIL'),flush=True)
        if proc.returncode:raise RuntimeError(proc.stderr or proc.stdout)
    base=['--data',str(d)]
    for name in ['verify_numerical_inputs.py','recalculate_tbu.py','recalculate_highloading.py','reproduce_geometry.py']:run(name,base)
    with tempfile.TemporaryDirectory() as tmp:
        target=Path(tmp)
        with zipfile.ZipFile(d/'motion_contact_data.zip') as z:
            for name in z.namelist():
                if not (target/name).resolve().is_relative_to(target.resolve()):raise ValueError('Unsafe ZIP path')
            z.extractall(target)
        proc=subprocess.run([sys.executable,str(target/'validate_source_data.py')],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace')
        (o/'verify_motion_contact.log').write_text(proc.stdout+'\n'+proc.stderr,encoding='utf-8')
        checks.append(dict(script='motion_contact_data.zip!validate_source_data.py',exit_code=proc.returncode))
        if proc.returncode:raise RuntimeError(proc.stderr or proc.stdout)
        print('Motion and continuous-contact data: PASS',flush=True)
    if a.plots:
        for name in ['plot_selected_regressions.py','plot_acceleration_comparison.py','plot_numerical_data.py','plot_cluster_size.py']:run(name,base+['--output',str(o/'plots')])
    report={'status':'PASS','python':sys.version,'checks':checks,'data_manifest_sha256':hashlib.sha256((d/'SHA256.json').read_bytes()).hexdigest(),'scope':'Supplied numerical inputs, exported inverse-viscosity series, geometric descriptors and selected plots. No fresh MD, full trajectory reanalysis or molecular-scene reconstruction.','numbering':'Source filenames may retain historical labels. Consult SOURCE_INDEX.csv and the numbering map for this release snapshot.'}
    (o/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('PASS: results recorded in '+str(o/'verification.json'))

if __name__=='__main__':main()
