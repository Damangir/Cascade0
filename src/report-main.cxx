/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */

#include "buildinfo.h"
/*
 * CPP Headers
 */
#include <string>
/*
 * General ITK
 */
#include "itkImage.h"
#include "itkNumericSeriesFileNames.h"
#include "itkImageAlgorithm.h"
/*
 * ITK Filters
 */
#include "itkFlipImageFilter.h"
#include "itkRescaleIntensityImageFilter.h"
#include "itkImageRegionIterator.h"
#include "itkSliceBySliceImageFilter.h"
#include "itkBinaryContourImageFilter.h"
#include "itkLabelOverlayImageFilter.h"
#include "itkRGBPixel.h"
/*
 * Others
 */
#include "3rdparty/tclap/CmdLine.h"
#include "util/helpers.h"
/*
 * Pixel types
 */
typedef unsigned int PixelType;
typedef itk::RGBPixel< unsigned short > RGBPixelType;
/*
 * Image types
 */
typedef itk::Image< PixelType, DIM > ImageType;
typedef itk::Image< RGBPixelType, DIM > RGBImageType;
typedef itk::Image< PixelType, SLICEDIM > SliceType;
typedef itk::Image< RGBPixelType, SLICEDIM > RGBSliceType;

typedef itk::BinaryContourImageFilter< SliceType, SliceType > binaryContourImageFilterType;
typedef itk::RescaleIntensityImageFilter< ImageType, ImageType > RescaleFilterType;
typedef itk::LabelOverlayImageFilter< ImageType, ImageType, RGBImageType > LabelOverlayImageFilterType;

typedef itk::SliceBySliceImageFilter< ImageType, ImageType > SlicerType;

typedef itk::FlipImageFilter< RGBImageType > FlipImageFilterType;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Image intensity range controller " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< unsigned int > dim2fold("d", "dim", "Dimension to fold",
                                           false, DIM - 1, "Integer", cmd);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "overlay", "string", cmd);

  TCLAP::ValueArg< std::string > mask("m", "mask", "Image mask", true, "",
                                      "string", cmd);

  TCLAP::ValueArg< std::string > input("i", "input",
                                       "Input sequences e.g. MPRAGE.nii.gz",
                                       true, "", "string", cmd);

  /*
   * Parse the argv array.
   */
  try
    {
    cmd.parse(argc, argv);
    }
  catch (TCLAP::ArgException &e)
    {
    std::ostringstream errorMessage;
    errorMessage << "error: " << e.error() << " for arg " << e.argId()
                 << std::endl;
    itk::OutputWindowDisplayErrorText(errorMessage.str().c_str());
    return EXIT_FAILURE;
    }

  /*
   * Argument and setting up the pipeline
   */
  try
    {

    ImageType::Pointer inputImage = cascade::util::LoadImage< ImageType >(
        input.getValue());
    ImageType::Pointer inputMask = cascade::util::LoadImage< ImageType >(
        mask.getValue());


    ImageType::RegionType nonzeroregion = cascade::util::ImageLargestNonZeroRegion(inputImage.GetPointer());

    inputImage = cascade::util::CropImage(inputImage.GetPointer(), nonzeroregion);
    inputMask = cascade::util::CropImage(inputMask.GetPointer(), nonzeroregion);


    binaryContourImageFilterType::Pointer binaryContourFilter =
        binaryContourImageFilterType::New();
    binaryContourFilter->SetForegroundValue(1);
    binaryContourFilter->FullyConnectedOff();

    SlicerType::Pointer slicer = SlicerType::New();
    slicer->SetDimension(dim2fold.getValue());
    slicer->SetFilter(binaryContourFilter);
    slicer->SetInput(inputMask);

    RescaleFilterType::Pointer rescaleFilter = RescaleFilterType::New();
    rescaleFilter->SetInput(inputImage);
    rescaleFilter->SetOutputMinimum(0);
    rescaleFilter->SetOutputMaximum(
        itk::NumericTraits< RGBPixelType::ComponentType >::max());

    LabelOverlayImageFilterType::Pointer labelOverlayImageFilter =
        LabelOverlayImageFilterType::New();
    labelOverlayImageFilter->SetInput(rescaleFilter->GetOutput());
    labelOverlayImageFilter->SetLabelImage(slicer->GetOutput());
    labelOverlayImageFilter->SetOpacity(1);
    labelOverlayImageFilter->Update();

    RGBImageType::Pointer rgbImage = labelOverlayImageFilter->GetOutput();

    cascade::util::WriteImage(outfile.getValue() + ".nii.gz",
                              rgbImage.GetPointer());

    /*
     * Niftii vertical dimension is bottom-up but it regular images its top-down.
     * Flip the image before writing it as image
     */
    itk::FixedArray< bool, DIM > flipAxes;
    flipAxes.Fill(0);
    flipAxes[1] = 1;
    FlipImageFilterType::Pointer flipFilter = FlipImageFilterType::New();
    flipFilter->SetInput(rgbImage);
    flipFilter->SetFlipAxes(flipAxes);
    flipFilter->Update();
    rgbImage = flipFilter->GetOutput();

    /*
     * Create slice by slice png
     */
    const RGBImageType::RegionType imageRegion =
        rgbImage->GetLargestPossibleRegion();
    const RGBImageType::IndexType requestedIndex = imageRegion.GetIndex();
    const RGBImageType::SizeType requestedSize = imageRegion.GetSize();
    typename RGBSliceType::RegionType sliceRegion;

    for (unsigned int i = 0, internal_i = 0; internal_i < DIM - 1;
        ++i, ++internal_i)
      {
      if (i == dim2fold.getValue()) ++i;
      sliceRegion.SetSize(internal_i, requestedSize[i]);
      sliceRegion.SetIndex(internal_i, requestedIndex[i]);
      }

    const itk::IndexValueType sliceRangeMax =
        static_cast< itk::IndexValueType >(requestedSize[dim2fold.getValue()]
            + requestedIndex[dim2fold.getValue()]);

    itk::NumericSeriesFileNames::Pointer numericSeriesFileNames =
        itk::NumericSeriesFileNames::New();
    numericSeriesFileNames->SetStartIndex(0);
    numericSeriesFileNames->SetEndIndex(sliceRangeMax);
    numericSeriesFileNames->SetSeriesFormat(outfile.getValue() + "_%03d.png");

    for (itk::IndexValueType slice_n = requestedIndex[dim2fold.getValue()];
        slice_n < sliceRangeMax; ++slice_n)
      {
      RGBImageType::RegionType regionForThisSlice = imageRegion;
      regionForThisSlice.SetIndex(dim2fold.getValue(), slice_n);
      regionForThisSlice.SetSize(dim2fold.getValue(), 1);

      itkAssertOrThrowMacro(
          regionForThisSlice.GetNumberOfPixels() == sliceRegion.GetNumberOfPixels(),
          "Number of pixels in slice and image regions does not match");

      RGBSliceType::Pointer slice = RGBSliceType::New();
      slice->SetRegions(sliceRegion);
      slice->Allocate();

      itk::ImageAlgorithm::Copy(rgbImage.GetPointer(), slice.GetPointer(),
                                regionForThisSlice, sliceRegion);

      cascade::util::WriteImage(numericSeriesFileNames->GetFileNames()[slice_n],
                                slice.GetPointer());
      }
    }
  catch (itk::ExceptionObject & err)
    {
    std::ostringstream errorMessage;
    errorMessage << "Exception caught!\n" << err << "\n";
    itk::OutputWindowDisplayErrorText(errorMessage.str().c_str());
    return EXIT_FAILURE;
    }

  return EXIT_SUCCESS;
  }
