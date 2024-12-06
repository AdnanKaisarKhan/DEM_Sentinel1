#
# S1_DEM_PROCESSING
#!/bin/sh
#!/bin/bash
############################################################################################################
# Sequential InSAR Processing Chain of Sentinel-1 InSAR pair for DEM generation.
# 
# Adnan Kaisar Khan, Saurabh Vijay 
# IIT Roorkee 
# 
# IMPORTANT INSTRUCTIONS
# - Download Sentinel-1 SLC data from ASF: https://www.asf.alaska.edu/ or https://dataspace.copernicus.eu/ [ wget --user=abc --password='abc@123' /file address/ ]
# - Perpendicular baseline of the scenes should be between 150-400m, this can be checked using ASF baseline tool.
# - Temporal baseline should be as low as possible.
# - The precise orbits can be downloaded from: https://S1qc.asf.alaska.edu or https://dataspace.copernicus.eu/ using eof command and wget /file address/
# - The SRTM ellipsoid DEM 30m can be downloaded from: https://portal.opentopography.org

# - Make a folder called S1_DEM_*StudySite (For ex: S1_DEM_Karakoram, S1_DEM_WIS), make a folder called 
#   dem and a folder called output. Also make a folder called inputdata and put sentinel-1 slc .zip files,
#   precise orbit files (POEORB), and reference DEM (ref_DEM) into it.  

# - directory (directory), sentinel-1 reference and secondary slc input files (referenceSLC, secondarySLC),
#   reference dem file and precise orbit files should be updated for each processing.

# - Also update the EPSG code for your AOI before starting processing your data.

# - Run this script using ./dem_using_sentinel1_mod.sh in terminal.
 
############################################################################################################

for ((j=10; j<=11; j++)); do

date

# ------------------------------------------------------
# Parameters to set (Working Directory and Input Files)
# ------------------------------------------------------

utm_zone=32642														# check the EPSG code for your AOI


directory="/labuser/adnan/S1_DEM_42_$j/inputdata"									# Specify the directory you want to list

file_array=($(find "$directory" -type f -name "S1A_IW_SLC*"))

if [ "${#file_array[@]}" -ge 2 ]; then
  
  referenceSLC=$(basename "${file_array[0]}")
  secondarySLC=$(basename "${file_array[1]}")

else
  echo "Insufficient matching files found starting with 'S1A_IW_SLC' in $directory"
fi

# --------------------
# Initial processing
# --------------------

referenceSLC=`echo $referenceSLC | cut -c 1-67`
orbit_ref=`echo $referenceSLC | cut -c 50-55`
file_ref=`echo $referenceSLC | cut -c 34-41`
echo "reference SLC file name is:" $referenceSLC
echo "orbit reference is" $orbit_ref
echo "reference date is" $file_ref

secondarySLC=`echo $secondarySLC | cut -c 1-67`
orbit_sec=`echo $secondarySLC | cut -c 50-55`
file_sec=`echo $secondarySLC | cut -c 34-41`
echo "secondary SLC file name is:" $secondarySLC
echo "orbit secondary is" $orbit_sec
echo "secondary file date is" $file_sec

# -----------------------------------
# Rest of the GAMMA code starts here
# -----------------------------------

cd /labuser/adnan/S1_DEM_42_$j

#unzip inputdata/$referenceSLC.zip

cd $referenceSLC.SAFE

par_S1_SLC measurement/s1a-iw1-slc-vv-*.tiff annotation/s1a-iw1-slc-vv-*.xml annotation/calibration/calibration-s1a-iw1-slc-vv-*.xml annotation/calibration/noise-s1a-iw1-slc-vv-*.xml ../$file_ref._iw1_vv.slc.par - ../$file_ref._iw1_vv.slc.tops_par

cd ..

ScanSAR_burst_corners $file_ref._iw1_vv.slc.par $file_ref._iw1_vv.slc.tops_par $file_ref._iw1_vv.kml

S1_BURST_tab_from_zipfile - inputdata/$referenceSLC.zip

cp $referenceSLC.burst_number_table $file_ref.burst_number_table

ls inputdata/*$file_ref*.zip > $file_ref.zipfile_list
ls inputdata/*$file_sec*.zip > $file_sec.zipfile_list

awk 'NR<5 || NR>10' $file_ref.burst_number_table > temp_file && mv temp_file $file_ref.burst_number_table

echo "Burst table modified for iw1"

file1="$file_ref.burst_number_table"

iw1_number_of_bursts_from_file=$(grep -oP 'iw1_number_of_bursts: \K\d+' "$file1")
iw1_first_burst_from_file=$(grep -oP 'iw1_first_burst: \s*\K[0-9]+(\.[0-9]+)?' "$file1")
iw1_last_burst_from_file=$(grep -oP 'iw1_last_burst: \s*\K[0-9]+(\.[0-9]+)?' "$file1")

echo "iw1 number of bursts from file 1: $iw1_number_of_bursts_from_file"
echo "iw1 first burst from file 1: $iw1_first_burst_from_file"
echo "iw1 last burst from file 1: $iw1_last_burst_from_file"


for ((i=1; i<=$iw1_number_of_bursts_from_file; i++)); do

echo "loop iteration: $i"

iw1_number_of_bursts=$(echo "$iw1_number_of_bursts_from_file - $iw1_number_of_bursts_from_file + 1" | bc)
iw1_first_burst=$(echo "$iw1_first_burst_from_file + ($i - 1)" | bc)
sub_value=$(echo "$iw1_number_of_bursts_from_file - $i" | bc)
iw1_last_burst=$(echo "$iw1_last_burst_from_file - $sub_value" | bc)

echo "iw1 number of bursts: $iw1_number_of_bursts"
echo "iw1 first burst: $iw1_first_burst"
echo "Subtraction Value: $sub_value"
echo "iw1 last burst: $iw1_last_burst"

sed -i "s/iw1_number_of_bursts: [0-9.]\+/iw1_number_of_bursts: $iw1_number_of_bursts/" "$file1"

line_number_1=3
line_number_2=4

sed -i "${line_number_1}s/.*/iw1_first_burst:       $iw1_first_burst/" "$file1"
sed -i "${line_number_2}s/.*/iw1_last_burst:       $iw1_last_burst/" "$file1"


S1_import_SLC_from_zipfiles $file_ref.zipfile_list $file_ref.burst_number_table vv 0 0 ./inputdata/ 1 1
S1_import_SLC_from_zipfiles $file_sec.zipfile_list $file_ref.burst_number_table vv 0 0 ./inputdata/ 1 1

multi_look_ScanSAR $file_ref.vv.SLC_tab $file_ref.vv.mli $file_ref.vv.mli.par 10 2 1 | tee outputref1.txt

range_samples_ref=$(sed -n 's/.*MLI mosaic image range samples: \([0-9]\+\).*/\1/p' outputref1.txt)
azimuth_lines_ref=$(sed -n 's/.*MLI mosaic image azimuth lines: \([0-9]\+\).*/\1/p' outputref1.txt)

echo "Range Samples Reference: $range_samples_ref"
echo "Azimuth Lines Reference: $azimuth_lines_ref"

multi_look_ScanSAR $file_sec.vv.SLC_tab $file_sec.vv.mli $file_sec.vv.mli.par 10 2 1 | tee outputsec1.txt

range_samples_sec=$(grep -oP 'MLI mosaic image range samples: \K\d+' outputsec1.txt)
azimuth_lines_sec=$(grep -oP 'MLI mosaic image azimuth lines: \K\d+' outputsec1.txt)

echo "Range Samples Secondary: $range_samples_sec"
echo "Azimuth Lines Secondary: $azimuth_lines_sec"

raspwr $file_ref.vv.mli $range_samples_ref 1 0 1 1 1. .35 gray.cm output/$file_ref.1vv.$i.mli.bmp

raspwr $file_sec.vv.mli $range_samples_sec 1 0 1 1 1. .35 gray.cm output/$file_sec.1vv.$i.mli.bmp


SLC_corners $file_ref.vv.mli.par | tee coordinates1.txt

cd dem

/bin/cp ../$file_ref.vv.mli .
/bin/cp ../$file_ref.vv.mli.par .

gdalbuildvrt -resolution highest -r cubic DEM_1.vrt $(find ../inputdata -iname 'ref_DEM.tif')

dem_import DEM_1.vrt DEM_1.dem DEM_1.dem_par 0 1

create_dem_par UTM_DEM_1.dem_par - - -20.0 20.0 $utm_zone 0 | tee UTM_DEM_info1.txt

if [ "$i" -eq 1 ]; then

dem_trans DEM_1.dem_par DEM_1.dem UTM_DEM_1.dem_par UTM_DEM_1.dem - - 1 1 - 2

fi

gc_map2 $file_ref.vv.mli.par UTM_DEM_1.dem_par UTM_DEM_1.dem $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt 1 1 $file_ref._UTM.ls_map - $file_ref._UTM.inc | tee gcmap2output1.txt

dem_range_width=$(grep -oP 'DEM segment: width = \K\d+' gcmap2output1.txt)
dem_azimuth_lines=$(grep -oP 'nlines = \K\d+' gcmap2output1.txt)

echo "DEM Range Width: $dem_range_width"
echo "DEM Azimuth Lines: $dem_azimuth_lines"

pixel_area $file_ref.vv.mli.par $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt $file_ref._UTM.ls_map $file_ref._UTM.inc $file_ref.sigma0 $file_ref.gamma0 20 0.01

geocode $file_ref._UTM.lt $file_ref._UTM_seg.dem $dem_range_width $file_ref._UTM.hgt $range_samples_ref $azimuth_lines_ref

create_diff_par $file_ref.vv.mli.par - $file_ref.diff_par 1 0

offset_pwrm $file_ref.gamma0 $file_ref.vv.mli $file_ref.diff_par UTM.offs UTM.snr 512 512 UTM.offsets 1 6 6 0.1

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.1 1

offset_pwrm $file_ref.gamma0 $file_ref.vv.mli $file_ref.diff_par UTM.offs UTM.snr 256 256 UTM.offsets 1 64 64 0.1

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.15 3

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.15 1

gc_map_fine $file_ref._UTM.lt $dem_range_width $file_ref.diff_par $file_ref._UTM.lt_fine 1

pixel_area $file_ref.vv.mli.par $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt_fine $file_ref._UTM.ls_map $file_ref._UTM.inc $file_ref.sigma0 $file_ref.gamma0 20 0.01

geocode $file_ref._UTM.lt_fine $file_ref._UTM_seg.dem $dem_range_width $file_ref._UTM.hgt $range_samples_ref $azimuth_lines_ref

cd ..

cp $file_ref.vv.slc.iw1 $file_ref.vv.iw1.rslc
cp $file_ref.vv.slc.iw1.par $file_ref.vv.iw1.rslc.par
cp $file_ref.vv.slc.iw1.tops_par $file_ref.vv.iw1.rslc.tops_par
echo "Done"

echo "$file_ref.vv.iw1.rslc $file_ref.vv.iw1.rslc.par $file_ref.vv.iw1.rslc.tops_par" > $file_ref.RSLC_tab

echo "Done"

echo "$file_sec.vv.slc.iw1 $file_sec.vv.slc.iw1.par $file_sec.vv.slc.iw1.tops_par" > $file_sec.SLC_tab

echo "Done"

echo "$file_sec.vv.iw1.rslc $file_sec.vv.iw1.rslc.par $file_sec.vv.iw1.rslc.tops_par" > $file_sec.RSLC_tab

echo "Done"

ScanSAR_coreg.py $file_ref.RSLC_tab $file_ref $file_sec.SLC_tab $file_sec $file_sec.RSLC_tab dem/$file_ref._UTM.hgt 10 2

file_ref_sec="${file_ref}_$file_sec"

echo "Filename Combined: $file_ref_sec"

phase_sim_orb $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off dem/$file_ref._UTM.hgt $file_ref_sec.sim_unw $file_ref.rslc.par - - 1 1

SLC_diff_intf $file_ref.rslc $file_sec.rslc $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off $file_ref_sec.sim_unw $file_ref_sec.diff 10 2 1 0 0.2

rasmph_pwr $file_ref_sec.diff $file_ref.rmli $range_samples_ref 1 0 1 1 rmg.cm output/$file_ref_sec.$i.1diff.bmp

geocode_back $file_ref.rmli $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.rmli $dem_range_width $dem_azimuth_lines 5 0 - - 3

geocode_back $file_ref_sec.diff $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref_sec.diff $dem_range_width $dem_azimuth_lines 4 1 - - 3

rasmph_pwr UTM.$file_ref_sec.diff UTM.$file_ref.rmli $dem_range_width 1 0 1 1 rmg.cm output/tmp1.$i.bmp

data2geotiff dem/$file_ref._UTM_seg.dem_par output/tmp1.$i.bmp 0 output/UTM.$file_ref_sec.$i.1diff.tif

multi_look $file_sec.rslc $file_sec.rslc.par $file_sec.rmli $file_sec.rmli.par 10 2

cc_wave $file_ref_sec.diff $file_ref.rmli $file_sec.rmli $file_ref_sec.diff.cc $range_samples_ref 5 5 0

adf2 $file_ref_sec.diff $file_ref_sec.diff.cc filt.$file_ref_sec.diff filt.$file_ref_sec.diff.cc $range_samples_ref

rascc_mask filt.$file_ref_sec.diff.cc $file_ref.rmli $range_samples_ref - - - - - 0.35 0.0 0.0 1.0 - - - output/filt.$file_ref_sec.$i.1diff.cc.bmp

geocode_back filt.$file_ref_sec.diff.cc $range_samples_ref dem/$file_ref._UTM.lt_fine output/UTM.$file_ref_sec.$i.1diff.cc $dem_range_width $dem_azimuth_lines 4 0 - - 3

data2geotiff dem/$file_ref._UTM_seg.dem_par output/UTM.$file_ref_sec.$i.1diff.cc 2 output/UTM.$file_ref_sec.$i.1diff.cc.tif

rasdt_pwr filt.$file_ref_sec.diff $file_ref.rmli $range_samples_ref - - - - - - 0 rmg.cm output/filt.$file_ref_sec.$i.1diff.bmp

mcf filt.$file_ref_sec.diff - output/filt.$file_ref_sec.$i.1diff.cc.bmp $file_ref_sec.1diff.unw $range_samples_ref 2 - - - - - - - - - 1

rasdt_pwr $file_ref_sec.1diff.unw $file_ref.rmli $range_samples_ref - - - - 0 5 1 rmg.cm output/$file_ref_sec.$i.1diff.unw.bmp

dh_map_orb $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off dem/$file_ref._UTM.hgt $file_ref_sec.1diff.unw $file_ref_sec.dpdh $file_ref_sec.dh $file_ref.rslc.par 1

rasdt_pwr $file_ref_sec.dh $file_ref.rmli $range_samples_ref - - - - 0 300 1 rmg.cm output/$file_ref_sec.$i.1dh.bmp

float_math dem/$file_ref._UTM.hgt $file_ref_sec.dh $file_ref.hgt1 $range_samples_ref 0

rasdt_pwr $file_ref.hgt1 $file_ref.rmli $range_samples_ref - - - - 0 200 1 rmg.cm output/$file_ref.$i.1hgt1.bmp

geocode_back $file_ref.rmli $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.rmli $dem_range_width $dem_azimuth_lines 5 0 - - 3

geocode_back $file_ref.hgt1 $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.hgt1 $dem_range_width $dem_azimuth_lines 4 0 - - 3

interp_ad UTM.$file_ref.hgt1 UTM.$file_ref.hgt2 $dem_range_width 10 15 25 2 2 1

data2geotiff dem/$file_ref._UTM_seg.dem_par UTM.$file_ref.hgt2 2 output/UTM1.hgt1.${file_ref_sec}_$i.tif

done

####################################################################################################
date

cd $referenceSLC.SAFE

par_S1_SLC measurement/s1a-iw2-slc-vv-*.tiff  annotation/s1a-iw2-slc-vv-*.xml annotation/calibration/calibration-s1a-iw2-slc-vv-*.xml annotation/calibration/noise-s1a-iw2-slc-vv-*.xml ../$file_ref._iw2_vv.slc.par - ../$file_ref._iw2_vv.slc.tops_par

cd ..

ScanSAR_burst_corners $file_ref._iw2_vv.slc.par $file_ref._iw2_vv.slc.tops_par $file_ref._iw2_vv.kml

S1_BURST_tab_from_zipfile - inputdata/$referenceSLC.zip

cp $referenceSLC.burst_number_table $file_ref.burst_number_table

ls inputdata/*$file_ref*.zip > $file_ref.zipfile_list
ls inputdata/*$file_sec*.zip > $file_sec.zipfile_list

awk 'NR<2 || (NR>4 && NR<8) || NR>10' $file_ref.burst_number_table > temp_file && mv temp_file $file_ref.burst_number_table

echo "Burst table modified for iw2"


file2="$file_ref.burst_number_table"

iw2_number_of_bursts_from_file=$(grep -oP 'iw2_number_of_bursts: \K\d+' "$file2")
iw2_first_burst_from_file=$(grep -oP 'iw2_first_burst: \s*\K[0-9]+(\.[0-9]+)?' "$file2")
iw2_last_burst_from_file=$(grep -oP 'iw2_last_burst: \s*\K[0-9]+(\.[0-9]+)?' "$file2")

echo "iw2 number of bursts from file 2: $iw2_number_of_bursts_from_file"
echo "iw2 first burst from file 2: $iw2_first_burst_from_file"
echo "iw2 last burst from file 2: $iw2_last_burst_from_file"


for ((i=1; i<=$iw2_number_of_bursts_from_file; i++)); do

echo "loop iteration: $i"

iw2_number_of_bursts=$(echo "$iw2_number_of_bursts_from_file - $iw2_number_of_bursts_from_file +1" | bc)
iw2_first_burst=$(echo "$iw2_first_burst_from_file + ($i - 1)" | bc)
sub_value=$(echo "$iw2_number_of_bursts_from_file - $i" | bc)
iw2_last_burst=$(echo "$iw2_last_burst_from_file - $sub_value" | bc)

echo "iw2 number of bursts: $iw2_number_of_bursts"
echo "iw2 first burst: $iw2_first_burst"
echo "Subtraction Value: $sub_value"
echo "iw2 last burst: $iw2_last_burst"

sed -i "s/iw2_number_of_bursts: [0-9.]\+/iw2_number_of_bursts: $iw2_number_of_bursts/" "$file2"

line_number_1=3
line_number_2=4

sed -i "${line_number_1}s/.*/iw2_first_burst:       $iw2_first_burst/" "$file2"
sed -i "${line_number_2}s/.*/iw2_last_burst:       $iw2_last_burst/" "$file2"


S1_import_SLC_from_zipfiles $file_ref.zipfile_list $file_ref.burst_number_table vv 0 0 ./inputdata/ 1 1
S1_import_SLC_from_zipfiles $file_sec.zipfile_list $file_ref.burst_number_table vv 0 0 ./inputdata/ 1 1

multi_look_ScanSAR $file_ref.vv.SLC_tab $file_ref.vv.mli $file_ref.vv.mli.par 10 2 1 | tee outputref2.txt

range_samples_ref=$(sed -n 's/.*MLI mosaic image range samples: \([0-9]\+\).*/\1/p' outputref2.txt)
azimuth_lines_ref=$(sed -n 's/.*MLI mosaic image azimuth lines: \([0-9]\+\).*/\1/p' outputref2.txt)

echo "Range Samples Reference: $range_samples_ref"
echo "Azimuth Lines Reference: $azimuth_lines_ref"

multi_look_ScanSAR $file_sec.vv.SLC_tab $file_sec.vv.mli $file_sec.vv.mli.par 10 2 1 | tee outputsec2.txt

range_samples_sec=$(grep -oP 'MLI mosaic image range samples: \K\d+' outputsec2.txt)
azimuth_lines_sec=$(grep -oP 'MLI mosaic image azimuth lines: \K\d+' outputsec2.txt)

echo "Range Samples Secondary: $range_samples_sec"
echo "Azimuth Lines Secondary: $azimuth_lines_sec"

raspwr $file_ref.vv.mli $range_samples_ref 1 0 1 1 1. .35 gray.cm output/$file_ref.$i.2vv.mli.bmp

raspwr $file_sec.vv.mli $range_samples_sec 1 0 1 1 1. .35 gray.cm output/$file_sec.$i.2vv.mli.bmp


SLC_corners $file_ref.vv.mli.par | tee coordinates2.txt

cd dem

/bin/cp ../$file_ref.vv.mli .
/bin/cp ../$file_ref.vv.mli.par .

gdalbuildvrt -resolution highest -r cubic DEM_1.vrt $(find ../inputdata -iname 'ref_DEM.tif')

dem_import DEM_1.vrt DEM_1.dem DEM_1.dem_par 0 1

create_dem_par UTM_DEM_1.dem_par - - -20.0 20.0 $utm_zone 0 | tee UTM_DEM_info2.txt

if [ "$i" -eq 1 ]; then

dem_trans DEM_1.dem_par DEM_1.dem UTM_DEM_1.dem_par UTM_DEM_1.dem - - 1 1 - 2

fi

gc_map2 $file_ref.vv.mli.par UTM_DEM_1.dem_par UTM_DEM_1.dem $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt 1 1 $file_ref._UTM.ls_map - $file_ref._UTM.inc | tee gcmap2output2.txt

dem_range_width=$(grep -oP 'DEM segment: width = \K\d+' gcmap2output2.txt)
dem_azimuth_lines=$(grep -oP 'nlines = \K\d+' gcmap2output2.txt)

echo "DEM Range Width: $dem_range_width"
echo "DEM Azimuth Lines: $dem_azimuth_lines"

pixel_area $file_ref.vv.mli.par $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt $file_ref._UTM.ls_map $file_ref._UTM.inc $file_ref.sigma0 $file_ref.gamma0 20 0.01

geocode $file_ref._UTM.lt $file_ref._UTM_seg.dem $dem_range_width $file_ref._UTM.hgt $range_samples_ref $azimuth_lines_ref

create_diff_par $file_ref.vv.mli.par - $file_ref.diff_par 1 0

offset_pwrm $file_ref.gamma0 $file_ref.vv.mli $file_ref.diff_par UTM.offs UTM.snr 512 512 UTM.offsets 1 6 6 0.1

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.1 1

offset_pwrm $file_ref.gamma0 $file_ref.vv.mli $file_ref.diff_par UTM.offs UTM.snr 256 256 UTM.offsets 1 64 64 0.1

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.15 3

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.15 1

gc_map_fine $file_ref._UTM.lt $dem_range_width $file_ref.diff_par $file_ref._UTM.lt_fine 1

pixel_area $file_ref.vv.mli.par $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt_fine $file_ref._UTM.ls_map $file_ref._UTM.inc $file_ref.sigma0 $file_ref.gamma0 20 0.01

geocode $file_ref._UTM.lt_fine $file_ref._UTM_seg.dem $dem_range_width $file_ref._UTM.hgt $range_samples_ref $azimuth_lines_ref

cd ..

cp $file_ref.vv.slc.iw2 $file_ref.vv.iw2.rslc
cp $file_ref.vv.slc.iw2.par $file_ref.vv.iw2.rslc.par
cp $file_ref.vv.slc.iw2.tops_par $file_ref.vv.iw2.rslc.tops_par
echo "Done"

echo "$file_ref.vv.iw2.rslc $file_ref.vv.iw2.rslc.par $file_ref.vv.iw2.rslc.tops_par" > $file_ref.RSLC_tab

echo "Done"

echo "$file_sec.vv.slc.iw2 $file_sec.vv.slc.iw2.par $file_sec.vv.slc.iw2.tops_par" > $file_sec.SLC_tab

echo "Done"

echo "$file_sec.vv.iw2.rslc $file_sec.vv.iw2.rslc.par $file_sec.vv.iw2.rslc.tops_par" > $file_sec.RSLC_tab

echo "Done"

ScanSAR_coreg.py $file_ref.RSLC_tab $file_ref $file_sec.SLC_tab $file_sec $file_sec.RSLC_tab dem/$file_ref._UTM.hgt 10 2

file_ref_sec="${file_ref}_$file_sec"

echo "Filename Combined: $file_ref_sec"

phase_sim_orb $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off dem/$file_ref._UTM.hgt $file_ref_sec.sim_unw $file_ref.rslc.par - - 1 1

SLC_diff_intf $file_ref.rslc $file_sec.rslc $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off $file_ref_sec.sim_unw $file_ref_sec.diff 10 2 1 0 0.2

rasmph_pwr $file_ref_sec.diff $file_ref.rmli $range_samples_ref 1 0 1 1 rmg.cm output/$file_ref_sec.$i.2diff.bmp

geocode_back $file_ref.rmli $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.rmli $dem_range_width $dem_azimuth_lines 5 0 - - 3

geocode_back $file_ref_sec.diff $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref_sec.diff $dem_range_width $dem_azimuth_lines 4 1 - - 3

rasmph_pwr UTM.$file_ref_sec.diff UTM.$file_ref.rmli $dem_range_width 1 0 1 1 rmg.cm output/tmp2.$i.bmp

data2geotiff dem/$file_ref._UTM_seg.dem_par output/tmp2.$i.bmp 0 output/UTM.$file_ref_sec.$i.2diff.tif

multi_look $file_sec.rslc $file_sec.rslc.par $file_sec.rmli $file_sec.rmli.par 10 2

cc_wave $file_ref_sec.diff $file_ref.rmli $file_sec.rmli $file_ref_sec.diff.cc $range_samples_ref 5 5 0

adf2 $file_ref_sec.diff $file_ref_sec.diff.cc filt.$file_ref_sec.diff filt.$file_ref_sec.diff.cc $range_samples_ref

rascc_mask filt.$file_ref_sec.diff.cc $file_ref.rmli $range_samples_ref - - - - - 0.35 0.0 0.0 1.0 - - - output/filt.$file_ref_sec.$i.2diff.cc.bmp

geocode_back filt.$file_ref_sec.diff.cc $range_samples_ref dem/$file_ref._UTM.lt_fine output/UTM.$file_ref_sec.$i.2diff.cc $dem_range_width $dem_azimuth_lines 4 0 - - 3

data2geotiff dem/$file_ref._UTM_seg.dem_par output/UTM.$file_ref_sec.$i.2diff.cc 2 output/UTM.$file_ref_sec.$i.2diff.cc.tif

rasdt_pwr filt.$file_ref_sec.diff $file_ref.rmli $range_samples_ref - - - - - - 0 rmg.cm output/filt.$file_ref_sec.$i.2diff.bmp

mcf filt.$file_ref_sec.diff - output/filt.$file_ref_sec.$i.2diff.cc.bmp $file_ref_sec.2diff.unw $range_samples_ref 1 - - - - - - - - - 1

rasdt_pwr $file_ref_sec.2diff.unw $file_ref.rmli $range_samples_ref - - - - 0 5 1 rmg.cm output/$file_ref_sec.$i.2diff.unw.bmp

dh_map_orb $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off dem/$file_ref._UTM.hgt $file_ref_sec.2diff.unw $file_ref_sec.dpdh $file_ref_sec.dh $file_ref.rslc.par 1

rasdt_pwr $file_ref_sec.dh $file_ref.rmli $range_samples_ref - - - - 0 300 1 rmg.cm output/$file_ref_sec.$i.2dh.bmp

float_math dem/$file_ref._UTM.hgt $file_ref_sec.dh $file_ref.hgt1 $range_samples_ref 0

rasdt_pwr $file_ref.hgt1 $file_ref.rmli $range_samples_ref - - - - 0 200 1 rmg.cm output/$file_ref.$i.2hgt1.bmp

geocode_back $file_ref.rmli $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.rmli $dem_range_width $dem_azimuth_lines 5 0 - - 3

geocode_back $file_ref.hgt1 $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.hgt1 $dem_range_width $dem_azimuth_lines 4 0 - - 3

interp_ad UTM.$file_ref.hgt1 UTM.$file_ref.hgt2 $dem_range_width 10 15 25 2 2 1

data2geotiff dem/$file_ref._UTM_seg.dem_par UTM.$file_ref.hgt2 2 output/UTM2.hgt1.${file_ref_sec}_$i.tif

done

####################################################################################################
date


cd $referenceSLC.SAFE

par_S1_SLC measurement/s1a-iw3-slc-vv-*.tiff  annotation/s1a-iw3-slc-vv-*.xml annotation/calibration/calibration-s1a-iw3-slc-vv-*.xml annotation/calibration/noise-s1a-iw3-slc-vv-*.xml ../$file_ref._iw3_vv.slc.par - ../$file_ref._iw3_vv.slc.tops_par

cd ..

ScanSAR_burst_corners $file_ref._iw3_vv.slc.par $file_ref._iw3_vv.slc.tops_par $file_ref._iw3_vv.kml

S1_BURST_tab_from_zipfile - inputdata/$referenceSLC.zip

cp $referenceSLC.burst_number_table $file_ref.burst_number_table

ls inputdata/*$file_ref*.zip > $file_ref.zipfile_list
ls inputdata/*$file_sec*.zip > $file_sec.zipfile_list

awk 'NR<2 || NR>7' $file_ref.burst_number_table > temp_file && mv temp_file $file_ref.burst_number_table

echo "Burst table modified for iw3"


file3="$file_ref.burst_number_table"

iw3_number_of_bursts_from_file=$(grep -oP 'iw3_number_of_bursts: \K\d+' "$file3")
iw3_first_burst_from_file=$(grep -oP 'iw3_first_burst: \s*\K[0-9]+(\.[0-9]+)?' "$file3")
iw3_last_burst_from_file=$(grep -oP 'iw3_last_burst: \s*\K[0-9]+(\.[0-9]+)?' "$file3")

echo "iw3 number of bursts from file 3: $iw3_number_of_bursts_from_file"
echo "iw3 first burst from file 3: $iw3_first_burst_from_file"
echo "iw3 last burst from file 3: $iw3_last_burst_from_file"


for ((i=1; i<=$iw3_number_of_bursts_from_file; i++)); do

echo "loop iteration: $i"

iw3_number_of_bursts=$(echo "$iw3_number_of_bursts_from_file - $iw3_number_of_bursts_from_file + 1" | bc)
iw3_first_burst=$(echo "$iw3_first_burst_from_file + ($i - 1)" | bc)
sub_value=$(echo "$iw3_number_of_bursts_from_file - $i" | bc)
iw3_last_burst=$(echo "$iw3_last_burst_from_file - $sub_value" | bc)

echo "iw3 number of bursts: $iw3_number_of_bursts"
echo "iw3 first burst: $iw3_first_burst"
echo "Subtraction Value: $sub_value"
echo "iw3 last burst: $iw3_last_burst"

sed -i "s/iw3_number_of_bursts: [0-9.]\+/iw3_number_of_bursts: $iw3_number_of_bursts/" "$file3"

line_number_1=3
line_number_2=4

sed -i "${line_number_1}s/.*/iw3_first_burst:       $iw3_first_burst/" "$file3"
sed -i "${line_number_2}s/.*/iw3_last_burst:       $iw3_last_burst/" "$file3"


S1_import_SLC_from_zipfiles $file_ref.zipfile_list $file_ref.burst_number_table vv 0 0 ./inputdata/ 1 1
S1_import_SLC_from_zipfiles $file_sec.zipfile_list $file_ref.burst_number_table vv 0 0 ./inputdata/ 1 1

multi_look_ScanSAR $file_ref.vv.SLC_tab $file_ref.vv.mli $file_ref.vv.mli.par 10 2 1 | tee outputref3.txt

range_samples_ref=$(sed -n 's/.*MLI mosaic image range samples: \([0-9]\+\).*/\1/p' outputref3.txt)
azimuth_lines_ref=$(sed -n 's/.*MLI mosaic image azimuth lines: \([0-9]\+\).*/\1/p' outputref3.txt)

echo "Range Samples Reference: $range_samples_ref"
echo "Azimuth Lines Reference: $azimuth_lines_ref"

multi_look_ScanSAR $file_sec.vv.SLC_tab $file_sec.vv.mli $file_sec.vv.mli.par 10 2 1 | tee outputsec3.txt

range_samples_sec=$(grep -oP 'MLI mosaic image range samples: \K\d+' outputsec3.txt)
azimuth_lines_sec=$(grep -oP 'MLI mosaic image azimuth lines: \K\d+' outputsec3.txt)

echo "Range Samples Secondary: $range_samples_sec"
echo "Azimuth Lines Secondary: $azimuth_lines_sec"

raspwr $file_ref.vv.mli $range_samples_ref 1 0 1 1 1. .35 gray.cm output/$file_ref.$i.3vv.mli.bmp

raspwr $file_sec.vv.mli $range_samples_sec 1 0 1 1 1. .35 gray.cm output/$file_sec.$i.3vv.mli.bmp


SLC_corners $file_ref.vv.mli.par | tee coordinates3.txt

cd dem

/bin/cp ../$file_ref.vv.mli .
/bin/cp ../$file_ref.vv.mli.par .

gdalbuildvrt -resolution highest -r cubic DEM_1.vrt $(find ../inputdata -iname 'ref_DEM.tif')

dem_import DEM_1.vrt DEM_1.dem DEM_1.dem_par 0 1

create_dem_par UTM_DEM_1.dem_par - - -20.0 20.0 $utm_zone 0 | tee UTM_DEM_info3.txt

if [ "$i" -eq 1 ]; then

dem_trans DEM_1.dem_par DEM_1.dem UTM_DEM_1.dem_par UTM_DEM_1.dem - - 1 1 - 2

fi

gc_map2 $file_ref.vv.mli.par UTM_DEM_1.dem_par UTM_DEM_1.dem $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt 1 1 $file_ref._UTM.ls_map - $file_ref._UTM.inc | tee gcmap2output3.txt

dem_range_width=$(grep -oP 'DEM segment: width = \K\d+' gcmap2output3.txt)
dem_azimuth_lines=$(grep -oP 'nlines = \K\d+' gcmap2output3.txt)

echo "DEM Range Width: $dem_range_width"
echo "DEM Azimuth Lines: $dem_azimuth_lines"

pixel_area $file_ref.vv.mli.par $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt $file_ref._UTM.ls_map $file_ref._UTM.inc $file_ref.sigma0 $file_ref.gamma0 20 0.01

geocode $file_ref._UTM.lt $file_ref._UTM_seg.dem $dem_range_width $file_ref._UTM.hgt $range_samples_ref $azimuth_lines_ref

create_diff_par $file_ref.vv.mli.par - $file_ref.diff_par 1 0

offset_pwrm $file_ref.gamma0 $file_ref.vv.mli $file_ref.diff_par UTM.offs UTM.snr 512 512 UTM.offsets 1 6 6 0.1

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.1 1

offset_pwrm $file_ref.gamma0 $file_ref.vv.mli $file_ref.diff_par UTM.offs UTM.snr 256 256 UTM.offsets 1 64 64 0.1

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.15 3

offset_fitm UTM.offs UTM.snr $file_ref.diff_par UTM.coffs UTM.coffsets 0.15 1

gc_map_fine $file_ref._UTM.lt $dem_range_width $file_ref.diff_par $file_ref._UTM.lt_fine 1

pixel_area $file_ref.vv.mli.par $file_ref._UTM_seg.dem_par $file_ref._UTM_seg.dem $file_ref._UTM.lt_fine $file_ref._UTM.ls_map $file_ref._UTM.inc $file_ref.sigma0 $file_ref.gamma0 20 0.01

geocode $file_ref._UTM.lt_fine $file_ref._UTM_seg.dem $dem_range_width $file_ref._UTM.hgt $range_samples_ref $azimuth_lines_ref

cd ..

cp $file_ref.vv.slc.iw3 $file_ref.vv.iw3.rslc
cp $file_ref.vv.slc.iw3.par $file_ref.vv.iw3.rslc.par
cp $file_ref.vv.slc.iw3.tops_par $file_ref.vv.iw3.rslc.tops_par
echo "Done"

echo "$file_ref.vv.iw3.rslc $file_ref.vv.iw3.rslc.par $file_ref.vv.iw3.rslc.tops_par" > $file_ref.RSLC_tab

echo "Done"

echo "$file_sec.vv.slc.iw3 $file_sec.vv.slc.iw3.par $file_sec.vv.slc.iw3.tops_par" > $file_sec.SLC_tab

echo "Done"

echo "$file_sec.vv.iw3.rslc $file_sec.vv.iw3.rslc.par $file_sec.vv.iw3.rslc.tops_par" > $file_sec.RSLC_tab

echo "Done"

ScanSAR_coreg.py $file_ref.RSLC_tab $file_ref $file_sec.SLC_tab $file_sec $file_sec.RSLC_tab dem/$file_ref._UTM.hgt 10 2

file_ref_sec="${file_ref}_$file_sec"

echo "Filename Combined: $file_ref_sec"

phase_sim_orb $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off dem/$file_ref._UTM.hgt $file_ref_sec.sim_unw $file_ref.rslc.par - - 1 1

SLC_diff_intf $file_ref.rslc $file_sec.rslc $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off $file_ref_sec.sim_unw $file_ref_sec.diff 10 2 1 0 0.2

rasmph_pwr $file_ref_sec.diff $file_ref.rmli $range_samples_ref 1 0 1 1 rmg.cm output/$file_ref_sec.$i.3diff.bmp

geocode_back $file_ref.rmli $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.rmli $dem_range_width $dem_azimuth_lines 5 0 - - 3

geocode_back $file_ref_sec.diff $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref_sec.diff $dem_range_width $dem_azimuth_lines 4 1 - - 3

rasmph_pwr UTM.$file_ref_sec.diff UTM.$file_ref.rmli $dem_range_width 1 0 1 1 rmg.cm output/tmp3.$i.bmp

data2geotiff dem/$file_ref._UTM_seg.dem_par output/tmp3.$i.bmp 0 output/UTM.$file_ref_sec.$i.3diff.tif

multi_look $file_sec.rslc $file_sec.rslc.par $file_sec.rmli $file_sec.rmli.par 10 2

cc_wave $file_ref_sec.diff $file_ref.rmli $file_sec.rmli $file_ref_sec.diff.cc $range_samples_ref 5 5 0

adf2 $file_ref_sec.diff $file_ref_sec.diff.cc filt.$file_ref_sec.diff filt.$file_ref_sec.diff.cc $range_samples_ref

rascc_mask filt.$file_ref_sec.diff.cc $file_ref.rmli $range_samples_ref - - - - - 0.35 0.0 0.0 1.0 - - - output/filt.$file_ref_sec.$i.3diff.cc.bmp

geocode_back filt.$file_ref_sec.diff.cc $range_samples_ref dem/$file_ref._UTM.lt_fine output/UTM.$file_ref_sec.$i.3diff.cc $dem_range_width $dem_azimuth_lines 4 0 - - 3

data2geotiff dem/$file_ref._UTM_seg.dem_par output/UTM.$file_ref_sec.$i.3diff.cc 2 output/UTM.$file_ref_sec.$i.3diff.cc.tif

rasdt_pwr filt.$file_ref_sec.diff $file_ref.rmli $range_samples_ref - - - - - - 0 rmg.cm output/filt.$file_ref_sec.$i.3diff.bmp

mcf filt.$file_ref_sec.diff - output/filt.$file_ref_sec.$i.3diff.cc.bmp $file_ref_sec.3diff.unw $range_samples_ref 1 - - - - - - - - - 1

rasdt_pwr $file_ref_sec.3diff.unw $file_ref.rmli $range_samples_ref - - - - 0 5 1 rmg.cm output/$file_ref_sec.$i.3diff.unw.bmp

dh_map_orb $file_ref.rslc.par $file_sec.rslc.par $file_ref_sec.off dem/$file_ref._UTM.hgt $file_ref_sec.3diff.unw $file_ref_sec.dpdh $file_ref_sec.dh $file_ref.rslc.par 1

rasdt_pwr $file_ref_sec.dh $file_ref.rmli $range_samples_ref - - - - 0 300 1 rmg.cm output/$file_ref_sec.$i.3dh.bmp

float_math dem/$file_ref._UTM.hgt $file_ref_sec.dh $file_ref.hgt1 $range_samples_ref 0

rasdt_pwr $file_ref.hgt1 $file_ref.rmli $range_samples_ref - - - - 0 200 1 rmg.cm output/$file_ref.$i.3hgt1.bmp

geocode_back $file_ref.rmli $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.rmli $dem_range_width $dem_azimuth_lines 5 0 - - 3

geocode_back $file_ref.hgt1 $range_samples_ref dem/$file_ref._UTM.lt_fine UTM.$file_ref.hgt1 $dem_range_width $dem_azimuth_lines 4 0 - - 3

interp_ad UTM.$file_ref.hgt1 UTM.$file_ref.hgt2 $dem_range_width 10 15 25 2 2 1

data2geotiff dem/$file_ref._UTM_seg.dem_par UTM.$file_ref.hgt2 2 output/UTM3.hgt1.${file_ref_sec}_$i.tif

done

date

done

# ---------------------
# GAMMA code ends here
# ---------------------

