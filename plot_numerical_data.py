"""Replot supplied numerical data, without author-specific paths or new simulations."""
from pathlib import Path
import argparse,csv,io,json,math,zipfile
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def read_rows(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data',type=Path,default=Path(__file__).resolve().parent)
    parser.add_argument('--output',type=Path,default=Path('results'))
    args=parser.parse_args();d=args.data.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
    manifest=[]
    def save(fig,name,inputs,scope):
        fig.tight_layout()
        for ext in ('png','pdf'):fig.savefig(out/(name+'.'+ext),dpi=180,bbox_inches='tight')
        plt.close(fig);manifest.append(dict(output=name,inputs=inputs,scope=scope))
    pairs=read_rows(d/'numerical/data/Figure2c_49pairs.csv')
    series=read_rows(d/'viscosity/current/tfme_adopted_loading_series.csv')
    fig,axes=plt.subplots(1,2,figsize=(12,4.5))
    names=sorted({r['system'] for r in series})
    for s in names:
        rr=sorted([r for r in series if r['system']==s],key=lambda r:float(r['loading']))
        line,=axes[0].plot([float(r['loading']) for r in rr],[float(r['eta_cP']) for r in rr],'.-',ms=4,label=s)
        for r in rr:
            if r['included'].lower()!='true':axes[0].plot(float(r['loading']),float(r['eta_cP']),'o',mfc='white',mec=line.get_color(),ms=5)
    axes[0].set(xlabel='CO2 loading (mol/mol amine)',ylabel='Viscosity (cP)',yscale='log',title='Supplied loading series; open point excluded from fit')
    axes[0].legend(fontsize=6,ncol=2)
    x=np.array([float(r['exp_eta_interpolated_cP']) for r in pairs]);y=np.array([float(r['sim_eta_cP']) for r in pairs])
    axes[1].scatter(x,y,s=18);lo=min(x.min(),y.min())*.8;hi=max(x.max(),y.max())*1.2;axes[1].plot([lo,hi],[lo,hi],'--',color='gray',lw=1)
    axes[1].set(xscale='log',yscale='log',xlabel='Experimental viscosity (cP)',ylabel='Simulated viscosity (cP)',title=f'49 pairs; mean absolute log10 error = {np.mean(abs(np.log10(y/x))):.6f}')
    save(fig,'viscosity_data',['viscosity/current/tfme_adopted_loading_series.csv','numerical/data/Figure2c_49pairs.csv'],'Numerical replot; original publication layout and experimental interpolation are not regenerated.')
    cluster=read_rows(d/'numerical/data/Figure3h_16systems.csv');x=np.array([float(r['joint_index']) for r in cluster]);y=np.log([float(r['Viscosity_cP']) for r in cluster]);fit=np.polyfit(x,y,1)
    fig,ax=plt.subplots(figsize=(6,4));ax.scatter(x,y,s=25);xx=np.linspace(x.min(),x.max(),100);ax.plot(xx,np.polyval(fit,xx),lw=1)
    ax.set(xlabel='Supplied joint composition/mass index',ylabel='ln(viscosity / cP)',title=f'16 systems; R2 = {np.corrcoef(x,y)[0,1]**2:.6f}')
    save(fig,'composition_viscosity',['numerical/data/Figure3h_16systems.csv'],'OLS numerical relation; no molecular snapshot rendering.')
    with zipfile.ZipFile(d/'motion_contact_data.zip') as z:
        def zr(n):return list(csv.DictReader(io.StringIO(z.read(n).decode('utf-8-sig'))))
        motion=zr('displacement/all_three_MSD_Fs.csv');contact=zr('contact/all16_Figure4e_9ns_plot_data.csv')
    eta={r['System']:float(r['Viscosity_cP']) for r in cluster}
    fig,axes=plt.subplots(1,3,figsize=(13,4))
    for s in sorted({r['system'] for r in motion}):
        rr=sorted([r for r in motion if r['system']==s and float(r['lag_ps'])<=500],key=lambda r:float(r['lag_ps']))
        axes[0].plot([float(r['lag_ps']) for r in rr],[float(r['MSD_A2']) for r in rr],label=s)
        axes[1].plot([float(r['lag_ps']) for r in rr],[float(r['Fs']) for r in rr],label=s)
    axes[0].set(xlabel='Lag time (ps)',ylabel='COM MSD (angstrom squared)',title='Original 1 ns NVT; all valid origins');axes[0].legend(fontsize=7)
    axes[1].set(xlabel='Lag time (ps)',ylabel='Self-intermediate scattering function',title='Same molecular displacements')
    axes[2].scatter([eta[r['system']] for r in contact],[float(r['tau_pers_H9000_ns']) for r in contact],s=24)
    axes[2].set(xlabel='Viscosity (cP)',xscale='log',ylabel='Restricted persistence integral (ns)',title='Fixed origin 1 ns; observed to 10 ns')
    save(fig,'motion_and_contact',['motion_contact_data.zip!displacement/all_three_MSD_Fs.csv','motion_contact_data.zip!contact/all16_Figure4e_9ns_plot_data.csv'],'Replot exported curves and restricted 9 ns integrals; not full cluster lifetimes or a trajectory reanalysis.')
    ffv=read_rows(d/'FFV/current/Figure5_144conditions.csv');b=read_rows(d/'FFV/current/Figure5b_16systems.csv');c=read_rows(d/'FFV/current/Figure5c_temperature.csv')
    names=list(dict.fromkeys(r['system'] for r in ffv));loads=sorted({float(r['loading']) for r in ffv});lookup={(r['system'],float(r['loading'])):float(r['FFV']) for r in ffv}
    fig,axes=plt.subplots(1,3,figsize=(14,6),gridspec_kw={'width_ratios':[1.35,1,1]})
    im=axes[0].imshow([[lookup[s,L] for L in loads] for s in names],aspect='auto',cmap='viridis')
    axes[0].set_yticks(range(len(names)),names,fontsize=7);axes[0].set_xticks(range(len(loads)),[f'{L:.2f}' for L in loads],rotation=45);axes[0].set(xlabel='CO2 loading',title='144 supplied FFV conditions');fig.colorbar(im,ax=axes[0],label='FFV',fraction=.045)
    x=np.array([float(r['FFV']) for r in b]);y=np.log([float(r['eta_cP']) for r in b]);fit=np.polyfit(x,y,1);xx=np.linspace(x.min(),x.max(),100)
    axes[1].scatter(x,y,s=22);axes[1].plot(xx,np.polyval(fit,xx));axes[1].set(xlabel='FFV',ylabel='ln(viscosity / cP)',title=f'16 systems; R2 = {np.corrcoef(x,y)[0,1]**2:.3f}')
    axes[2].scatter([float(r['inverse_FFV']) for r in c],[float(r['ln_eta']) for r in c],s=25)
    for r in c:axes[2].annotate(r['temperature_K']+' K',(float(r['inverse_FFV']),float(r['ln_eta'])),fontsize=7,xytext=(3,3),textcoords='offset points')
    axes[2].set(xlabel='1 / FFV',ylabel='ln(viscosity / cP)',title='Separate temperature series; single-snapshot FFV')
    save(fig,'free_volume_data',['FFV/current/Figure5_144conditions.csv','FFV/current/Figure5b_16systems.csv','FFV/current/Figure5c_temperature.csv'],'Replot supplied FFV values; no insertion sampling or raw-trajectory processing.')
    (out/'plot_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('PASS: four numerical overview figures (PNG/PDF) and plot_manifest.json.')

if __name__=='__main__':main()
