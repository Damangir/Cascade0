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
 * ITK IO
 */
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"

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

typedef itk::ImageRegionIterator< RGBImageType > RGBImageIteratorType;
typedef itk::ImageRegionIterator< RGBSliceType > RGBSliceIteratorType;
/*
 * IO types
 */
typedef itk::ImageFileWriter< RGBImageType > OutputWriterType;
typedef itk::ImageFileWriter< RGBSliceType > ImageWriterType;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Image intensity range controller " BUILDINFO,
      ' ', CASCADE_VERSION);

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

  unsigned int dimension_fold = DIM - 1;
  /*
   * Argument and setting up the pipeline
   */
  try
    {
    ImageType* inputImage = cascade::util::LoadImage< ImageType >(
        input.getValue());

    binaryContourImageFilterType::Pointer binaryContourFilter =
        binaryContourImageFilterType::New();
    binaryContourFilter->SetForegroundValue(1);
    binaryContourFilter->FullyConnectedOff();

    SlicerType::Pointer slicer = SlicerType::New();
    slicer->SetDimension(dimension_fold);
    slicer->SetFilter(binaryContourFilter);
    slicer->SetInput(cascade::util::LoadImage< ImageType >(mask.getValue()));

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

    RGBImageType::Pointer rgbImage = RGBImageType::New();
    rgbImage = labelOverlayImageFilter->GetOutput();

    OutputWriterType::Pointer outputWriter = OutputWriterType::New();
    outputWriter->SetFileName(outfile.getValue() + ".nii.gz");
    outputWriter->SetInput(rgbImage);
    outputWriter->Update();

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
    const RGBImageType::RegionType requestedRegion =
        rgbImage->GetLargestPossibleRegion();
    const RGBImageType::IndexType requestedIndex = requestedRegion.GetIndex();
    const RGBImageType::SizeType requestedSize = requestedRegion.GetSize();
    typename RGBSliceType::RegionType internalRegion;
    unsigned int internal_i = 0;
    for (unsigned int i = 0; internal_i < SLICEDIM; ++i, ++internal_i)
      {
      if (i == dimension_fold)
        {
        ++i;
        }
      internalRegion.SetSize(internal_i, requestedSize[i]);
      internalRegion.SetIndex(internal_i, requestedIndex[i]);
      }
    const itk::IndexValueType sliceRangeMax =
        static_cast< itk::IndexValueType >(requestedSize[dimension_fold]
            + requestedIndex[dimension_fold]);

    itk::NumericSeriesFileNames::Pointer numericSeriesFileNames =
        itk::NumericSeriesFileNames::New();
    numericSeriesFileNames->SetStartIndex(0);
    numericSeriesFileNames->SetEndIndex(sliceRangeMax);
    numericSeriesFileNames->SetSeriesFormat(outfile.getValue() + "_%03d.png");

    for (itk::IndexValueType slice_n = requestedIndex[dimension_fold];
        slice_n < sliceRangeMax; ++slice_n)
      {
      RGBImageType::RegionType currentRegion = requestedRegion;
      currentRegion.SetIndex(slicer->GetDimension(), slice_n);
      currentRegion.SetSize(slicer->GetDimension(), 1);

      itkAssertOrThrowMacro(
          currentRegion.GetNumberOfPixels() == internalRegion.GetNumberOfPixels(),
          "Number of pixels in slice and image regions does not match");

      RGBSliceType::Pointer slice = RGBSliceType::New();
      slice->SetRegions(internalRegion);
      slice->Allocate();

      RGBImageIteratorType imgIt(rgbImage, currentRegion);
      RGBSliceIteratorType sliceIt(slice, internalRegion);
      itk::ImageRegionIterator< ImageType > orgIt(inputImage, currentRegion);
      orgIt.GoToBegin();
      imgIt.GoToBegin();
      sliceIt.GoToBegin();
      while (!imgIt.IsAtEnd())
        {
        sliceIt.Set(imgIt.Get());
        ++imgIt;
        ++sliceIt;
        ++orgIt;
        }
      ImageWriterType::Pointer sliceWriter = ImageWriterType::New();
      sliceWriter->SetInput(slice);
      sliceWriter->SetFileName(numericSeriesFileNames->GetFileNames()[slice_n]);
      sliceWriter->Update();
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
