# P2 viscosity source data and numerical reproduction

This repository accompanies the manuscript **Comparative Insights into Viscosity in Single-Component Water-Lean CO2 Absorbents**. Its authoritative numerical inputs are supplied as versioned release assets. The current numerical checks have been tested in an independent directory with Python 3.12.14 using only the released inputs and the dependencies below.

## Download the release assets

Open [M16-20261024-v4](https://github.com/Nemo-ZJU-1998/P2-Viscosity-M16-Data/releases/tag/M16-20261024-v4). Download both files without renaming them:

| Asset | SHA256 |
|---|---|
| `M16_source_data_20261024_v4.zip` | `fd0e0d4a33738ef94d9a5505169a6ecd0affde8eea58f419151092c9ba5d7f5d` |
| `M16_evidence_20261024_v4.zip` | `be1e0f0fb7f8fdf443c7ba19de8ba984b419284ca8587ed1c1686cd3b9ed4b90` |

If this release or its assets are not visible, publication is not yet complete. A draft release is not available to ordinary anonymous readers. Do not substitute a private repository or an earlier archive.

The source asset is about 22.7 MB compressed and 69.9 MB extracted. The companion evidence asset is about 394.9 MB and contains historical upstream ZIPs; unpack only the upstream archive required for a particular check. It does not have to be unpacked to run the primary numerical checks.

Verify both downloaded ZIP hashes against the table above. For example, run `Get-FileHash .\M16_source_data_20261024_v4.zip -Algorithm SHA256` in Windows PowerShell (repeat for the evidence ZIP), or use `sha256sum` on Linux / `shasum -a 256` on macOS. Then use a new working directory:

```text
reader-test/
  M16_source_data_20261024_v4.zip
  M16_evidence_20261024_v4.zip
  source/
    README.txt
    requirements.txt
    verify_checksums.py
    reproduce_current.py
    data/
    modules/
    provenance/
    parameters/
    results/
  evidence/                 # optional extraction of the companion asset
    README.txt
    archive_manifest.json
    upstream/
```

The ZIPs contain their payload directly: create the `source` and `evidence` directories when extracting; do not add another nested directory with the asset's basename.

## Install and run

The commands below use Python 3.12 and a fresh virtual environment. On Linux/macOS use `python3` if that is the Python 3.12 command. Do not use Python's `-O` option, because the verification scripts use assertions.

```bash
python -m venv .venv
# Linux/macOS:
source .venv/bin/activate
# Windows PowerShell, instead:
# .\.venv\Scripts\Activate.ps1

python -m zipfile -e M16_source_data_20261024_v4.zip source
python -m pip install -r source/requirements.txt
python source/verify_checksums.py
python source/reproduce_current.py
```

If PowerShell activation is restricted, invoke `.\.venv\Scripts\python.exe` directly in place of `python`; no execution-policy change is required. The tested dependency pins are NumPy 2.5.4, SciPy 1.18.1 and pandas 3.0.1; optional figure rendering also uses Matplotlib 3.11.2 and Pillow 13.0.0, all listed in `source/requirements.txt`.

Run the checksum verification **before** numerical reproduction. The entry point regenerates some module result files and writes `source/results/current_verification.json`, so a checksum check after execution can legitimately identify generated outputs that differ from their bundled snapshots. Work on an extracted copy and retain the downloaded ZIPs unchanged.

The entry point uses paths relative to its own location and may be called from another working directory. It must not require the author's `C:`, `D:`, `E:` or HPC data directories. Historical provenance files and optional upstream scripts may record those locations; they are not dependencies of the primary numerical entry point.

## What the primary entry point checks

| Analysis | Current input cohort and scope |
|---|---|
| Figure 2(c) | 49 equally weighted pairs from seven systems; experimental interpolation, endpoint assignments and logarithmic MAE |
| Loading fits / Table S2 / Figure S20 | 132 retained loading points from 15 systems; 12 systems have nine loadings and three have eight |
| Figure 3(h) | 16-system molecular-mass/cluster model, using the corrected tBu model |
| Figure 6 | 64 reported FFV regression/control fits and the supplied 1001-frame tBu FFV summary |
| Figure 4(d,e) | Three representative displacement/correlation-function summaries |
| Figure 5 / M11 | Three representative signed-energy and conditional-control summaries |
| Figure S25 | Statistics from the current 15-system source table |
| Corrected tBu loading series / Figure S34 | Nine loading values, separate from the archived 132-point loading-fit cohort |
| QM corrections | Six new counterpoise fragment-energy arithmetic checks |

Read `source/provenance/analysis_versions.csv` before using files in `source/modules/`. Canonical current data and that registry take precedence over historical snapshots in retained upstream archives. Different analyses have different cohorts by design.

Selected expected outputs include:

- Experimental comparison: 49 pairs, log10 MAE **0.13699363640178025**.
- Figure 3(h): 16 systems, training R² **0.8630288377837207**, leave-one-system-out log10 RMSE **0.2373921456330226**.
- Corrected tBu at loading 0.25: **9.490217154539728 ± 0.5811625881224336 cP**.

The comparison reproduces the archived experimental source coordinates and interpolation. It is not an independent re-digitization or a fresh verification of the primary literature measurements and their sample conditions.

## Recalculate the corrected tBu viscosities

This calculation uses only Python's standard library:

```bash
python source/modules/tBu/recalculate.py
```

For each selected acceleration, it reads the archived GROMACS inverse-viscosity time series, takes the arithmetic mean over **200–450 ps inclusive**, and calculates

```text
apparent viscosity [cP] = 1000 / mean(inverse viscosity [(Pa s)^-1]).
```

It then fits apparent viscosity against acceleration by unweighted OLS. The reported value is the intercept and the reported `±` is its **conditional intercept standard error**, given the archived selected acceleration subset and time window. Each 500 ps production run contributes 2501 samples in that interval at 0.1 ps spacing. The selected accelerations are supplied explicitly in `source/modules/tBu/tBu_corrected_viscosity_313K.csv`; loading 0.35 uses 0.0225, 0.025, 0.0275, 0.030 and 0.035 nm ps^-2. Additional archived acceleration points are diagnostics and must not silently replace the adopted subset.

These SEs do not cover acceleration-selection uncertainty, time-window choice, force-field error, unresolved low-shear bias or independent-run variability. A high fitted R² is not evidence, by itself, of a resolved zero-shear plateau.

The corrected model is the silicon-free **36_deSi** model. Combine its viscosities only with the matching corrected-model structural sources in M03 and M05. Legacy Si-containing tBu FFV, cluster and energy data are excluded.

## Optional figure rendering and evidence

To regenerate the current S25 figure:

```bash
python source/scripts/replot_S25.py lj
```

Outputs are written to `source/figures/FigureS25_current.png` and `.pdf`. Reproducing numbers does not require recreating every publication layout. Exact appearance may depend on font availability.

For an upstream audit, extract the companion asset separately:

```bash
python -m zipfile -e M16_evidence_20261024_v4.zip evidence
```

Its `upstream/` ZIPs retain original module evidence. They can include older calculations, archived absolute paths, TPRs and sampled trajectories. Consult their own README and the current analysis registry; do not mix their historical snapshots into current inputs. Optional trajectory analysis has additional requirements such as MDAnalysis, networkx or GROMACS, and is distinct from the tested numerical entry point.

## Reproduction boundaries

1. **Numerical reproduction from supplied tables and derived curves:** supported by the primary entry point and tested in an independent environment.
2. **Viscosity recomputation from exported inverse-viscosity series:** supported for the corrected nine-loading tBu series. This does not re-export those series from the original EDR files; the complete production EDR collection is not included.
3. **Complete MD rerun from initial structures:** not a self-contained, tested capability of this release. Some upstream archives contain a corrected 0.25-loading NVT TPR, one NEMD TPR and a sampled structural trajectory. They do not provide the complete nine-loading set of initial/restart states, production inputs, scheduler/tool dependencies and EDR files needed to reconstruct every reported run. No new full MD or QM runs are performed by the numerical entry point.

The earlier `NemoZJU/ViscosityCalculation` repository is a private historical code reference, not a required public dependency and not an authoritative one-command reproduction of this release. Its generic two-input preparation, fixed acceleration defaults and author-specific postprocessing paths must not be assumed to define the corrected 36_deSi production workflow. The public source package includes parameter/provenance records, which identify the model and settings but do not establish physical force-field validation.

The current evidence does not establish independent-run convergence or a resolved zero-shear limit. Regression and response-error propagation intervals retain the conditional definitions documented with each dataset. Numerical agreement with archived results must not be described as experimental validation or proof of a universal viscosity mechanism.

## Frozen provenance

The SHA256 values above identify the immutable v4 ZIPs. Some packaged README/provenance text preserves access checks made before this public repository was created; those records are historical and do not replace the public release status shown here. Updates to repository documentation must not silently change a released ZIP under the same checksum or version. If numerical payloads need changing, publish a new version with new checksums.
