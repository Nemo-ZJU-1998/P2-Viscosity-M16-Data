# Viscosity of water-lean CO2 absorbents

Numerical data and analysis code for a study of viscosity, aggregate composition, molecular motion and fractional free volume in single-component, water-lean CO2 absorbents.

## Download

Download **[viscosity-data-20261028-v2.zip](https://github.com/Nemo-ZJU-1998/Water-Lean-Absorbent-Viscosity/releases/download/data-20261028-v2/viscosity-data-20261028-v2.zip)** from the [versioned data release](https://github.com/Nemo-ZJU-1998/Water-Lean-Absorbent-Viscosity/releases/tag/data-20261028-v2). The archive includes the scripts below, numerical inputs, small simulation-parameter files and source indexes. Raw trajectories are not included.

## Run

Use Python 3.12. From the directory containing the downloaded ZIP:

```bash
python -m zipfile -e viscosity-data-20261028-v2.zip data
python data/reproduce.py --data data --output results
```

Numerical checks use only the Python standard library. To generate the selected plots, install the plotting dependencies in a virtual environment and run:

```bash
python -m pip install -r data/requirements.txt
python data/reproduce.py --data data --output results --plots
```

The tested plotting versions are NumPy 2.3.5, pandas 3.0.1 and Matplotlib 3.11.2. The complete environment is listed in `environment.txt`.

## Outputs

`results/verification.json` records the checks and their exit codes. `results/plots/` contains seven figures in PNG and PDF: four numerical overviews, the selected Me3SiNHGly regressions, the acceleration-sensitivity comparison, and the 16-system cluster-size distributions. Overview plots reproduce the supplied numerical relationships, not the original publication layout or molecular illustrations.

Expected results include 49 experimental-comparison pairs with a mean absolute log10 error of **0.1369936364**, 134 retained viscosity-loading inputs, and 144 free-volume conditions. Recalculation of the Si-free tBuNHDiGly series gives **9.490217 +/- 0.581163 cP** at loading 0.25.

## Find a result

| Content | Input location in the archive | Runnable code |
|---|---|---|
| Viscosity comparisons and loading series | `numerical/data/`, `viscosity/current/` | `verify_numerical_inputs.py`, `plot_numerical_data.py` |
| tBuNHDiGly viscosity extrapolation | `viscosity/tBu_corrected/` | `recalculate_tbu.py` |
| High-loading viscosity extrapolation | `high_loading_viscosity.zip` | `recalculate_highloading.py` |
| Cluster-size distributions | `SI/cluster_size/inputs/` | `plot_cluster_size.py` |
| Aggregate composition and viscosity | `numerical/data/Figure3h_16systems.csv` | `plot_numerical_data.py` |
| Molecular displacement and contact persistence | `motion_contact_data.zip` | `reproduce.py`, `plot_numerical_data.py` |
| Fractional free volume | `FFV/current/` | `plot_numerical_data.py` |
| Selected regression and acceleration comparisons | `SI/Me3SiNHGly_S15/`, `SI/compact/` | `plot_selected_regressions.py`, `plot_acceleration_comparison.py` |

[SOURCE_INDEX.csv](SOURCE_INDEX.csv) gives figure/table-level locations. [CODE_INDEX.csv](CODE_INDEX.csv) lists runnable entry points. The numbering map identifies the 23 SI figures and 13 SI tables indexed in this data release; source filenames and complete supporting tables can retain earlier labels. `ARCHIVED_SOURCE_INDEX.csv` identifies data retained for transparency but no longer displayed as numbered SI items. The acceleration-sensitivity plot is supplementary diagnostic material.

## Interpretation and scope

The tBuNHDiGly estimates use the corrected Si-free model and the 200-450 ps interval of each 500 ps production run. Their uncertainties are conditional extrapolation-intercept standard errors. The two high-loading calculations use their separately documented 1000-2500 ps interval.

Molecular-displacement and scattering curves use the original 1 ns NVT trajectories. Continuous-contact persistence uses a fixed absolute origin at 1 ns and observations to 10 ns. Its restricted 9 ns integral is not a complete cluster lifetime.

The scripts verify supplied numerical data and selected calculations; they do not rerun all molecular dynamics simulations or reconstruct every figure from raw coordinates. Original trajectory-analysis scripts require additional inputs and path configuration. Raw trajectories are available from the corresponding author on reasonable request.

[KNOWN_GAPS.json](KNOWN_GAPS.json) and [SOURCE_GAPS_BY_ITEM.csv](SOURCE_GAPS_BY_ITEM.csv) identify missing illustration/profile inputs, unverified experimental-density provenance, and three unresolved viscosity-centre differences. No unmatched uncertainty estimates are substituted. SHA256.json lists the checksums of the archive contents.

Third-party attribution and applicable terms are retained. This deposit does not grant a new licence to third-party material.
