# Data and analysis code

This repository provides the data and analysis code supporting our study of viscosity in single-component, water-lean CO₂ absorbents.

## Download

- [Numerical data and analysis code (23 MB)](https://github.com/Nemo-ZJU-1998/P2-Viscosity-M16-Data/releases/download/M16-20261024-v4/M16_source_data_20261024_v4.zip): data tables, analysis scripts, model parameters and source information.
- [Supporting computational files (395 MB)](https://github.com/Nemo-ZJU-1998/P2-Viscosity-M16-Data/releases/download/M16-20261024-v4/M16_evidence_20261024_v4.zip): archived simulation settings, parameter files and quantum-chemical records.

Only the first download is needed to run the numerical analyses. Both files are available in the [versioned release](https://github.com/Nemo-ZJU-1998/P2-Viscosity-M16-Data/releases/tag/M16-20261024-v4).

## Run the analyses

Use Python 3.12, preferably in a new virtual environment. From the folder containing the downloaded numerical archive, run:

```bash
python -m zipfile -e M16_source_data_20261024_v4.zip data
python -m pip install -r data/requirements.txt
python data/verify_checksums.py
python data/reproduce_current.py
```

Run the checksum check before the analyses, which regenerate some result files. The numerical summary is written to `data/results/current_verification.json`. It includes the viscosity–loading fits, structure–viscosity regressions, energy correlations and other numerical results reported in the paper. For example, the seven-system experimental comparison contains 49 pairs and gives a logarithmic MAE of 0.1369936364.

To recalculate the nine tBuNHDiGly viscosities separately, using only the Python standard library:

```bash
python data/modules/tBu/recalculate.py
```

These estimates use the corrected Si-free model and the 200–450 ps interval of each 500 ps production run. The reported ± values are the conditional standard errors of the extrapolated intercepts. At CO₂ loading 0.25, the result is 9.49 ± 0.58 cP.

## Scope of reproduction

The scripts reproduce numerical analyses from the supplied tables and derived curves. The tBuNHDiGly calculation starts from exported inverse-viscosity time series. The deposit does not include a complete set of production inputs, energy files and trajectories for rerunning all molecular dynamics simulations.

Data sources and the input files used for each analysis are listed in `data/provenance/analysis_versions.csv`. Use that register when consulting the supporting archives, which also retain earlier data versions.

## File checksums

The SHA-256 values identify the two release files:

```text
fd0e0d4a33738ef94d9a5505169a6ecd0affde8eea58f419151092c9ba5d7f5d  M16_source_data_20261024_v4.zip
be1e0f0fb7f8fdf443c7ba19de8ba984b419284ca8587ed1c1686cd3b9ed4b90  M16_evidence_20261024_v4.zip
```
