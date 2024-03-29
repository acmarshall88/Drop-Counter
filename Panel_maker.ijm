//'tolerance' for finding maxima in background peak of raw sample image (see 'Array.findMaxima()'):
		//(increase this value if too many premature maxima are found in histogram) 
	tolerance = 10; //(% of max counts in histogram... )

waitForUser("Import Image Sequence \n (File->Import->Image Sequence...)");

run("Images to Stack", "name=Stack title=[] use keep");

Stack.setXUnit("microns");
Stack.setYUnit("microns");

getPixelSize(unit, pixelWidth, pixelHeight);
print("pixelWidth = "+pixelWidth+" "+unit);
print("pixelHeight = "+pixelHeight+" "+unit);

// Ensures scale bar is set to 'overlay':
run("Scale Bar...", "width=0 height=0 font=0 color=White background=None location=[Lower Right] hide overlay");

Dialog.create("Cropping and labelling...");
Dialog.addCheckbox("Would you like to crop images?", false);
Dialog.addNumber("Crop box width (square, centred)", 100, 1, 5, "microns");
Dialog.addCheckbox("OR, draw crop box manually?", false);
Dialog.addCheckbox("Include image labels?", false);
Dialog.addCheckbox("Normalise brightness?", true);
Dialog.addNumber("Scale panels", 1, 2, 5, "");
Dialog.addNumber("Border width", 8, 0, 5, "px");
Dialog.addCheckbox("Convert to 8-bit?", true);
Dialog.addCheckbox("Reverse order of images?", false);
Dialog.show();

crop_status = Dialog.getCheckbox();
crop_size = Dialog.getNumber()/pixelWidth;
crop_manual_status = Dialog.getCheckbox();
label_status = Dialog.getCheckbox();
normalisation_status = Dialog.getCheckbox();
scale = Dialog.getNumber();
border_width = Dialog.getNumber();
convert_to_8bit = Dialog.getCheckbox();
reverse_order = Dialog.getCheckbox();

if (reverse_order == true) {
	run("Reverse");
}

if (crop_status == true) {

	getDimensions(width, height, channels, slices, frames);
		image_width = width;
		image_height = height;
	
	if (crop_manual_status == true) {
		makeRectangle(400, 400, 826, 826);
		waitForUser("Draw box to crop image. Then hit 'OK'.");
		run("Crop");
	} else {
		makeRectangle(image_width/2 - crop_size/2, image_height/2 - crop_size/2, crop_size, crop_size);
		run("Crop");
	}

}


// Assigns 'sample' to open (selected) image:
sample = getTitle();

if (normalisation_status == true) {

for (i = 1; i <= nSlices; i++) {
    setSlice(i);
	
	////////////////////////////////////////////////////////////////////////////////////////////
	print("###########################################################################");
	print("### 1. Extract histogram/LUT of Slice#"+i+"... ###                        ");
	////////////////////////////////////////////////////////////////////////////////////////////
	
	// Defines number of bins for histogram:
	getRawStatistics(nPixels, mean, min, max, std, histogram);
	pixel_depth = max-min;
	print("pixel_depth (# of shades of grey in image) = "+ pixel_depth);
	nBins = pixel_depth/pow(2, -floor(-pixel_depth*0.0001)); //(nBins should be ~500-1000 and a factor of pixel_depth)
	print("nBins (# of bins for histogram) = "+ nBins);
	
	// Gets values from the LUT histogram. 
	// This returns two arrays "values" and "counts".
	// The histogram is split into into nBins number of bins. 
	
	getHistogram(values, counts, nBins);
	plot_values = values;
	plot_counts = counts;
	
//	Plot.create(sample+" histogram", "values", "counts", plot_values, plot_counts);
//	Plot.show();
//	rename(sample+" raw image histogram");
//	
//	print("see:  "+getTitle());
	
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
	
	for (j = 0; j < 15; j++) {
		if ((peak_x_location == maxLoc[j]) == true
				&&	(maxLoc[j+1]-maxLoc[j] <= nBins*0.05) 
				&& (counts[maxLoc[j+1]] >= counts[maxLoc[j]]*0.9) 
				== true) {
			peak_x_location = maxLoc[j+1];
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
//	Fit.plot();
//	
//	rename(sample+" raw image histogram background peak fit");
	
	// Extracts fitted parameters from the gaussian fit using "Fit.p()"...
	fit_max = Fit.p(0); //'a' in "Gaussian (no offset)"
	sample_background_mean = Fit.p(1); //'b' in "Gaussian (no offset)"
	fit_sd = abs(Fit.p(2)); //'c' in "Gaussian (no offset)"
	
	print("Background Peak Fit (Gaussian):");
	print("slice_background_max = "+fit_max);
	print("*slice_background_mean* (mean pixel value) = "+sample_background_mean);
	print("slice_background_SD = "+fit_sd);
	
	if (i == 1) {
		bg_mean_list = newArray(1);
		bg_mean_list = Array.fill(bg_mean_list, sample_background_mean);
	} else {
	    mean_to_append = newArray(1);
	    mean_to_append = Array.fill(mean_to_append,sample_background_mean);
	    bg_mean_list = Array.concat(bg_mean_list,mean_to_append);
	};
	    
};

print(" ");
print("Mean background intensity for each slice:"); 
Array.print(bg_mean_list);
print(" ");


////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 3. Find slice with max mean background intensity... ###                ");
////////////////////////////////////////////////////////////////////////////////////////////

Array.getStatistics(bg_mean_list, min, max, mean, stdDev);
maxSlice = Array.findMaxima(bg_mean_list, max/100, 0);

maxSlice_bg_mean = bg_mean_list[maxSlice[0]];
print("Slice with max bg intensity: "+(maxSlice[0]+1));
print("... bg mean intensity = "+bg_mean_list[maxSlice[0]]);
print(" ");

////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 4. Normalise histogram of each slice to slice with max intensity... ###");
print("###    (normalisation_factor = maxSlice_bg_mean/slice_bg_mean)  ###");
////////////////////////////////////////////////////////////////////////////////////////////

for (i = 1; i <= nSlices; i++) {
    setSlice(i);
    slice_bg_mean = bg_mean_list[i-1];
    print("slice#"+i+" BG mean = "+slice_bg_mean);
    normalisation_factor = maxSlice_bg_mean/slice_bg_mean; 
	print("normalisation_factor for this slice = "+normalisation_factor);
	run("Multiply...", "value="+normalisation_factor+" slice");
};
print(" ");

} else {
	print("No image brightness normalisation");
};

////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### 5. Make Montage... ###");
////////////////////////////////////////////////////////////////////////////////////////////

print("Number of panels = "+nSlices);

if (label_status == true) {
	run("Make Montage...", "columns="+nSlices+" rows=1 scale="+scale+" border="+border_width+" font=14 label");
} else {
	run("Make Montage...", "columns="+nSlices+" rows=1 scale="+scale+" border="+border_width+"");
}

run("Scale Bar...", "width=200 height=20 font=40 color=Red background=None location=[Lower Right] bold overlay");
run("Grays");

getStatistics(area, mean, min, max, std, histogram);
print("min intensity = "+min);
print("max intensity = "+max);
setMinAndMax(min, max);
print("min <-> max set to: "+min+" <-> "+max);

if (convert_to_8bit == true) {
	run("8-bit");
}

print(" ");
////////////////////////////////////////////////////////////////////////////////////////////
print("###########################################################################");
print("### NOTES... ###");
////////////////////////////////////////////////////////////////////////////////////////////

print(">> Change image colour using: Image -> Color -> Channels Tool (click 'More' -> 'greys')");
print(">> Change Scale bar using: Analyze -> Tools -> Scale Bar");
