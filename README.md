# FWHM_fromSpotProfile
ImageJ MACRO to calculate FWHM from confocal/STED images using spot detection and line Gaussain fitting

# Asymmetric FWHM Batch Analyzer
**An ImageJ/Fiji macro for automated Gaussian fit analysis of elongated biological structures.**

[Image of a Gaussian fit line profile over a fluorescent microscopy spot showing FWHM and R-squared values]

## Overview
This tool is designed to detect asymmetric fluorescent spots (such as filaments or cell wall segments), perform Gaussian fits on both the vertical and horizontal axes, and validate them based on user-defined "Goodness of Fit" ($R^2$) thresholds. It processes entire directories of `.tiff` files and exports both comprehensive raw data and clean summary tables.

## Features
* **Asymmetry Logic:** Validates spots that are "lines, not circles" by requiring a high $R^2$ in one axis and a low $R^2$ in the other.
* **Cell Wall Mode:** A toggleable "Strict Mode" that narrows the acceptable FWHM range ($0.5x$ to $2x$) for uniform structures like plant cell walls.
* **Adjacency Filtering:** Automatically skips spots that are too close to each other (closer than the measurement line length) to prevent signal "bleeding."
* **Edge Exclusion:** Prevents fitting errors by ignoring spots where the measurement line would fall outside the image boundary.
* **Dual Table Output:** * **Summary Table:** Focuses on validated results (Local Index, Image, FWHM).
    * **Full Table:** Contains developer-level raw fit data for both axes.
* **Visual Verification:** Option to save "Marked Images" where validated spots are labeled (Magenta = Vertical, Green = Horizontal).

## Installation
1.  Download the `.ijm` file from this repository.
2.  Open **Fiji/ImageJ**.
3.  Drag and drop the `.ijm` into the Fiji status bar and click **Run**, or go to `Plugins > Macros > Run...`.

## Parameters & Settings
When you run the script, a dialogue box will appear:

| Parameter | Description |
| :--- | :--- |
| **Pixels per Micron** | The scale of your image (e.g., 100 px = 1 µm). |
| **Profile Line Length** | The length of the line (in pixels) used for the Gaussian fit. |
| **Estimated FWHM** | The expected width of your structure (in microns). |
| **Min High R2** | Minimum $R^2$ for the validated (good) axis. |
| **Max Low R2** | Maximum $R^2$ for the "bad" axis (to ensure elongation). |
| **Contains Cell Wall?** | **Checked:** Strict filter ($0.2x$ - $3x$ Est. FWHM). <br> **Unchecked:** Broad filter ($0.1x$ - $5x$ Est. FWHM). |

## Output
The macro generates two `.csv` files in your specified destination folder:
* `Full_FWHM_Results.csv`
* `Summary_FWHM_Results.csv`

## License
Licensed under the **Apache License, Version 2.0**.

---
**Author:** Hussam Moammer  
**Year:** 2026
