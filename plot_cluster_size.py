"""Reproduce 16-system Figure 3(g)-style SI panels from archived count tables.
Run: python build_supplement.py
Requires numpy, pandas, matplotlib. No viscosity fitting or new MD is performed.
"""
from pathlib import Path
import json, hashlib, shutil
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

import argparse
_parser=argparse.ArgumentParser(description='Reproduce 16-system cluster-size distributions from archived counts.')
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_parser.add_argument('--output',type=Path,default=Path('results/plots'))
_args=_parser.parse_args()
INPUT=_args.data.resolve()/'SI/cluster_size/inputs'
OUT=_args.output.resolve();OUT.mkdir(parents=True,exist_ok=True)
systems=pd.read_csv(INPUT/'systems.csv')
assert len(systems)==16 and systems.System.nunique()==16
for item in json.loads((INPUT/'source_manifest.json').read_text(encoding='utf-8')):
    copied_name=Path(item['copy'].replace('\\', '/')).name
    assert hashlib.sha256((INPUT/copied_name).read_bytes()).hexdigest()==item['sha256']
cols=['n_F','n_C','n_P','n_Z']
summary=[]; detail=[]; plotrows=[]; results={}; checks=[]
for r in systems.itertuples():
    m=json.loads((INPUT/f'{r.System}_metrics.json').read_text(encoding='utf-8'))
    raw=pd.read_csv(INPUT/f'{r.System}_cluster_type_dist.csv')
    sizes=pd.read_csv(INPUT/f'{r.System}_cluster_size_dist.csv')
    c=raw[cols].to_numpy(dtype=int); n=raw.n_clusters.to_numpy(dtype=int)
    assert np.all(c.sum(axis=1)>1) and np.all(n>=0)
    assert not raw.duplicated(cols).any()
    N=int(m['n_molecules']);nf=int(m['n_frames_used']);den=N*nf
    assert N==r.N==2000 and nf==r.n_frames==101
    population=np.array([m['mol_type_counts'].get(t,0) for t in 'FCPZ'])
    single=population*nf-(c*n[:,None]).sum(axis=0)
    assert np.all(single>=0)
    c=np.vstack([c,np.eye(4,dtype=int)]);n=np.r_[n,single];s=c.sum(axis=1)
    assert (s*n).sum()==den
    recovered=pd.Series(s*n).groupby(s).sum().sort_index()
    expected=sizes.set_index('cluster_size').n_molecules.sort_index()
    assert np.array_equal(recovered.index,expected.index) and np.array_equal(recovered.values,expected.values)
    assert np.allclose(sizes.mass_fraction,sizes.n_molecules/den) # historical header is molecule fraction
    target=(c[:,0]==0)&(((c[:,1]==c[:,2])&(c[:,1]>0)&(c[:,3]==0))|((c[:,1]==0)&(c[:,2]==0)&(c[:,3]>=2)))
    fs=(s==1)&(c[:,0]==1);zs=(s==1)&(c[:,3]==1)
    masks={'target':target,'ZW':zs,'F':fs,'other':~(target|zs|fs)}
    bins={key:np.bincount(np.minimum(s[mask],10)-1,weights=s[mask]*n[mask],minlength=10)/den for key,mask in masks.items()}
    assert np.isclose(sum(x.sum() for x in bins.values()),1)
    assert np.isclose(100*(bins['target'].sum()+bins['ZW'].sum()),r.f_all_pct)
    tet=s==4; nt=int(n[tet].sum()); ntt=int(n[tet&target].sum())
    assert nt>0 and np.isclose(4*nt/den,m['frac_size4'])
    if r.Family!='guanidine':assert np.isclose(4*ntt/den,m['frac_2C2P'])
    label='4ZW' if r.Family=='guanidine' else 'C2P2'
    record=dict(ID=r.ID,System=r.System,target_composition=label,N=N,n_frames=nf,
        tetramer_cluster_observations=nt,target_tetramer_cluster_observations=ntt,
        target_within_tetramers_pct=100*ntt/nt,all_tetramers_all_box_molecule_pct=400*nt/den,
        target_tetramers_all_box_molecule_pct=400*ntt/den,
        F_monomers_all_box_molecule_pct=100*single[0]/den,ZW_monomers_all_box_molecule_pct=100*single[3]/den)
    summary.append(record)
    observed={tuple(v):int(count) for v,count in zip(c[tet],n[tet])}
    possibilities=[(f,0,0,4-f) for f in range(5)] if r.Family=='guanidine' else [(f,cc,4-f-cc,0) for f in range(5) for cc in range(5-f)]
    assert set(observed).issubset(possibilities)
    for v in possibilities:
        count=observed.get(v,0)
        detail.append(dict(ID=r.ID,System=r.System,**dict(zip(cols,map(int,v))),n_clusters=int(count),
            within_tetramers_pct=100*count/nt,all_box_molecule_pct=400*count/den))
    for b in range(10):
        plotrows.append(dict(ID=r.ID,System=r.System,cluster_size_bin=str(b+1) if b<9 else '>=10',**{k:float(v[b]) for k,v in bins.items()}))
    results[r.System]=(bins,record)
    checks.append(dict(system=r.System,composition_conserved=True,size_histogram_reproduced=True,
        molecule_fraction_sum=float(sum(v.sum() for v in bins.values())),adopted_fraction_reproduced=True))

df=pd.DataFrame(summary);df.to_csv(OUT/'tetramer_summary_16.csv',index=False,float_format='%.10g')
pd.DataFrame(detail).to_csv(OUT/'tetramer_compositions_16.csv',index=False,float_format='%.10g')
pd.DataFrame(plotrows).to_csv(OUT/'cluster_size_plot_data_16.csv',index=False,float_format='%.12g')
assert np.allclose(df.set_index('System').loc[['IPADM2BOL','EEMPA','Me3SiNHDiGly'],'target_within_tetramers_pct'].round(1),[15.4,75.7,98.6])
(OUT/'validation.json').write_text(json.dumps(dict(n_systems=16,all_passed=True,checks=checks),indent=2),encoding='utf-8')

plt.rcParams.update({'font.family':'Arial','font.size':9,'mathtext.fontset':'stixsans','svg.fonttype':'none',
    'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.65,'xtick.major.width':.6,'ytick.major.width':.6})
colors={'target':'#355C9A','other':'#CFD6DD','F':'#E9EDF1','ZW':'#D9CCEB'}
outlines={'ether-amine':'#0072B2','guanidine':'#CC79A7','silane-alkoxy':'#009E73'}
def chem(name):
    return name.replace('Me3','Me$_3$').replace('Et3','Et$_3$').replace('NH2','NH$_2$').replace('M2BOL','M$_2$BOL')
fig,axes=plt.subplots(4,4,figsize=(8.6,9.0),sharex=True,sharey=True)
x=np.arange(1,11)
for ax,r in zip(axes.flat,systems.itertuples()):
    bins,rec=results[r.System];bottom=np.zeros(10)
    ax.axvspan(3.5,4.5,color='#E4E8EC',zorder=0)
    for key in ['target','other','F','ZW']:
        ax.bar(x,bins[key],bottom=bottom,width=.78,color=colors[key],edgecolor='white',linewidth=.3,zorder=2);bottom+=bins[key]
    ax.bar(x,bottom,width=.78,facecolor='none',edgecolor=outlines[r.Family],linewidth=.55,zorder=3)
    ax.set_title(f'{r.ID}. {chem(r.System)}',loc='left',fontsize=10,pad=20)
    label=r'$4\mathrm{ZW}$' if r.Family=='guanidine' else r'$\mathrm{C}_2\mathrm{P}_2$'
    ax.text(.02,1.025,f'{label} in size 4: {rec["target_within_tetramers_pct"]:.1f}%',transform=ax.transAxes,fontsize=9,color=colors['target'])
    assert bottom.max()<=1
    ax.set(xlim=(.35,10.65),ylim=(0,1),xticks=x,xticklabels=[*map(str,range(1,10)),r'$\geq10$'],yticks=np.arange(0,1.01,.2))
    ax.tick_params(labelsize=9,length=3,pad=2,labelbottom=True)
    ax.grid(axis='y',color='.92',linewidth=.45,zorder=0)
fig.supxlabel('Cluster size (molecules)',y=.078,fontsize=11)
fig.supylabel('Molecule fraction (all molecules)',x=.015,fontsize=11)
fig.legend(handles=[Patch(facecolor=colors[k],label=t) for k,t in [('target','F-free target aggregates'),('other','Other compositions'),('F','F monomers'),('ZW','Isolated ZW')]],loc='lower center',bbox_to_anchor=(.52,.007),ncol=2,frameon=False,fontsize=10)
fig.suptitle(r'313 K; $\alpha=0.25$ mol CO$_2$/mol amine',fontsize=12,y=.985)
fig.subplots_adjust(left=.082,right=.99,bottom=.14,top=.90,wspace=.23,hspace=.65)
for ext in ['png','pdf','svg']:fig.savefig(OUT/f'FigureS_cluster_size_16.{ext}',dpi=300)
plt.close(fig)

print('PASS: 16 cluster-size distributions; composition conservation and target fractions verified.')
