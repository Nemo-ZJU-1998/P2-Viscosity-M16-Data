from pathlib import Path
import csv,io,json,zipfile,hashlib,math,statistics
import argparse
_parser=argparse.ArgumentParser(description='Reproduce from the published data archive.')
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_parser.add_argument('--output',type=Path,default=Path('results'))
_args=_parser.parse_args()
R=(_args.data/'.').resolve()
_output=_args.output.resolve()
_output.mkdir(parents=True,exist_ok=True)
def rows(p):return list(csv.DictReader((R/p).open(encoding='utf-8-sig')))
def r2(x,y):
 xm=statistics.mean(x);ym=statistics.mean(y);return sum((a-xm)*(b-ym) for a,b in zip(x,y))**2/(sum((a-xm)**2 for a in x)*sum((b-ym)**2 for b in y))
pairs=rows('numerical/data/Figure2c_49pairs.csv');assert len(pairs)==49
mae=statistics.mean(abs(math.log10(float(p['sim_eta_cP'])/float(p['exp_eta_interpolated_cP']))) for p in pairs);assert abs(mae-.13699363640178025)<1e-10
series=rows('viscosity/current/tfme_adopted_loading_series.csv');assert sum(r['included']=='True' for r in series)==134
for s,expected in [('IPATFMM2BOL',4335.161501092471),('MEIPADM2BOL',121.14103978238163)]:assert abs(float(next(r for r in series if r['system']==s and float(r['loading'])==.4)['eta_cP'])-expected)<1e-9
cluster=rows('numerical/data/Figure3h_16systems.csv');assert len(cluster)==16;assert abs(r2([math.log(float(r['Viscosity_cP'])) for r in cluster],[float(r['joint_index']) for r in cluster])-.8630288377837207)<1e-9
ffv=rows('FFV/current/Figure5_144conditions.csv');assert len(ffv)==144 and len({(r['system'],r['loading']) for r in ffv})==144 and all(int(r['n_frames'])==1001 for r in ffv)
b=rows('FFV/current/Figure5b_16systems.csv');assert len(b)==16 and abs(r2([float(r['FFV']) for r in b],[math.log(float(r['eta_cP'])) for r in b])-.791)<.0005
with zipfile.ZipFile(R/'motion_contact_data.zip') as z:
 table=list(csv.DictReader(io.StringIO(z.read('contact/all16_Figure4e_9ns_plot_data.csv').decode('utf-8-sig'))));curves=list(csv.DictReader(io.StringIO(z.read('contact/all16_C_cont_fixed1ns_0_9ns.csv').decode('utf-8-sig'))));motion=list(csv.DictReader(io.StringIO(z.read('displacement/all_three_MSD_Fs.csv').decode('utf-8-sig'))));assert len(table)==16 and len(curves)==9001
 for t in table:assert int(t['origin_absolute_ps'])==1000 and int(t['horizon_ps'])==9000 and abs(sum(float(c[t['system']]) for c in curves[:-1])*.001-float(t['tau_pers_H9000_ns']))<1e-9
 assert len([r for r in motion if float(r['lag_ps'])==500 and int(r['n_origins'])==501])==3
for name,digest in json.loads((R/'SHA256.json').read_text(encoding='utf-8')).items():assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
print('PASS: 49 pairs/MAE, 134 retained loading points, 16-system cluster and FFV data, 144 conditions, current Figure4 conventions and package hashes. This validates frozen numerical inputs, not fresh MD or every original-coordinate analysis.')
