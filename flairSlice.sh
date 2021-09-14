#!/bin/bash

Usage() {
    echo "
    ++++++++++++++++++++++++++++++++++++++++ flairSlice.sh +++++++++++++++++++++++++++++++++++++++
          Slicing FLAIR image into three clinically representative slices
          Three slices are provided,
            1. Centrum Semiovale level
            2. Corona Radiata level
            3. Striatocapsular level
    ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo ""
    echo " Usage: flairSlice.sh --flair=flair.nii.gz --t1=t1.nii.gz --refer=ch2better.nii.gz "
    echo ""
    echo ""
    echo " [Option Description] "
    echo "    --flair=<image>        : 2D flair image "
    echo "    --t1=<string>          : t1 mprage image "
    echo "    --refer=<string>       : standard template image (ch2better.nii.gz) "
    echo ""
    echo " Version History:
        Ver 0.10 : [2021.05.24] Release of the toolbox
        ""
 This script was created by:
      Uksu, Choi (qtwing@naver.com)
      "
    exit 1
}

#echo $@
[ "$2" = "" ] && Usage

################## parameter setting ###########################################
get_opt1() {
    arg=`echo $1 | sed 's/=.*//'`
    echo $arg
}

get_arg1() {
    if [ X`echo $1 | grep '='` = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    else
	arg=`echo $1 | sed 's/.*=//'`
	if [ X$arg = X ] ; then
	    echo "Option $1 requires an argument" 1>&2
	    exit 1
	fi
	echo $arg
    fi
}

get_imarg1() {
    arg=`get_arg1 $1`;
    arg=`$FSLDIR/bin/remove_ext $arg`;
    echo $arg
}

get_arg2() {
    if [ X$2 = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    fi
    echo $2
}
################################################################################

############# set the inputs ###################################################
# list of variables to be set via the options
f_img="";
t1_img="";
ref_img="";

# input variables
if [ $# -lt 2 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=`get_opt1 $1`;
    case "$iarg"
	in
  --flair)
      f_img=`get_imarg1 $1`;
      shift;;
  --t1)
      t1_img=`get_imarg1 $1`;
      shift;;
  --refer)
	    ref_img=`get_imarg1 $1`;
	    shift;;
	-h)
	    Usage;
	    exit 0;;
	*)
	    #if [ `echo $1 | sed 's/^\(.\).*/\1/'` = "-" ] ; then
	    echo "Unrecognised parameter $1" 1>&2
	    exit 1
    esac
done


##################### Check dependencies #######################################
#### check software dependencies
# software 01
if command -v fsl >/dev/null 2>&1 ; then
    echo "
    + 'FSL' found
    "
else
    echo "
    [Caution]! FSL not found, please install before running this script.
    "
    exit 1
fi

# software 02
if command -v antsRegistration >/dev/null 2>&1 ; then
    echo "
    + 'ANTs' found
    "
else
    echo "
    [Caution]! ANTs not found, please install before running this script.
    "
    exit 1
fi

# software 03
if command -v 3dRSFC >/dev/null 2>&1 ; then
    echo "
    + 'AFNI' found
    "
else
    echo "
    [Caution]! AFNI not found, please install before running this script.
    "
    exit 1
fi


#### check script dependencies
# script 01
if command -v antsRegistrationSyNQuick.sh >/dev/null 2>&1 ; then
    echo "
    > [Script] 'antsRegistrationSyNQuick.sh' found"
else
    echo "
    [Caution]! antsRegistrationSyNQuick.sh not found, please install before running this script.
    "
    exit 1
fi

# template data check
if [ -f "${FSL_DIR}/data/standard/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz" ]; then
    echo "
    > [Script] 'template files' were found"
else
    echo "
    [Caution]! 'template files' were not found.
    Please download files in ${FSL_DIR}/data/standard directory
    "
    exit 1
fi

## time stamp
time_start=`date +%s`

############### preprocessing #################################################################################################
## Brain extraction (flair)
if [ -f ${f_img}_brain.nii.gz ]; then
echo "
  +++ ${f_img}_brain.nii.gz is found, we skip this process."
else
  echo "
      +++ ${f_img}_brain.nii.gz is not exist, brain extraction is starting"
  bet2 ${f_img}.nii.gz ${f_img}_brain.nii.gz -f 0.4 -w 1.5
fi

## Brain extraction (t1)
if [ -f ${t1_img}_brain.nii.gz ]; then
echo "
  +++ ${t1_img}_brain.nii.gz is found, we skip this process."
else
  echo "
      +++ ${t1_img}_brain.nii.gz is not exist, brain extraction is starting"
  N4BiasFieldCorrection -d 3 -i ${t1_img}.nii.gz -b [200] -o ${t1_img}_bias.nii.gz -v
  antsBrainExtraction.sh \
                      -d 3 \
                      -a ${t1_img}_bias.nii.gz \
                      -e ${FSL_DIR}/data/standard/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz \
                      -m ${FSL_DIR}/data/standard/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz \
                      -f ${FSL_DIR}/data/standard/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumRegistrationMask.nii.gz \
                      -o Ext
  # convert
  bet2 ExtBrainExtractionBrain ExtBrainExtractionBrain_tmp -f 0.1 -w 1 # emparically defined
  fslmaths ExtBrainExtractionBrain_tmp ${t1_img}_brain.nii.gz
  # clean
  rm -r Ext
fi

## N4 inhomogeneity correction
if [ -f ${f_img}_brain_bias.nii.gz ]; then
echo "
  +++ ${f_img}_brain_bias.nii.gz is found, we skip this process."
else
  echo "
      +++ ${f_img}_brain_bias.nii.gz is not exist, N4 inhomogeneity correction is starting"
  N4BiasFieldCorrection -d 3 -i ${f_img}_brain.nii.gz -b [200] -o ${f_img}_brain_bias.nii.gz -v
  N4BiasFieldCorrection -d 3 -i ${t1_img}_brain.nii.gz -b [200] -o ${t1_img}_brain_bias.nii.gz -v
fi

## Resample image dimensions
if [ -f ${t1_img}_resample.nii.gz ]; then
echo "
  +++ ${t1_img}_resample.nii.gz is found, we skip this process."
else
  echo "
      +++ ${t1_img}_resample.nii.gz is not exist, resampling of images is starting"
  f_pixdimx=($(echo `fslval ${f_img} pixdim1`))
  f_pixdimy=($(echo `fslval ${f_img} pixdim2`))
  f_pixdimz=($(echo `fslval ${f_img} pixdim3`))
  ## resample to input image
  3dresample -rmode NN -prefix ${t1_img}_resample.nii.gz -input ${t1_img}_brain_bias.nii.gz -dxyz ${f_pixdimx} ${f_pixdimy} ${f_pixdimz}
  3dresample -rmode NN -prefix ${ref_img}_resample.nii.gz -input ${ref_img}.nii.gz -dxyz ${f_pixdimx} ${f_pixdimy} ${f_pixdimz}
  ## masking
  fslmaths ${t1_img}_resample.nii.gz -bin ${t1_img}_mask.nii.gz
  fslmaths ${ref_img}_resample.nii.gz -bin ${ref_img}_mask.nii.gz
fi

################ Main run #################################################################################################
## registration from flair to t1
if [ -f ${f_img}_2_${t1_img}.nii.gz ]; then
echo "
  +++ ${f_img}_2_${t1_img}.nii.gz is found, we skip this process."
else
  echo "
      +++ ${f_img}_2_${t1_img}.nii.gz is not exist, multi-modal registration using ANTs is starting"
  flirt -dof 6 -in ${f_img}_brain_bias -ref ${t1_img}_resample -omat inputReg.mat -out ${f_img}_2_${t1_img}.nii.gz -v
fi

## registration from t1 to refer using non-linear
if [ -f ${t1_img}_2_${ref_img}.nii.gz ]; then
echo "
  +++ ${t1_img}_2_${ref_img}.nii.gz is found, we skip this process."
else
  echo "
      +++ ${t1_img}_2_${ref_img}.nii.gz is not exist, affine registration using FSL is starting"
  antsIntermodalityIntrasubject.sh -d 3 -i ${t1_img}_resample.nii.gz -r ${ref_img}_resample.nii.gz \
  -x ${ref_img}_mask.nii.gz -w t1img2temp_ -t 3 -o t1reg
  cp t1reganatomical.nii.gz ${t1_img}_2_${ref_img}.nii.gz
fi

## registration from flair to refer using non-linear
if [ -f ${f_img}_2_${ref_img}.nii.gz ]; then
echo "
  +++ ${f_img}_2_${ref_img}.nii.gz is found, we skip this process."
else
  echo "
      +++ ${f_img}_2_${ref_img}.nii.gz is not exist, affine registration using transformation matrix is starting"
  antsApplyTransforms \
              --dimensionality 3 \
              --input ${f_img}_2_${t1_img}.nii.gz \
              --reference-image ${ref_img}_resample.nii.gz \
              --output ${f_img}_2_${ref_img}.nii.gz \
              --n Linear \
              --transform t1reg1Warp.nii.gz \
              --transform t1reg0GenericAffine.mat \
              --default-value 0
fi

## slicing flair images
if [ -f ${f_img}_2_${ref_img}_highres.nii.gz ]; then
echo "
  +++ ${f_img}_2_${ref_img}_highres.nii.gz is found, we skip this process."
else
  echo "
      +++ ${f_img}_2_${ref_img}_highres.nii.gz is not exist, affine registration using transformation matrix is starting"
  r_pixdimx=($(echo `fslval ${ref_img} pixdim1`))
  r_pixdimy=($(echo `fslval ${ref_img} pixdim2`))
  r_pixdimz=($(echo `fslval ${ref_img} pixdim3`))
  3dresample -rmode NN -prefix ${f_img}_2_${ref_img}_highres.nii.gz -input ${f_img}_2_${ref_img}.nii.gz -dxyz ${r_pixdimx} ${r_pixdimy} ${r_pixdimz}
  # slicing
  r_dimx=($(echo `fslval ${ref_img} dim1`))
  r_dimy=($(echo `fslval ${ref_img} dim2`))
  r_dimz=($(echo `fslval ${ref_img} dim3`))
  fslroi ${f_img}_2_${ref_img}_highres.nii.gz ${f_img}_slice1 0 ${r_dimx} 0 ${r_dimy} 206 1 # Centrum Semiovale level
  fslroi ${f_img}_2_${ref_img}_highres.nii.gz ${f_img}_slice2 0 ${r_dimx} 0 ${r_dimy} 182 1 # Corona Radiata level
  fslroi ${f_img}_2_${ref_img}_highres.nii.gz ${f_img}_slice3 0 ${r_dimx} 0 ${r_dimy} 158 1 # Striatocapsular level
fi

################ remove intermediate files #####################################
find . ! name "${t1_img}.nii.gz" ! name "${ref_img}.nii.gz" ! name "${f_img}.nii.gz" ! -name "*slice*.nii.gz" ! -name "*ch2better_highres.nii.gz" -type f -delete
rmdir -p t1reg
################################################################################

# finish time recording
time_end=`date +%s`
time_elapsed=$((time_end - time_start))
echo
echo "--------------------------------------------------------------------------------------"
echo " flairSlice processing is completed in $time_elapsed seconds"
echo " $(( time_elapsed / 3600 ))h $(( time_elapsed %3600 / 60 ))m $(( time_elapsed % 60 ))s"
echo "--------------------------------------------------------------------------------------"
exit 0
