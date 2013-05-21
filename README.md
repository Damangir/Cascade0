Cascade: Classification of White Matter Lesions
=======

Introduction
-------
Cascade, Classification of White Matter Lesions, is a fully automated tool for quantification of White Matter Lesions. Cascade is designed to be as flexible as possible. and can work with all sort of input sequences. It can work without any manually delineated samples as reference.

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
cascade --version
```

Citation
-------
Any scientific work derived from the result of this software or its modifications should refer to [our paper](http://www.ncbi.nlm.nih.gov/pubmed/22921728):

> Damangir S, Manzouri A, Oppedal K, Carlsson S, Firbank MJ, Sonnesyn H, Tysnes OB, O'Brien JT, Beyer MK, Westman E, Aarsland D, Wahlund LO, Spulber G. Multispectral MRI segmentation of age related white matter changes using a cascade of support vector machines. J Neurol Sci. 2012 Nov 15;322(1-2):211-6. doi: 10.1016/j.jns.2012.07.064. Epub 2012 Aug 24. PubMed PMID: 22921728.


Manual
-------

### Preprocessing
Before running the **cascade** you should perform the following preprocessing steps to your subject:

 * Co-register all available sequences together
 * Extract brain

These steps are not required but they are strongly recommended:

 * Inhomogeneity correction
 * Brain tissue segmentation

This step is optional but can help to increase the accuracy of the results:

 * Nonlinearly register T1-weighted image to MNI152 and save the transformation matrix and deformation field 

### WML segmentation
Once you have done the preprocessing on the subject.
depending on different preprocessing you can use **cascade** as follows.

#### Only registered, brain extracted images are available
You should input the sequences in which the white matter lesions appear hyper-intense (e.g. FLAIR) with flag `-l` and those with hypo-intense white matter lesions (e.g. T1-wighted) with flag `-d`. You can use as much sequence as you want, the only requirement is that you should have at least one hyper-intense sequence.

```bash
cascade -l FLAIR.nii.gz -d T1.nii.gz
```

#### Registered image with brain tissue segmentation
Once you have brain tissue segmentation **cascade** can benefit from its information and increase its accuracy as much as 20%. **cascade** expects the brain tissue segmentation as a label image with white matter as highest and grey matter the scone highest (e.g. CSF: 1 GM: 2 WM: 3). You should specify the labeled image with flag `-m` and set the value for grey matter with flag `-t`

```bash
cascade -l FLAIR.nii.gz -d T1.nii.gz -m pveseg.nii.gz -t 2
```

#### Registration to standard template is available
If you have the registration information to the standard space, you can perform additional post-processing to the output result. The post-processor is not part of the cascade distribution however you are welcome to contact us and we will provide you with the post-processor software.
