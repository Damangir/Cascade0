Cascade: Classification of White Matter Lesions
=======

Content
-------
* [Introduction](#introduction)
* [Installation](#install)
* [Manual](#manual)
  * [Preprocessing](#preprocessing)
  * [White matter lesion segmentation](#wml-segmentation)
  * [Sample usage](#sample-usage)
* [Citation](#citation)
* [Copyright](#copyright)
* [License](#license)


Introduction
-------
Cascade, Classification of White Matter Lesions, is a fully automated tool for quantification of White Matter Lesions. Cascade is designed to be as flexible as possible. and can work with all sort of input sequences. It can work without any manually delineated samples as reference.

Please [report any issue](https://github.com/Damangir/Cascade/issues) at https://github.com/Damangir/Cascade/issues.

Install
-------
In order to install the software you need to have the following application installed on your computer.

 * Modern C++ compiler (gcc is recommended)
 * cmake 2.8+ (cmake.org)
 * make
 * Insight Toolkit 4.0+ (itk.org)

You can check availability of these packages on your computer (on Unix-like computers e.g. Mac and Ubuntu)
```bash
echo -ne "C++ compiler: "; command -v cc||  command -v gcc||  command -v clang||  command -v c++||  echo "No C++ compiler found"
make --version
cmake --version
```

In order to check if you have Insight Toolkit installed, you have to search for the file: ITKConfig.cmake . If you can not find this file
you have to download and install Insight Toolkit. If you have C++ compiler, make and cmake installation of Insight Toolkit is streight
forward. Suppose the directory containing ITKConfig.cmake is named `/usr/local/lib/cmake/InsightToolkit4.3/` . Run:

```bash
export ITK_DIR=/usr/local/lib/cmake/InsightToolkit4.3/
```

Now you are ready to install the **cascade**:

```bash
unzip CascadevXX.zip
cd CascadevXX
mkdir build
cd build
cmake ../src
make
```

Optionally if you want to install the software systemwide you can do so by (you should have the administrative right to do so):

```bash
sudo make install
```

You can assert the installation

```bash
cascade -v
```

Manual
-------

### Preprocessing
Before running the **cascade** you should perform the following preprocessing steps to your subject:

 * Co-register all available sequences together
 * Skull stripping (Brain extraction)
 * Partial Volume Estimation
 * Intensity normalization

There is a helper script to do these steps called `cascade_pre.sh`. Type `cascade_pre.sh -h` for more help and options.

### WML segmentation
You should be provided with a state file series alongside your **cascade** installation. There is a two step procedure before you can have your final report"

 * Likelihood calculation
 * False positive removal and post processing

There is a helper script to do these steps called `cascade_main.sh`. Type `cascade_main.sh -h` for more help and options.

There is also a reporting part which will provide a comma-separated values (CSV) file containing WML volume, WML volume per lobe, brain tissue fractions (WM, GM and CSF). The reporting system will also create overlays on all input sequences on NIFTI (for 3d viewing) and PNG (for use in publication).


### Sample usage
Suppose that for your subject you have T1-weighted and FLAIR sequence. Select a folder name where you want your result to be. For this example I'll use `/home/soheil/Project_1/Subject_1`

```bash
cascade-pre.sh -t T1.nii.gz -f FLAIR.nii.gz -b T1_BRAIN_MASK.nii.gz -r /home/soheil/Project_1/Subject_1
```

This will create a directory structure and put all needed files in place. You should have a directory structure similar to:

```
/home/soheil/Project_1/Subject_1
├── cache
├── images
└── transformations
```

Once the preprocessing completed you should run the main script:

```bash
cascade-main.sh -r /home/soheil/Project_1/Subject_1 -s ${CASCADEDIR}/states/FLAIR_T1
```

where `${CASCADEDIR}/states/FLAIR_T1` is the location of state images. You can use the pre-trained state image shipped alongside the **cascade** installation or use your own trained state image.

After running the main script your directory structure would be:

```
/home/soheil/Project_1/Subject_1
├── cache
├── images
├── ranges
├── report
│   └── overlays
└── transformations
```

The actual output of the **cascade** lies in the report folder alongside with the overlays.

Citation
-------
Any scientific work derived from the result of this software or its modifications should refer to [our paper](http://www.ncbi.nlm.nih.gov/pubmed/22921728):

> Damangir S, Manzouri A, Oppedal K, Carlsson S, Firbank MJ, Sonnesyn H, Tysnes OB, O'Brien JT, Beyer MK, Westman E, Aarsland D, Wahlund LO, Spulber G. Multispectral MRI segmentation of age related white matter changes using a cascade of support vector machines. J Neurol Sci. 2012 Nov 15;322(1-2):211-6. doi: 10.1016/j.jns.2012.07.064. Epub 2012 Aug 24. PubMed PMID: 22921728.

Copyright
-------
Copyright (C) 2013 [Soheil Damangir](http://www.linkedin.com/in/soheildamangir) - All Rights Reserved

License
-------
[![Creative Commons License](https://raw.github.com/Damangir/Cascade/master/license.png "Creative Commons License")](http://creativecommons.org/licenses/by-nc-nd/3.0/)

Cascade by [Soheil Damangir](http://www.linkedin.com/in/soheildamangir) is licensed under a [Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License](http://creativecommons.org/licenses/by-nc-nd/3.0/).
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/3.0/.

