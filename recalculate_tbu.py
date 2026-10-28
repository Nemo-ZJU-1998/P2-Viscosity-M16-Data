from pathlib import Path
import csv,statistics,math
import argparse
_parser=argparse.ArgumentParser(description='Reproduce from the published data archive.')
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_parser.add_argument('--output',type=Path,default=Path('results'))
_args=_parser.parse_args()
R=(_args.data/'viscosity/tBu_corrected').resolve()
_output=_args.output.resolve()
_output.mkdir(parents=True,exist_ok=True)
for row in csv.DictReader((R/'tBu_corrected_viscosity_313K.csv').open(encoding='utf-8-sig')):
 d=R/'gromacs_results'/('CO2_loading_'+format(float(row['loading']),'.2f'))/'result';xs=[];ys=[]
 for a in row['accelerations'].split(';'):
  x=float(a);p=next(p for p in sorted(d.glob('Viscosity_313_*')) if p.suffix in ['.xvg','.txt'] and abs(float(p.stem.split('_')[-1])-x)<1e-9);v=[]
  for line in p.read_text(encoding='utf-8').splitlines():
   if not line.strip() or line.startswith(('#','@')):continue
   t,q=map(float,line.split()[:2])
   if 200-1e-7<=t<=450+1e-7:v.append(q)
  xs.append(x);ys.append(1000/statistics.mean(v))
 n=len(xs);xb=statistics.mean(xs);yb=statistics.mean(ys);sxx=sum((x-xb)**2 for x in xs);b=sum((x-xb)*(y-yb) for x,y in zip(xs,ys))/sxx;a=yb-b*xb;sse=sum((y-a-b*x)**2 for x,y in zip(xs,ys));se=math.sqrt(sse/(n-2)*(1/n+xb*xb/sxx));r2=1-sse/sum((y-yb)**2 for y in ys)
 assert abs(a-float(row['eta0_cP']))<1e-7 and abs(se-float(row['intercept_SE_cP']))<1e-7
 print(row['loading'],a,se,r2)
