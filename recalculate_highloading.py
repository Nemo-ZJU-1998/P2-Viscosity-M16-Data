from pathlib import Path
import json,gzip,math,csv
import argparse,zipfile,tempfile
_parser=argparse.ArgumentParser()
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_args=_parser.parse_args()
_tmp=tempfile.TemporaryDirectory()
R=Path(_tmp.name)
with zipfile.ZipFile(_args.data/'high_loading_viscosity.zip') as _z:
 for _n in _z.namelist():
  if not (R/_n).resolve().is_relative_to(R.resolve()):raise ValueError('Unsafe ZIP path')
 _z.extractall(R)
def ols(x,y):
 n=len(x);mx=sum(x)/n;my=sum(y)/n;sxx=sum((v-mx)**2 for v in x);b=sum((a-mx)*(v-my) for a,v in zip(x,y))/sxx;a=my-b*mx;sse=sum((v-a-b*u)**2 for u,v in zip(x,y));sst=sum((v-my)**2 for v in y)
 return dict(intercept=a,slope=b,intercept_SE=math.sqrt(sse/(n-2)*(1/n+mx*mx/sxx)),R2=1-sse/sst)
a=json.loads((R/'tfme_analysis.json').read_text(encoding='utf-8'));out={}
for system,g in a['adopted'].items():
 x=[];y=[]
 for point in g['points']:
  amp=point['lambda'];base=R/'raw'/system/'loading_0.40';f=next(d/'inverse_viscosity.xvg.gz' for d in base.glob('lambda_*') if abs(float(d.name.removeprefix('lambda_'))-amp)<1e-9);vals=[]
  with gzip.open(f,'rt') as h:
   for line in h:
    if not line.strip() or line.lstrip().startswith(('#','@')):continue
    t,v=map(float,line.split()[:2])
    if 1000<=t<2500:vals.append(v)
  assert len(vals)==15000
  x.append(amp);y.append(1000/(sum(vals)/len(vals)))
 fit=ols(x,y);assert abs(fit['intercept']-g['eta'])<1e-7;assert abs(fit['intercept_SE']-g['SE'])<1e-7;out[system]=fit
rows=list(csv.DictReader((R/'tfme_adopted_loading_series.csv').open(encoding='utf-8-sig')));assert sum(r['included'].lower()=='true' for r in rows)==134
for system in a['adopted']:
 rr=[r for r in rows if r['system']==system and r['included'].lower()=='true'];fit=ols([float(r['loading']) for r in rr],[math.log(float(r['eta_cP'])) for r in rr]);assert len(rr)==9;assert abs(fit['slope']-a['fits'][system]['B'])<1e-10;out[system]['loading_fit']=fit
print(json.dumps(out,indent=2))
