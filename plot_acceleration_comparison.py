from pathlib import Path
import csv
import argparse
_parser=argparse.ArgumentParser(description='Reproduce from the published data archive.')
_parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
_parser.add_argument('--output',type=Path,default=Path('results'))
_args=_parser.parse_args()
OUT=(_args.data/'SI/compact').resolve()
_output=_args.output.resolve()
_output.mkdir(parents=True,exist_ok=True)
with (OUT/"acceleration_window_comparison.csv").open(encoding="utf-8-sig",newline="") as f:rr=list(csv.reader(f))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.family':'Arial','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(7.3,4.3));labels=[]
for i,row in enumerate(rr[1:]):
 centre,se=[float(x.strip()) for x in row[1].split('±')];low=float(row[2]);quad=float(row[4]);y=5-i
 ax.plot([min(centre,low,quad),max(centre,low,quad)],[y,y],color='0.8',lw=.8,zorder=0)
 ax.errorbar(centre,y+.12,xerr=se,fmt='o',color='#444444',mfc='white' if i==3 else '#444444',ms=5,capsize=3,label='Adopted fit ± intercept SE' if i==0 else None)
 ax.scatter(low,y,marker='s',s=28,color='#0072B2',label='Lowest four accelerations' if i==0 else None)
 ax.scatter(quad,y-.12,marker='^',s=33,color='#D55E00',label='Fit against squared acceleration' if i==0 else None)
 labels.append(row[0].replace('@',', L = ').replace('Me3Si',r'Me$_3$Si').replace('M2BOL',r'M$_2$BOL'))
ax.set_yticks(list(reversed(range(6))),labels);ax.set_xscale('log');ax.set_xlabel('Extrapolated viscosity (cP)');ax.set_ylim(-.6,6.65)
ax.legend(loc='upper left',fontsize=9,frameon=False);fig.tight_layout()
fig.savefig(_output/'acceleration_window_comparison.png',dpi=250,bbox_inches='tight');fig.savefig(_output/'acceleration_window_comparison.pdf',bbox_inches='tight');plt.close(fig)
