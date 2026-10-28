"""Reproduce adopted Me3SiNHGly regressions from documented selected inputs.
OLS is unweighted. Point bars are archived five-block 95% CIs; printed +/- is
the OLS intercept SE; shading is a 95% confidence band for the mean regression.
No new trajectory or fitted intercept adjustment is used.
"""
from pathlib import Path
import csv,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
import argparse
_parser=argparse.ArgumentParser(description='Reproduce from the published data archive.')
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_parser.add_argument('--output',type=Path,default=Path('results'))
_args=_parser.parse_args()
O=(_args.data/'SI/Me3SiNHGly_S15').resolve()
_output=_args.output.resolve()
_output.mkdir(parents=True,exist_ok=True)
rows=list(csv.DictReader((O/'selected_points.csv').open(encoding='utf-8-sig')))
T975={2:4.302652729911275,3:3.182446305284263,4:2.7764451051977987,5:2.570581835636314}
plt.rcParams.update({'font.family':'Arial','font.size':7.5,'axes.labelsize':7.5,'axes.titlesize':7.5,'xtick.labelsize':7,'ytick.labelsize':7,'axes.linewidth':.6,'axes.spines.top':False,'axes.spines.right':False,'xtick.major.width':.6,'ytick.major.width':.6,'xtick.major.size':2.4,'ytick.major.size':2.4,'savefig.bbox':'tight','savefig.pad_inches':.02,'pdf.fonttype':42,'mathtext.fontset':'custom','mathtext.rm':'Arial','mathtext.it':'Arial:italic'})
fig,axes=plt.subplots(3,3,figsize=(7.2,6.15));manifest=[]
for k,ax in enumerate(axes.ravel()):
 d=[r for r in rows if r['panel']=='abcdefghi'[k]]
 x=np.array([float(r['acceleration']) for r in d]);y=np.array([float(r['eta_cP']) for r in d]);err=np.array([float(r['point_block_ci95_cP']) for r in d])
 n=len(x);xb=x.mean();sxx=((x-xb)**2).sum();slope=((x-xb)*(y-y.mean())).sum()/sxx;b=y.mean()-slope*xb;rss=((y-b-slope*x)**2).sum();s2=rss/(n-2);se=np.sqrt(s2*(1/n+xb*xb/sxx));r2=1-rss/((y-y.mean())**2).sum()
 target=float(d[0]['adopted_intercept_cP']);assert abs(b-target)<.00051,(k,b,target)
 xs=np.linspace(0,x.max()*1.06,200);yh=b+slope*xs;ci=T975[n-2]*np.sqrt(s2*(1/n+(xs-xb)**2/sxx))
 ax.fill_between(xs,yh-ci,yh+ci,color='#D55E00',alpha=.13,lw=0)
 ax.plot(xs,yh,color='#D55E00',lw=1,zorder=3)
 ax.errorbar(x,y,yerr=err,fmt='o',ms=3.2,mfc='#0072B2',mec='white',mew=.4,ecolor='#0072B2',elinewidth=.6,capsize=1.6,capthick=.6,zorder=4)
 ax.plot([0],[b],marker='*',ms=7.5,mfc='#E69F00',mec='#333333',mew=.4,zorder=5,clip_on=False)
 ax.set_xlim(0,x.max()*1.06);ax.set_ylim(min(0,(y-err).min()),max((y+err).max(),b)*1.32)
 ax.xaxis.set_major_locator(MaxNLocator(nbins=4));ax.yaxis.set_major_locator(MaxNLocator(nbins=4));ax.grid(False)
 ax.text(-.20,1.10,'abcdefghi'[k],transform=ax.transAxes,fontsize=8,fontweight='bold',va='top')
 ax.set_title('CO$_2$ = %.2f mol mol$^{-1}$'%float(d[0]['loading']),loc='left',pad=3)
 ax.text(.97,.95,'$\\eta_0$ = %.3f $\\pm$ %.3f\n$R^2$ = %.3f'%(b,se,r2),transform=ax.transAxes,fontsize=7.5,va='top',ha='right')
 if k//3==2:ax.set_xlabel('$\\Lambda$ (nm ps$^{-2}$)')
 if k%3==0:ax.set_ylabel('η (cP)')
 manifest.append(dict(panel='abcdefghi'[k],loading=float(d[0]['loading']),selected_accelerations=x.tolist(),intercept_cP=b,intercept_SE_cP=se,slope=slope,R2=r2,n=n,adopted_intercept_cP=target,source=d[0]['summary']))
fig.subplots_adjust(wspace=.30,hspace=.42)
for ext in ['png','pdf']:fig.savefig(_output/f'FigureS15_verified_subsets.{ext}',dpi=300)
plt.close(fig)
(_output/'panel_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print(json.dumps(manifest,indent=2))
