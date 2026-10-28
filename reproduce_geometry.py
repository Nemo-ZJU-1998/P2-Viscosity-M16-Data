"""Validate the supplied, adopted geometric descriptors; no energy calculation."""
from pathlib import Path
import csv,re,math,hashlib,statistics
import argparse
_parser=argparse.ArgumentParser(description='Reproduce from the published data archive.')
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_parser.add_argument('--output',type=Path,default=Path('results'))
_args=_parser.parse_args()
R=(_args.data/'geometry').resolve()
_output=_args.output.resolve()
_output.mkdir(parents=True,exist_ok=True)
def rows(p):return list(csv.DictReader((R/p).open(encoding='utf-8-sig')))
def parse(data):
 blocks=re.findall(r'(?:Standard|Input) orientation:.*?\n\s*-+\s*\n.*?\n\s*-+\s*\n(.*?)\n\s*-+',data.decode('utf-8',errors='replace'),re.S)
 assert blocks
 return [[int(t[1]),*[float(v) for v in t[3:6]]] for l in blocks[-1].splitlines() if len(t:=l.split())==6]
for r in rows('M14/TableS4_geometry/contacts.csv'):
 data=(R/'M14/TableS4_geometry'/r['raw_file']).read_bytes();assert hashlib.sha256(data).hexdigest()==r['sha256'];atoms=parse(data)
 D,H,A=[atoms[int(r[k])-1][1:] for k in ['donor_atom_1based','hydrogen_atom_1based','acceptor_atom_1based']]
 u=[d-h for d,h in zip(D,H)];v=[a-h for a,h in zip(A,H)];angle=math.degrees(math.acos(max(-1,min(1,sum(a*b for a,b in zip(u,v))/(math.dist(D,H)*math.dist(A,H))))))
 for value,key,tol in [(math.dist(H,A),'H_A_A',.002),(math.dist(D,A),'D_A_A',.002),(angle,'D_H_A_deg',.12)]:assert abs(value-float(r[key]))<tol,(r['system'],key)
for r in rows('M11/TableS7_geometry/adopted_geometric_columns.csv'):
 label=r['system_loading'];a=rows('M11/TableS7_geometry/'+label+'_atom_contact_counts.csv');b=rows('M11/TableS7_geometry/'+label+'_tetramer_counts.csv')
 c=statistics.mean(float(v['n_vdw_apolar_inter'])/(float(v['n_vdw_apolar_inter'])+float(v['n_vdw_apolar_intra'])) for v in a);t=statistics.mean(float(v['tetramer_frac_stoich2p2c']) for v in b if math.isfinite(float(v['tetramer_frac_stoich2p2c'])))
 assert abs(c-float(r['reported_contact_fraction']))<.00051
 assert abs(t-float(r['reported_tetramer_fraction']))<.00051
for r in rows('M11/TableS7_geometry/effective_pair_summary.csv'):
 a=rows('M11/TableS7_geometry/'+r['system']+'_effective_pair_counts.csv')
 for v in a:assert abs(float(v['effective_between_pair_share'])-float(v['between_n'])/(float(v['between_n'])+float(v['within_n'])))<1e-12
 assert abs(statistics.mean(float(v['effective_between_pair_share']) for v in a)*100-float(r['mean_between_effective_pair_percent']))<1e-10
print('PASS: eight TableS4 optimized donor-acceptor geometries; thirteen TableS7 geometric-descriptor rows; three effective-pair count summaries. Only reported geometry is validated, not a viscosity mechanism.')
