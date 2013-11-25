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
#include "itkBinaryThresholdImageFilter.h"
#include "itkBinaryImageToShapeLabelMapFilter.h"
#include "itkShapeOpeningLabelMapFilter.h"
#include "itkLabelStatisticsOpeningImageFilter.h"
#include "itkMaskImageFilter.h"
/*
 * Others
 */
#include "util/helpers.h"
#include "3rdparty/tclap/CmdLine.h"
/*
 * Pixel types
 */
typedef float PixelType;
typedef unsigned int LabelType;
/*
 * Image types
 */
typedef itk::Image< PixelType, DIM > ImageType;
typedef itk::Image< LabelType, DIM > LabelImageType;

typedef itk::BinaryThresholdImageFilter< ImageType, ImageType > BinaryThresholdImageFilterType;
typedef itk::BinaryImageToShapeLabelMapFilter< ImageType > BinaryImageToShapeLabelMapFilterType;
typedef BinaryImageToShapeLabelMapFilterType::OutputImageType ShapeLabelMapType;
typedef itk::LabelMapToLabelImageFilter< ShapeLabelMapType, LabelImageType > LabelMapToLabelImageFilterType;
typedef itk::LabelStatisticsOpeningImageFilter< LabelImageType, ImageType > LabelStatisticsOpeningFilterType;
typedef itk::MaskImageFilter<ImageType, LabelImageType,ImageType> MaskFilterType;

/*
 * IO types
 */
typedef itk::ImageFileWriter< ImageType > WriterType;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Statistics filter image " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "out.nii.gz", "string", cmd);

  TCLAP::SwitchArg reverseSwitch("r", "reverse", "Threshold backwards", cmd,
                                 false);

  TCLAP::ValueArg< float > threshold("t", "threshold",
                                     "property to be filtered. ", false, 0.0,
                                     "Threshold", cmd);

  std::vector< std::string > allowedProperty;
  allowedProperty.push_back("Minimum");
  allowedProperty.push_back("Maximum");
  allowedProperty.push_back("Mean");
  allowedProperty.push_back("Sum");
  allowedProperty.push_back("StandardDeviation");
  allowedProperty.push_back("Variance");
  allowedProperty.push_back("Median");
  allowedProperty.push_back("MaximumIndex");
  allowedProperty.push_back("MinimumIndex");
  allowedProperty.push_back("CenterOfGravity");
  allowedProperty.push_back("WeightedPrincipalMoments");
  allowedProperty.push_back("WeightedPrincipalAxes");
  allowedProperty.push_back("Kurtosis");
  allowedProperty.push_back("Skewness");
  allowedProperty.push_back("WeightedElongation");
  allowedProperty.push_back("Histogram");
  allowedProperty.push_back("WeightedFlatness");

  TCLAP::ValuesConstraint< std::string > allowedVals(allowedProperty);

  TCLAP::ValueArg< std::string > property("", "property",
                                          "Property to be filtered.", false,
                                          "NumberOfPixels", &allowedVals, cmd);

  TCLAP::ValueArg< float > binarize("b", "bin-threshold",
                                    "Threshold to binarize image. ", false, 0.0,
                                    "Threshold", cmd);

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
    const PixelType thrVal = 0;
    const PixelType foreground = 1;

    ImageType::Pointer inputIMage = cascade::util::LoadImage< ImageType >(
        input.getValue());
    BinaryThresholdImageFilterType::Pointer thresholdFilter =
        BinaryThresholdImageFilterType::New();
    thresholdFilter->SetInput(inputIMage);
    thresholdFilter->SetLowerThreshold(binarize.getValue());
    thresholdFilter->SetInsideValue(foreground);
    thresholdFilter->SetOutsideValue(thrVal);

    BinaryImageToShapeLabelMapFilterType::Pointer binaryImageToShapeLabelMapFilter =
        BinaryImageToShapeLabelMapFilterType::New();
    binaryImageToShapeLabelMapFilter->FullyConnectedOn();
    binaryImageToShapeLabelMapFilter->SetInputForegroundValue(foreground);
    binaryImageToShapeLabelMapFilter->SetInput(thresholdFilter->GetOutput());

    LabelMapToLabelImageFilterType::Pointer labelMapToLabelImageFilter =
        LabelMapToLabelImageFilterType::New();
    labelMapToLabelImageFilter->SetInput(
        binaryImageToShapeLabelMapFilter->GetOutput());

    LabelStatisticsOpeningFilterType::Pointer statisticsOpeningFilter =
        LabelStatisticsOpeningFilterType::New();
    statisticsOpeningFilter->SetInput(
        labelMapToLabelImageFilter->GetOutput());
    statisticsOpeningFilter->SetFeatureImage(inputIMage);

    statisticsOpeningFilter->SetLambda(threshold.getValue());
    statisticsOpeningFilter->SetReverseOrdering(reverseSwitch.getValue());
    statisticsOpeningFilter->SetAttribute(property.getValue());

    MaskFilterType::Pointer negatedMask = MaskFilterType::New();
    negatedMask->SetInput(inputIMage);
    negatedMask->SetMaskImage(statisticsOpeningFilter->GetOutput());

    cascade::util::WriteImage(outfile.getValue(), negatedMask->GetOutput());
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
