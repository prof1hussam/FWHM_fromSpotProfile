//--------------------------------------------------------------------------------------
// 1. PARAMETER DIALOGUE
//--------------------------------------------------------------------------------------
Dialog.create("FWHM Batch Analysis Settings");

Dialog.addMessage("--- 1. FILE LOCATIONS ---");
Dialog.addDirectory("Source Image Folder:", "");
Dialog.addDirectory("Destination for CSV Results:", "");
Dialog.addString("File Extension:", ".tiff"); 

Dialog.addMessage("--- 2. DETECTION SETTINGS ---");
Dialog.addNumber("Pixels per Micron:", 100); 
Dialog.addNumber("Profile Line Length (px):", 100); 
Dialog.addNumber("Estimated FWHM (microns):", 0.2); 
Dialog.addNumber("Max Points to Test:", 1000); 

Dialog.addMessage("--- 3. FILTRATION LOGIC (R-Squared) ---");
Dialog.addNumber("Min High R2 (Good axis):", 0.75); 
Dialog.addNumber("Max Low R2 (Bad axis):", 0.75); 

Dialog.addMessage("--- 4. TOGGLES & SPECIAL MODES ---");
Dialog.addCheckbox("Contains Cell Wall? (Strict Size Filter)", false); // NEW
Dialog.addCheckbox("Save results automatically?", true);
Dialog.addCheckbox("Show & Save Marked Images?", false); 
Dialog.addCheckbox("Exclude Adjacent Spots", true); 
Dialog.addCheckbox("Exclude Edge Spots", true); 

Dialog.show();

// Assigning Dialog values
inputDir = Dialog.getString();
saveDir = Dialog.getString();
ext = Dialog.getString();
UnitofScale = Dialog.getNumber();
lineSize = Dialog.getNumber();
estSize = Dialog.getNumber();
MaximumPoints = Dialog.getNumber();
gofHigh = Dialog.getNumber();
gofLow = Dialog.getNumber();

isCellWall = Dialog.getCheckbox(); // Boolean for strict size filter
doSave = Dialog.getCheckbox();
showOverlay = Dialog.getCheckbox();
excludeAdjacent = Dialog.getCheckbox();
excludeEdges = Dialog.getCheckbox();

//--------------------------------------------------------------------------------------
// 2. HOUSEKEEPING
//--------------------------------------------------------------------------------------
if (inputDir == "") exit("No input directory selected.");
if (doSave && !endsWith(saveDir, File.separator)) saveDir = saveDir + File.separator;

markedDir = saveDir + "Marked_Images" + File.separator;
if (showOverlay && doSave) File.makeDirectory(markedDir);

if (isOpen("FWHM_Full_Results")) { selectWindow("FWHM_Full_Results"); run("Close"); }
if (isOpen("FWHM_Summary")) { selectWindow("FWHM_Summary"); run("Close"); }

list = getFileList(inputDir);
countGlobal = 0; 
setBatchMode(true); 

// Determine Multipliers based on the Cell Wall toggle
if (isCellWall) {
    upperMult = 3.0;
    lowerMult = 0.2;
} else {
    upperMult = 5.0;
    lowerMult = 0.1;
}

//--------------------------------------------------------------------------------------
// 3. PROCESSING LOOP
//--------------------------------------------------------------------------------------
for (f = 0; f < list.length; f++) {
    if (endsWith(list[f], ext)) {
        open(inputDir + list[f]);
        name = getTitle();
        countLocal = 0; 
        
        getDimensions(w, h, channels, slices, frames); 
        run("Set Scale...", "distance="+UnitofScale+" known=1 unit=micron global");
        getPixelSize(unit, pixelWidth, pixelHeight);

        AveragePixel = getValue("Mean raw");
        StdDeviation = getValue("StdDev");
        CalculatedProminence = AveragePixel + (1 * StdDeviation); 

        halfLine = floor(lineSize / 2);
        margin = halfLine + 1;

        run("Find Maxima...", "prominence=" + CalculatedProminence + " strict exclude output=[Point Selection]");
        
        if (selectionType() != -1) {
            getSelectionCoordinates(x, y);
            intensities = newArray(x.length);
            for (i = 0; i < x.length; i++) { intensities[i] = getPixel(x[i], y[i]); }
            sortedIndices = Array.rankPositions(intensities);
            sortedIndices = Array.reverse(sortedIndices);
            numPoints = minOf(x.length, MaximumPoints);

            keepX = newArray(0); keepY = newArray(0);
            run("Select None");

            for (j = 0; j < numPoints; j++) {
                currentX = x[sortedIndices[j]];
                currentY = y[sortedIndices[j]];

                if (excludeEdges && (currentX <= margin || currentX >= (w - margin) || currentY <= margin || currentY >= (h - margin))) continue;

                tooClose = false;
                if (excludeAdjacent && keepX.length > 0) {
                    for (k = 0; k < keepX.length; k++) {
                        dist = sqrt(pow(currentX - keepX[k], 2) + pow(currentY - keepY[k], 2));
                        if (dist < lineSize) { tooClose = true; break; }
                    }
                }
                if (tooClose) continue; 

                // --- Measurement Profiles ---
                makeLine(currentX, currentY - halfLine, currentX, currentY + halfLine);
                Y_v = getProfile();
                X_v = newArray(Y_v.length);
                for (i = 0; i < Y_v.length; i++) { X_v[i] = i * pixelHeight; }
                Fit.doFit("Gaussian", X_v, Y_v);
                R_v = Fit.rSquared; FWHM_v = abs(2.35482 * Fit.p(3));

                makeLine(currentX - halfLine, currentY, currentX + halfLine, currentY);
                Y_h = getProfile();
                Fit.doFit("Gaussian", X_v, Y_h); 
                R_h = Fit.rSquared; FWHM_h = abs(2.35482 * Fit.p(3));

                isVGood = (R_v > gofHigh && R_h < gofLow);
                isHGood = (R_h > gofHigh && R_v < gofLow);

                if (isVGood || isHGood) {
                    if (isVGood) { 
                        valFWHM = FWHM_v; valR2 = R_v; orient = "Vertical"; bCol = "magenta";
                        lx1=currentX; ly1=currentY-halfLine; lx2=currentX; ly2=currentY+halfLine;
                    } else { 
                        valFWHM = FWHM_h; valR2 = R_h; orient = "Horizontal"; bCol = "green";
                        lx1=currentX-halfLine; ly1=currentY; lx2=currentX+halfLine; ly2=currentY;
                    }
                    
                    // --- THE UPDATED SIZE FILTER ---
                    if (valFWHM < upperMult * estSize && valFWHM > lowerMult * estSize) {
                        countGlobal++; countLocal++; 
                        keepX = Array.concat(keepX, currentX); keepY = Array.concat(keepY, currentY);
                        
                        addFullTable(countGlobal, countLocal, currentX, currentY, valFWHM, valR2, orient, unit, Fit.p(0), Fit.p(1), name, FWHM_v, R_v, FWHM_h, R_h);
                        addSummaryTable(countLocal, name, valFWHM, valR2, orient);
                        
                        if (showOverlay) {
                            makeLine(lx1, ly1, lx2, ly2);
                            run("Add Selection...", "stroke=" + bCol + " width=1");
                            makeText(""+countLocal, currentX+4, currentY-8);
                            run("Add Selection...", "stroke=" + bCol);
                        }
                    }
                }
            }
        }
        
        if (showOverlay && countLocal > 0) {
            setBatchMode("show");
            run("Flatten");
            saveAs("Tiff", markedDir + "Marked_" + name);
            close(); 
            setBatchMode("hide");
        }
        close(); 
    }
}

setBatchMode(false);

if (doSave && countGlobal > 0) {
    if (isOpen("FWHM_Full_Results")) {
        selectWindow("FWHM_Full_Results");
        saveAs("Results", saveDir + "Full_FWHM_Results.csv");
        run("Close");
    }
    if (isOpen("FWHM_Summary")) {
        selectWindow("FWHM_Summary");
        saveAs("Results", saveDir + "Summary_FWHM_Results.csv");
        run("Close");
    }
}

print("--- Batch Analysis Finished ---");
if (isCellWall) print("Mode: Strict Cell Wall (0.2x to 3x size filter)");
else print("Mode: General (0.1x to 5x size filter)");
exit; 

//--------------------------------------------------------------------------------------
// FUNCTIONS
//--------------------------------------------------------------------------------------

function addFullTable(gIdx, lIdx, xP, yP, fwhm, r2, orient, u, b, m, img, fv, rv, fh, rh){
    tFull = "FWHM_Full_Results"; t2 = "[" + tFull + "]";
    if (!isOpen(tFull)){
        run("Table...", "name=" + t2 + " width=1100 height=500");
        print(t2, "\\Headings:Global_Idx\tLocal_Idx\tx\ty\tFWHM_Validated\tRSquared\tOrientation\tUnit\tBase\tMax\tImage\tFWHM_Vert\tR2_Vert\tFWHM_Horiz\tR2_Horiz");
    }
    print(t2, gIdx + "\t" + lIdx + "\t" + xP + "\t" + yP + "\t" + fwhm + "\t" + r2 + "\t" + orient + "\t" + u + "\t" + b + "\t" + m + "\t" + img + "\t" + fv + "\t" + rv + "\t" + fh + "\t" + rh);
}

function addSummaryTable(lIdx, img, fwhm, r2, orient){
    tSum = "FWHM_Summary"; t2 = "[" + tSum + "]";
    if (!isOpen(tSum)){
        run("Table...", "name=" + t2 + " width=600 height=400");
        print(t2, "\\Headings:Local_Index\tImage\tFWHM_Validated\tRSquared_Val\tOrientation");
    }
    print(t2, lIdx + "\t" + img + "\t" + fwhm + "\t" + r2 + "\t" + orient);
}
exit;