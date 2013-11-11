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
/*
 * ITK Filters
 */
#include "itkCastImageFilter.h"
#include "itkBilateralImageFilter.h"
#include "itkMaskImageFilter.h"
#include "itkBinaryThresholdImageFilter.h"
/*
 * Others
 */
#include "pipeline/itkSliceNormalizerPipeline.h"
#include "pipeline/itkN4Pipeline.h"
#include "pipeline/itkRobustOutlierPipeline.h"
#include "pipeline/itkIntensityNormalizerPipeline.h"

#include "util/helpers.h"
#include "3rdparty/tclap/CmdLine.h"

/*
 * Pixel types
 */
typedef unsigned int InputPixelType;
typedef float OutputPixelType;
typedef float InterimPixelType;
typedef char MaskPixelType;
/*
 * Image types
 */
typedef itk::Image< InputPixelType, DIM > InputImageType;
typedef itk::Image< OutputPixelType, DIM > OutputImageType;
typedef itk::Image< MaskPixelType, DIM > MaskImageType;

typedef itk::Image< InterimPixelType, DIM > InterimImageType;
typedef itk::Image< InterimPixelType, SLICEDIM > InterimSliceType;

typedef itk::CastImageFilter< InputImageType, InterimImageType > CastToInterimType;
typedef itk::CastImageFilter< InterimImageType, OutputImageType > CastToOutputType;

typedef itk::SliceNormalizerPipeline< InterimImageType, InterimImageType, MaskImageType > SliceNormalizerType;
typedef itk::IntensityNormalizerPipeline< InterimImageType, InterimImageType, MaskImageType > IntensityNormalizerType;

typedef itk::BinaryThresholdImageFilter< MaskImageType, MaskImageType > BinaryThresholdImageFilterType;
typedef itk::N4Pipeline< InterimImageType, InterimImageType > N4PipelineType;
typedef itk::MaskImageFilter< InterimImageType, InterimImageType > MaskFilterType;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Image intensity range controller " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "out.nii.gz", "string", cmd);

  TCLAP::SwitchArg scaleSwitch("", "no-scale", "Do not apply scale factor", cmd,
                                 true);

  TCLAP::ValueArg< unsigned int > bins("b", "bins", "", false, 20, "Integer",
                                       cmd);

  TCLAP::ValueArg< std::string > mask("m", "mask",
                                      "Mask sequences e.g. mask.nii.gz", false,
                                      "", "string", cmd);

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
    BinaryThresholdImageFilterType::Pointer thresholdFilter =
        BinaryThresholdImageFilterType::New();

    if (mask.isSet())
      {
      thresholdFilter->SetInput(
          cascade::util::LoadImage< MaskImageType >(mask.getValue()));
      }
    else
      {
      thresholdFilter->SetInput(
          cascade::util::LoadImage< MaskImageType >(input.getValue()));
      }

    thresholdFilter->SetLowerThreshold(1);

    CastToInterimType::Pointer castToInterim = CastToInterimType::New();
    castToInterim->SetInput(
        cascade::util::LoadImage< InputImageType >(input.getValue()));

    SliceNormalizerType::Pointer sliceNormalizer = SliceNormalizerType::New();
    sliceNormalizer->SetInput(castToInterim->GetOutput());
    sliceNormalizer->SetMaskImage(thresholdFilter->GetOutput());
    sliceNormalizer->SetMaskValue(thresholdFilter->GetInsideValue());
    sliceNormalizer->SetNumberOfLevels(bins.getValue());

    N4PipelineType::Pointer n4Corrector = N4PipelineType::New();
    n4Corrector->SetInput(sliceNormalizer->GetOutput());
    n4Corrector->Update();

    IntensityNormalizerType::Pointer intensityNormalizer =
        IntensityNormalizerType::New();

    MaskFilterType::Pointer maskFilter = MaskFilterType::New();
    maskFilter->SetMaskImage(castToInterim->GetOutput());

    if(scaleSwitch.getValue())
      {
      intensityNormalizer->SetInput(n4Corrector->GetOutput());
      intensityNormalizer->SetMaskImage(thresholdFilter->GetOutput());
      intensityNormalizer->SetMaskValue(thresholdFilter->GetInsideValue());
      intensityNormalizer->SetNumberOfLevels(bins.getValue());

      maskFilter->SetInput(intensityNormalizer->GetOutput());
      }else{
        maskFilter->SetInput(n4Corrector->GetOutput());
      }
    CastToOutputType::Pointer castToOutput = CastToOutputType::New();
    castToOutput->SetInput(maskFilter->GetOutput());
    castToOutput->Update();

    cascade::util::WriteImage(outfile.getValue(), castToOutput->GetOutput());
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
