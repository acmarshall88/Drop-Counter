////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////// DROP COUNTER //////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////

// This macro is for calculating the [relative] amount 
//	of condensed protein in liquid-liquid phase separated 
//	samples imaged using fluorescence microscopy.

// MACRO PROCESS OVERVIEW:
// 1. Extract histogram/LUT (x,y = values,counts) of sample image.
// 2. Find the mean background pixel value (x) by fitting gaussian to background peak in histogram.
// 3. Use gaussian blur of image of control sample (out-of-focus image of sample with no large droplets) as 'blank' to subtract from sample image.
// 4. Normalise blank by multipyling it by: 0.99*sample_background_mean/blank_mean. ('mean' is mean pixel value; 99% factor is to leave some background signal to fit gaussian)
// 5. Subtract normalised blank from sample image.
// 6. Extract histogram (x,y = values,counts) of background-subtracted image.
// 7. Fit gaussian to background peak of background-subtracted image to set a reproducible/consistent threshold for all sample images.
// 8. Use threshold to define droplet mask.
// 9. Relative condensed protein is calculated using two methods:
	//	Method#1) total integrated intensity inside droplets divided by total integrated intensity outside droplets (Idroplet/Imedia)
		//	*assumes no saturated pixels... also assumes background subtraction won't affect(?) 
	//	Method#2) identify all droplets and calculate volume of each from their individual areas, then sum all volumes to get total condensed volume. 
		//	*assumes droplets are spheres with a USER-DEFINED Contact Angle (USER INPUT)
		//  ... if contact angle is not known, the volume calculated is relative but still valid for Csat determination.

////////////////////////////////////////////////////////////////////////////////////////////
// BEFORE RUNNING MACRO YOU NEED TO MAKE 'BLANK' IMAGE FIRST AND SPECIFY LOCATION IN DIALOG POPUP (OR LINE 44)
// *take out-of-focus (~50um below plate surface) image of sample with highest [protein] before LLPS occurs (at least with no big drops).


////////////////////////////////////////////////////////////////////////////////////////////
// TO RUN MACRO, FIRST OPEN SAMPLE IMAGE, THEN HIT 'RUN' (ctrl+R)...
////////////////////////////////////////////////////////////////////////////////////////////
//selectImage(1);

// Default input parameters (these are updated via dialog box pop-up):

	//sample protein concentration:
	protein_uM = 1; 

	//droplet contact angle (in degrees... automatically converted to radians for volume calculations):	
	theta = 30;

	//filepath to blank image:
	blank_filepath = "\\\\uniwa.uwa.edu.au\\userhome\\staff7\\00101127\\My Documents\\LLPS results\\20210618_sfpqQG\\20x\\D19_blank_30above.nd2";
	
	//pathway to blank images (NB: these images must have file names: "##uM_Gblur30.tif", where ## is an integer):
//	blank_directory = "\\\\uniwa.uwa.edu.au\\userhome\\staff7\\00101127\\My Documents\\LLPS results\\20201112_gfp-sfpq(1-265)\\Day2_20hr (20201113)\\PlateI_centrifuged\\row I 10X OBJ\\BLANK(I1_Gblur)";

	//Blank Filename Prefix:
//	blank_file_prefix = "Gblur100_";
	
	//droplet threshold value (number of background peak standard deviations) ("user value", Wang et al 2018):
	user_value = 3;
		//(Increasing user_value will increase intensity threshold for defining pixels as condensed phase)
	
	//'tolerance' for finding maxima in background peak of raw sample image (see 'Array.findMaxima()', LINE 102):
		//(increase this value if too many premature maxima are found in histogram) 
	tolerance = 10; //(% of max counts in histogram... see line 141)	


//Creates dialog box for user input:
Dialog.create("Sample input");
Dialog.addNumber("(1) Protein Concentration:", protein_uM, 1, 5, "uM");
//Dialog.addMessage("^ Total protein concentration in sample. \n \n");

Dialog.addNumber("(2) Droplet Contact Angle:", theta, 1, 5, "deg");

Dialog.addNumber("(3) Droplet thresholding:  ", user_value);
//Dialog.addMessage("^ Number of positive standard deviations from mean of background peak of \n blank-subtracted image ('user value' - Wang et al, 'A Molecular Grammar...', Cell, 2018).\n Increasing this will increase intensity threshold for defining pixels as condensed phase. \n (use ~3 for widefield images; ~5-10 for confocal)");

Dialog.addCheckbox("(4) Subtract Blank?", true);
//Dialog.addMessage("^ Useful when background intensity is non-uniform. \n \n \n");

Dialog.addString("(5) Blank Filepath:     ", blank_filepath, 100);
//Dialog.addMessage("^ Complete path to blank image file. \n \n \n");

//Dialog.addString("(2) Blank File Directory:     ", blank_directory, 100);
//Dialog.addMessage("^ Pathway to folder containing blank image(s). \n \n \n");
//
//Dialog.addString("(3) Blank Filename Prefix:", blank_file_prefix);
//Dialog.addMessage("^ Filenames for blank images must have format: '[Blank Filename Prefix]#.tif', \n "+
//	"where '#' is the approx protein concentration in micromolar (must be an integer). \n \n \n");

Dialog.addNumber("(6) Peak find tolerance:     ", tolerance);
//Dialog.addMessage("^ Tolerance value for finding background peak in raw image (default=10). \n "+
//	"This is as a percentage of max counts value in histogram (*increase this value \n "+
//	"if too many premature maxima are found in histogram of raw image). \n \n \n");

Dialog.addCheckbox("(7) Show Gaussian Fits (Plots)?", false);

Dialog.addMessage("\n*Notes:");
Dialog.addMessage("*(1) Total protein concentration in sample.");
Dialog.addMessage("*(3) Number of positive standard deviations from mean of background peak of \n blank-subtracted image ('user value' - Wang et al, 'A Molecular Grammar...', Cell, 2018).\n Increasing this will increase intensity threshold for defining pixels as condensed phase. \n (use ~3 for widefield images; ~10-15 for confocal)");
Dialog.addMessage("*(4) Useful when background intensity is non-uniform.");
Dialog.addMessage("*(5) Complete path to blank image file.");
Dialog.addMessage("*(6) Tolerance value for finding background peak in raw image (default=10). \n "+
	"This is as a percentage of max counts value in histogram (*increase this value \n "+
	"if too many premature maxima are found in histogram of raw image). \n \n \n");

Dialog.show();

protein_uM = Dialog.getNumber();
theta = Dialog.getNumber();
user_value = Dialog.getNumber();
blank_subtraction_status = Dialog.getCheckbox();
blank_filepath = Dialog.getString();
//blank_directory = Dialog.getString()+"\\";
//blank_file_prefix = Dialog.getString();
tolerance = Dialog.getNumber();
show_plots_status = Dialog.getCheckbox();

// starts log:
print(" ");
print("###########################################################################");
print("################################# NEW SAMPLE ##############################");
print("###########################################################################");
print("*User Input Parameters*:");
print("Sample protein concentration = "+protein_uM+" uM");
print("Droplet contact angle = "+theta+" deg");
print("Droplet threshold parameter = "+user_value+"  (background peak standard deviations)");
if (blank_subtraction_status == true) {
	print("Blank Image for background-subtraction:  "+blank_filepath);
}
//print("Blank image file path:  "+blank_directory+blank_file_prefix+" ##");
print("Tolerance for raw image background peak find = "+tolerance+"%");
print(" ");

// Assigns 'sample' to open (selected) image:
sample = getTitle();
bgsubtracted_sample = "not defined (yet)";

////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 1. Extract histogram/LUT of raw sample image... ###                        ");
////////////////////////////////////////////////////////////////////////////////////////////

// Defines number of bins for histogram:
getRawStatistics(nPixels, mean, min, max, std, histogram);
pixel_depth = max-min;
print("pixel_depth (# of shades of grey in image) = "+ pixel_depth);
nBins = pixel_depth/pow(2, -floor(-pixel_depth*0.0001)); //(nBins should be ~500-5000 and a factor of pixel_depth)
print("nBins (# of bins for histogram) = "+ nBins);

// Gets values from the LUT histogram. 
// This returns two arrays "values" and "counts".
// The histogram is split into into nBins number of bins. 

getHistogram(values, counts, nBins);
plot_values = values;
plot_counts = counts;

if (show_plots_status == true) {
	Plot.create(sample+" histogram", "values", "counts", plot_values, plot_counts);
	Plot.show();
	rename(sample+" raw image histogram");
	print("see:  "+getTitle());
};

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 2. Find the mean background pixel value (x) by fitting gaussian to ###");
print("###     background peak (left-most peak) in histogram of raw image... ###");
////////////////////////////////////////////////////////////////////////////////////////////

// "Array.getStatistics()" gets statistics from the 
// arrays that were extracted using getHistogram.
// Only really useful for the counts array.

// First, this removes first and last values in array 
// to remove these potential 'maxima'...

values = Array.slice(values, 1, nBins-1);
counts = Array.slice(counts, 1, nBins-1);
 
Array.getStatistics(counts, min, max, mean, stdDev);
print("mean_counts = "+mean);
print("max_counts = "+max);
print("min_counts = "+min);

// Need to locate max value of background peak to define region to fit gaussian... 
// Finds maxima:
maxima_list = Array.findMaxima(counts, max*tolerance/100);
maxima_list_sorted = Array.sort(maxima_list);
dummy_array = newArray(nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, 
	nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, nBins-4, nBins-4);
 maxLoc = Array.concat(maxima_list,dummy_array);
		//(^adding dummy array is so that for loop (below) will work even if 
		// no premature maxima are defined)
		
print("maxima locations (bins): "); Array.print(maxLoc);

//Excludes "premature" maxima (outliers) and define peak location (bin#)...

if (maxLoc[0] == 0) {
	peak_x_location = maxLoc[1];
} else {
	peak_x_location = maxLoc[0];
}

for (i = 0; i < 15; i++) {
	if ((peak_x_location == maxLoc[i]) == true
			&&	(maxLoc[i+1]-maxLoc[i] <= nBins*0.05) 
			&& (counts[maxLoc[i+1]] >= counts[maxLoc[i]]*0.9) 
			== true) {
		peak_x_location = maxLoc[i+1];
};
};

 print("bkgnd maximum bin (peak_x_location): " + peak_x_location);
 peak_x = values[peak_x_location]; 
 print("bkgnd maximum, pixel value (peak_x) = " + peak_x);
 maxCount = counts[peak_x_location];
 print("bkgnd maximum, counts (maxCount) = " + maxCount);
peak_x_bin = plot_values[peak_x_location];

// Defines maximum cutoff for the fitting of the gaussian 
// to the left-most peak in the histogram:

// max_cutoff = peak_x_location * 1.1; 
	//(^includes left half of distribution only)
max_cutoff = peak_x_location * 1.5; 
	//(^excludes right shoulder of distribution) 

// makes trimmed dataset...
bg_x_values = Array.slice(values, 0, max_cutoff);
bg_y_values = Array.slice(counts, 0, max_cutoff);

// Fits a given function ("Gaussian (no offset)" in 
// this case) to the trimmed dataset using "Fit.doFit()".
// Fit.plot() then prints the fitted plot into
// a new window...

//using built-in function, "Gaussian (no offset)"... function is "y = a*exp(-(x-b)*(x-b)/(2*c*c)))"...
SD_initialguess = peak_x*0.03; 
print("SD_initialguess = "+ SD_initialguess);
initialGuesses = newArray(maxCount, peak_x, SD_initialguess);
Fit.doFit("Gaussian (no offset)", bg_x_values, bg_y_values, initialGuesses);

if (show_plots_status == true) {
	Fit.plot();
	rename(sample+" raw image histogram background peak fit");
};

// Extracts fitted parameters from the gaussian fit using "Fit.p()"...
fit_max = Fit.p(0); //'a' in "Gaussian (no offset)"
sample_background_mean = Fit.p(1); //'b' in "Gaussian (no offset)"
fit_sd = abs(Fit.p(2)); //'c' in "Gaussian (no offset)"

print("Raw Image Background Fit (Gaussian):");
print("sample_background_max = "+fit_max);
print("*sample_background_mean* (mean pixel value) = "+sample_background_mean);
print("sample_background_SD = "+fit_sd);
if (show_plots_status == true) {
	print("see:  "+getTitle());
};

print(" ");



if (blank_subtraction_status == true) {

////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 3. Use gaussian blur of control image (an out-of-focus image of sample with ###");
print("###     highest [protein] without formation of droplets (i.e. just below Csat)  ###");
print("###     as 'blank' to subtract from sample image...                             ###");
////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////
//print("###########################################################################");
//print("### 3. Use gaussian blur of image of control sample (same [protein], but no ###");
//print("###     LLPS - e.g. in high [salt]) as 'blank' to subtract from sample image... ###");
//////////////////////////////////////////////////////////////////////////////////////////////


//blank_uM_1 = round(protein_uM);
//blank_filepath_1 = blank_directory + blank_file_prefix + blank_uM_1 +".tif";
//
//for (i = 1; i < 100; i++) {
//	if (File.exists(blank_filepath_1) == 0) {
//		blank_uM_1 = round(protein_uM-i);
//		blank_filepath_1 = blank_directory + blank_file_prefix + blank_uM_1 +".tif";
//};
//};
//print("path to blank image 1 = "+blank_filepath_1);
//if (File.exists(blank_filepath_1) == 1) {
//	print(" ^This file exists.");
//} else {
//	print(" ^This file DOES NOT exist.");
//}
//
//
//blank_uM_2 = round(protein_uM);
//blank_filepath_2 = blank_directory + blank_file_prefix + blank_uM_2 +".tif";
//
//for (i = 1; i < 100; i++) {
//	if (File.exists(blank_filepath_2) == 0) {
//		blank_uM_2 = round(protein_uM+i);
//		blank_filepath_2 = blank_directory + blank_file_prefix + blank_uM_2 +".tif";
//};
//};
//print("path to blank image 2 = "+blank_filepath_2);
//if (File.exists(blank_filepath_2) == 1) {
//	print(" ^This file exists.");
//} else {
//	print(" ^This file DOES NOT exist.");
//}
//
//
//if (File.exists(blank_filepath_1) == 0) {
//	blank_filepath = blank_filepath_2;
//}
//
//if (File.exists(blank_filepath_2) == 0) {
//	blank_filepath = blank_filepath_1;
//}
//
//if (File.exists(blank_filepath_1) == 1 
// && File.exists(blank_filepath_2) == 1) {
//	if (((protein_uM - blank_uM_1) <= (blank_uM_2 - protein_uM)) == true) {
//		blank_filepath = blank_filepath_1;		 
//	} else {
//		blank_filepath = blank_filepath_2;
//	}
//}
//
//if (File.exists(blank_filepath_1) == 0
// && File.exists(blank_filepath_2) == 0) {
//	Dialog.create("Error - check blank images");
//	Dialog.addMessage("Can't find blank file. Please check filepath to blank images.");
//	Dialog.addMessage("(This error will also occur if concentration specified in blank filename\n"+
//		"differs from sample concentration by more than 100)");
//	Dialog.show();
//}
//
//print("path to 'best' blank = "+blank_filepath);


// Opens 'blank' image representative of background to subtract: 
open(blank_filepath);

// Does Gaussian blur to remove all features/noise:
run("Gaussian Blur...", "sigma=80");

blank = getTitle();
print("blank image:  "+blank);

getRawStatistics(nPixels, mean, min, max, std, histogram);
blank_mean = mean;
print("*blank_mean* (mean pixel value) = "+blank_mean);

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 4. Normalise blank to sample_background_mean...  ###");
////////////////////////////////////////////////////////////////////////////////////////////

normalisation_factor = 0.99*(sample_background_mean/blank_mean); 
	//(^99% factor is so that there remains a background normal distribution to fit)
print("normalisation_factor = " + normalisation_factor);
print("  ^(this is (sample_background_mean)/(blank_mean) x 0.99)");

run("Multiply...", "value="+ normalisation_factor);
rename(blank+" - (normalised to "+sample+" background)");
blank_normalised = getTitle();

print("see:  "+getTitle());

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 5. Subtract normalised blank from sample image...  ###");
////////////////////////////////////////////////////////////////////////////////////////////

imageCalculator("Subtract create",sample,blank_normalised);

// removes noise:
run("Median...", "radius=2");

// Assigns 'bgsubtracted_sample_ID' to new image:
bgsubtracted_sample_ID = getImageID();

rename(""+sample+" after blank subtraction");
bgsubtracted_sample = getTitle();

print(" (also, noise removed by applying Median filter)");
print("outputs new image called:  '"+bgsubtracted_sample+"'");

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 6. Extract histogram (x,y = values,counts) of background-subtracted image...###");
////////////////////////////////////////////////////////////////////////////////////////////

// Defines number of bins for histogram:
getRawStatistics(nPixels, mean, min, max, std, histogram);
pixel_depth = max-min;
print("pixel_depth (# of shades of grey in image) = "+ pixel_depth);
nBins = pixel_depth/pow(2, -floor(-pixel_depth*0.0001)); 
	//(^nBins should be ~500-5000 and a factor of pixel depth)
print("nBins (# of bins for histogram) = "+ nBins);

// Gets values from the LUT histogram. 
// This returns two arrays "values" and "counts".
// The histogram is split into into nBins number of bins. 

getHistogram(values, counts, nBins);

///////EXCLUDE FIRST THREE POINTS:
values = Array.slice(values, 3, nBins);
counts = Array.slice(counts, 3, nBins);

//Plot.create(bgsubtracted_sample+" histogram", "values", "counts", plot_values, plot_counts);

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 7. Fit Gaussian to background peak of background-subtracted image to  ###");
print("###     set a reproducible/consistent threshold for all sample images...  ###");
////////////////////////////////////////////////////////////////////////////////////////////

// Makes trimmed dataset using fitted SD from original gaussian
// (pre-subtracted image - line 166) to estimate appropriate max cutoff 
// for fitting Gaussian to BG peak in histogram of BG-subtracted image
bg_x_values = Array.slice(values, 0, fit_sd*1.5); // <- 'values' array from line //386
bg_y_values = Array.slice(counts, 0, fit_sd*1.5); // <- 'counts' array from line //387

//For setting y-offset: 
//Gets min counts value in left-most third of blank-subtracted image...
	counts_first_third = Array.slice(counts, 0, nBins*0.33);
	Array.getStatistics(counts_first_third, min, max, mean, stdDev);
	min_counts = min;
	print("max BG counts = "+max);
	print("min BG counts = "+min+" (used as y-offset for gaussian fit)");


// Fits a given function ("customGaussian" in this case) to the 
// trimmed dataset using "Fit.doFit()".
// Fit.plot() then prints the fitted plot into a new window (optional)...

	//Using previously fitted max and SD parameters from above (re-fit mean only):
		initialGuesses = newArray(1);
			//(^sets initial guess for mean 'a' as 0)
		customGaussian = "y = "+ min_counts +" + ("+ fit_max +"-"+ min_counts +")*exp(-(x-a)*(x-a)/(2*"+ fit_sd +"*"+ fit_sd +"))";
			//(^set y offset to min counts in histogram)

		//customGaussian = "y = "+ fit_max +"*exp(-(x-a)*(x-a)/(2*"+ fit_sd +"*"+ fit_sd +"))";
			//(^no y offset; i.e. y min = 0)

		//initialGuesses = newArray(2);
			//(^sets initial guesses for offset 'a' and mean 'b' as 0 and 0)
		//customGaussian = "y = a + ("+ fit_max +"-a)*exp(-(x-b)*(x-b)/(2*"+ fit_sd +"*"+ fit_sd +"))"; 
			//(^WITH OFFSET FITTING; i.e. y min = 'a')
		
		Fit.doFit(customGaussian, bg_x_values, bg_y_values, initialGuesses);
		
	// Extract fitted parameters...
	refit_mean = Fit.p(0);		//('a' above)
	//fit_offset = Fit.p(0);	//('a' above)
	//refit_mean = Fit.p(1);	//('b' above)

// re-make trimmed dataset...
	bg_x_values = Array.slice(values, 0, refit_mean+fit_sd*1.5);
	bg_y_values = Array.slice(counts, 0, refit_mean+fit_sd*1.5); 

	//Do second round of fitting to tweak max and SD (mean is fixed):
		initialGuesses = newArray(fit_max, fit_sd);
		customGaussian3 = "y = "+ min_counts +" + (a-"+ min_counts +")*exp(-(x-("+ refit_mean +"))*(x-("+ refit_mean +"))/(2*b*b))";
			//(^set y offset to min counts in histogram)
		
		//initialGuesses = newArray(fit_offset, fit_max, fit_sd);
		//customGaussian3 = "y = a + (b-a)*exp(-(x-("+ refit_mean +"))*(x-("+ refit_mean +"))/(2*c*c))";
			//(^WITH OFFSET FITTING; i.e. y min = 'a')
		
		Fit.doFit(customGaussian3, bg_x_values, bg_y_values, initialGuesses);

	// Extract fitted parameters...
	//refit_offset = Fit.p(0); 	//('a' above)
	refit_max = Fit.p(0); 		//('a' above)
	refit_sd = Fit.p(1); 		//('b' above)

//OPTIONAL:
//Fit.plot();

//print("Y-OFFSET_fit = " + refit_offset);
print("MAX_fit = " + refit_max);
print("MEAN_fit = " + refit_mean);
print("SD_fit = " + refit_sd);

print(" ");

// Sets the new threshold for the image ("user value" (arbitrary) is defined in line 17)
// using mean and SD parameters of Gaussian fit above...
new_thresh = refit_mean + abs(refit_sd)*user_value; 
print("threshold = " + new_thresh);





} else {
	print("############### (no blank subtraction) ##################");
	print(" ");

	new_thresh = sample_background_mean + abs(fit_sd)*user_value;
	print("threshold = " + new_thresh);
}



if (show_plots_status == true) {
	
	// Creates data from the fitted gaussian for creation of plot...
	fitted_counts = Array.copy(counts);
	
	for (i = 0; i < values.length; i++) {
		fitted_counts[i] = Fit.f(values[i]);
	}
	
	// Creation of the plot for visual represenation of the data...
	 Plot.create("Total Image Histogram", "Pixel Values", "Counts");
	 Plot.setColor("red");
	 Plot.setLineWidth(5);
	 Plot.add("dot", values, counts);
	 Plot.setLineWidth(2);
	 Plot.setColor("cyan");
	 Plot.add("line", values, fitted_counts);
	 Plot.setColor("red");
	Array.getStatistics(bg_y_values, min, max, mean, stdDev); 
	maxCount = max;
	 Plot.drawLine(new_thresh, maxCount*0.8, new_thresh, 0);
	 Plot.addText("Threshold Value", 0.13, 0.2);
	 Plot.setColor("black");
	 Plot.show;
	
	rename("Thresholded histogram");
	
	print("see:  "+getTitle());
};

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 8. Use threshold to define droplet mask...  ###");
////////////////////////////////////////////////////////////////////////////////////////////

if (isOpen(bgsubtracted_sample) == 1) {
	selectImage(bgsubtracted_sample);
} else {
	selectImage(sample);
}

sample_final = getImageID();

getStatistics(area, mean, min, max, std, histogram);
setThreshold(new_thresh, max);

// Creates selection from the threshold for the droplets...
run("Create Selection");

print("see:  "+getTitle());

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 9. Calculate amount of condensed protein (2 Methods)...  ###");
////////////////////////////////////////////////////////////////////////////////////////////

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 9a. Method #1 - compare integrated intensities (relative)...  ###");
////////////////////////////////////////////////////////////////////////////////////////////

// Gets statistics for the condensed phase (inside droplets)...
getStatistics(area, mean, min, max, std);
	Idroplet=mean*area; // integrated intensity inside droplets
	drop_area=area;

// Changes selection to the background (everything else)...
run("Make Inverse");

// Get statistics for the dilute phase (outside droplets)...
getStatistics(area, mean, min, max, std);
	Imedia=mean*area; // integrated intensity outside droplets
	back_area=area;

// proportion of condensed protein BY AREA =
proportion_cond_area=drop_area/(back_area+drop_area);

// To append new results to existing table (and ignore this if 1st sample)... 
if (isOpen("Method#1 (compare integrated intensities)") == 1) {
	selectWindow("Method#1 (compare integrated intensities)"); IJ.renameResults("Results")
};

row=nResults;
setResult("Prot_Conc_uM", row, protein_uM);
setResult("SDs_for_threshold", row, user_value);
setResult("condensed_area", row, drop_area);
setResult("dilute_area", row, back_area);
setResult("proportion_condensed_area", row, proportion_cond_area);
setResult("Idroplet", row, Idroplet);
setResult("Imedia", row, Imedia);
setResult("Idroplet/Imedia", row, Idroplet/Imedia);
 
 IJ.renameResults("Method#1 (compare integrated intensities)");

print("see:  '"+getTitle()+"' results table");

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 9b. Method #2 - calculate total condensed volume (estimate of absolute)... ###");
////////////////////////////////////////////////////////////////////////////////////////////

// Clears selection... (image remains thresholded)...
run("Select None");

// To append new results (from "Analyze Particles") to existing table (and ignore this if 1st sample)... 
if (isOpen("Method#2 (calculate total condensed volume)") == 1) {
	selectWindow("Method#2 (calculate total condensed volume)"); IJ.renameResults("Summary")
};

// "run("Analyze Particles...")" counts droplets and calculates average area...
run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 display summarize");
//run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Outlines display summarize"); //(use this to show droplet outlines)
// ^^GIVES Area in um^2

//Calculate volume of each droplet using Area (A) and Contact Angle (theta)
//and add to Results table...

//theta must be in RADIANS:
th_rad = theta*(PI/180);

for (i = 0; i < nResults(); i++) {
    A = getResult("Area", i);
    setResult("Volume_um3", i, (PI/3) * pow((sqrt(A/PI)/sin(th_rad)), 3) * (2+cos(th_rad)) * pow((1-cos(th_rad)), 2) );
}
updateResults();

selectWindow("Results");
Vol_array = Table.getColumn("Volume_um3");

Vol_total_um3=0;

for (i=0;i<lengthOf(Vol_array);i++){
 Vol_total_um3=Vol_total_um3+Vol_array[i];
};

print("Condensed vol in image (um^3) = "+Vol_total_um3);

//Append to "Summary" table window...
IJ.renameResults("Particle list for "+protein_uM+"uM sample (Method#2)");
selectWindow("Summary"); IJ.renameResults("Results"); 


/////////////////////////////////////////////////
//run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 display summarize");
//
////(use the following to display list of particles in results window...)
//	//run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Outlines display summarize");
//	// IJ.renameResults("Particle list for "+protein_uM+"uM sample (Method#2)");
//
//// Calculates theoretical condensed volume at well bottom
//// using average droplet area ("Average Size") to calculate
//// average droplet volume (*ASSUMING A HEMISPHERE*), and then
//// multiplying by number of droplets ("Count")...
//
//selectWindow("Summary"); IJ.renameResults("Results"); 
//
//// Adds [protein] to Results Table...
//setResult("protein_uM", nResults-1, protein_uM);
//setResult("uservalue_threshSD", row, user_value);
//
//// Gets "Count" and "Average Size" values from last row of Results table...
//Count = getResult("Count", nResults-1);
//Average_Size = getResult("Average Size", nResults-1);
//
//// Uses rearranged formula for volume-of-a-sphere to calculate 
//// vol (in cubic microns) from area ("Average Size")... 
//Av_calculated_sphere_Vol = (4/(3*sqrt(PI)))*pow(Average_Size, 3/2);
//// Halves for hemisphere assumption...
//Av_calculated_hemisphere_Vol = 0.5*Av_calculated_sphere_Vol;
//// Multiplies by number of droplets...
//Total_calculated_Vol_um3 = Av_calculated_hemisphere_Vol*Count;
//// Converts to nanoliters...
//Total_calculated_Vol_nL = Total_calculated_Vol_um3/pow(10,6);
//	//(^ 1 nanoliter = 1,000,000 cubic microns)

/////////////////////////////////////////////////


Total_calculated_Vol_nL=Vol_total_um3/pow(10,6);
	//(^ 1 nanoliter = 1,000,000 cubic microns)
print("Condensed vol in image (nL) = "+Total_calculated_Vol_nL);

// Interior dimensions of well bottom are ~ 3.3 x 3.3 mm.
print("Well bottom dimensions ~ 3.3 x 3.3 mm");
well_area_um2 = pow(3300,2);
print("Well bottom area = "+well_area_um2+" microns^2");

// Calculates area covered by image...
selectImage(sample_final);
getDimensions(width, height, channels, slices, frames);
getPixelSize(unit, pixelWidth, pixelHeight);
image_width = width*pixelWidth;
image_height = height*pixelHeight;
print("Image dimensions = "+image_width+" x "+image_height+" "+unit);
image_area_um2 = image_width*image_height;
print("Image area = "+image_area_um2+" "+unit+"^2");

// Calculates factor to multiply calculated Volume by
// to extrapolate to total condensed volume in sample...
extrapolation_factor = well_area_um2/image_area_um2;
print("extrapolation_factor = "+extrapolation_factor+
	" <--(condensed vol captured by image is multiplied by this to get total condensed volume in sample)");

Total_calculated_Vol_in_sample_nL = Total_calculated_Vol_nL*extrapolation_factor;
print("Condensed vol in sample (nL) = "+Total_calculated_Vol_in_sample_nL);

// Appends output to Results Table...
//setResult("Condensed Volume (um^3)", nResults-1, Total_calculated_Vol_um3);
setResult("Protein_Conc_uM", nResults-1, protein_uM);
setResult("SDs_for_threshold", nResults-1, user_value);
setResult("Contact_angle", nResults-1, theta);
setResult("Condensed_Vol_um3", nResults-1, Vol_total_um3);
setResult("Cond_Vol_in_image_nL", nResults-1, Total_calculated_Vol_nL);
setResult("Cond_Vol_in_sample_nL", nResults-1, Total_calculated_Vol_in_sample_nL);

// Renames Results table...
IJ.renameResults("Method#2 (calculate total condensed volume)");

print("see:  '"+getInfo("window.title")+"' results table");
//print("see:  '"+getTitle()+"' results table");


print(" "); 
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### Remarks ###");
////////////////////////////////////////////////////////////////////////////////////////////

if (blank_subtraction_status == true) {

	// Final caution message if normalisation factor deviates too much from 1...
	if ((normalisation_factor > 3) == true || 
		(normalisation_factor < 0.3) == true) {
		Dialog.create("Caution (not fatal)");
		Dialog.addMessage("Blank normalisation factor deviates significantly from 1.0\n"+
		"(normalisation_factor = "+normalisation_factor+").\n"+
		"Check blank-subtracted image.\n"+
		"Consider adding blank images with average intensity more similar to sample background intensity\n"+
		"and/or check that microscope settings are similar for sample and blank images.");
		Dialog.show();
		print("Caution: normalisation factor deviates significantly from 1.0");
	}
}

print(" "); 