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
#include <vector>
#include <string>
/*
 * General ITK
 */
#include "itkImage.h"
/*
 * ITK Filters
 */
#include "itkBinaryThresholdImageFilter.hxx"
#include "itkApproximateSignedDistanceMapImageFilter.h"
#include <itkHistogramMatchingImageFilter.h>
/*
 * Others
 */
#include "util/helpers.h"
#include "3rdparty/tclap/CmdLine.h"

/*
 * Pixel types
 */
typedef float PixelType;
typedef float DistanceType;
/*
 * Image types
 */
typedef itk::Image< PixelType, DIM > ImageType;
typedef itk::Image< DistanceType, DIM > DistanceImageType;

typedef itk::BinaryThresholdImageFilter< ImageType, ImageType > BinaryThresholdImageFilterType;
typedef itk::ApproximateSignedDistanceMapImageFilter< ImageType,
    DistanceImageType > ApproximateSignedDistanceMapImageFilterType;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Distance map " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "out.nii.gz", "string", cmd);

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
  const PixelType thrVal = itk::NumericTraits<PixelType>::epsilon();
  const PixelType foreground = 255;

  ImageType::Pointer inputIMage = cascade::util::LoadImage< ImageType >(
      input.getValue());
  BinaryThresholdImageFilterType::Pointer thresholdFilter =
      BinaryThresholdImageFilterType::New();
  thresholdFilter->SetInput(inputIMage);
  thresholdFilter->SetLowerThreshold(thrVal);
  thresholdFilter->SetInsideValue(foreground);
  thresholdFilter->SetOutsideValue(thrVal);

  ReportFilterMacro(thresholdFilter);

  ApproximateSignedDistanceMapImageFilterType::Pointer approximateSignedDistanceMapImageFilter =
      ApproximateSignedDistanceMapImageFilterType::New();
  approximateSignedDistanceMapImageFilter->SetInput(thresholdFilter->GetOutput());
  approximateSignedDistanceMapImageFilter->SetInsideValue(thresholdFilter->GetInsideValue());
  approximateSignedDistanceMapImageFilter->SetOutsideValue(thresholdFilter->GetOutsideValue());

  cascade::util::WriteImage(
      outfile.getValue(), approximateSignedDistanceMapImageFilter->GetOutput());

  return EXIT_SUCCESS;
  }
