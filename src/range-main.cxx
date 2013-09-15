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
#include "itkSliceBySliceImageFilter.h"
#include "itkCastImageFilter.h"
#include "itkCurvatureFlowImageFilter.h"
#include "itkBilateralImageFilter.h"
#include "itkMaskImageFilter.h"
#include "itkBinaryFunctorImageFilter.h"
#include "itkBinaryThresholdImageFilter.h"

#if ITK_VERSION_MAJOR >= 4
#include "itkComposeImageFilter.h"
#else
#include "itkImageToVectorImageFilter.h"
#endif
/*
 * ITK IO
 */
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
/*
 * Others
 */
#include "pipeline/itkImageNormalizerPipeline.h"
#include "pipeline/itkN4Pipeline.h"
#include "pipeline/itkRobustOutlierPipeline.h"
#include "util/itkIntensityAlignFunctor.h"
#include "util/helpers.h"
#include "3rdparty/tclap/CmdLine.h"

/*
 * Pixel types
 */
typedef unsigned int InputPixelType;
typedef float OutputPixelType;
typedef float InterimPixelType;
/*
 * Image types
 */
typedef itk::Image< InputPixelType, DIM > InputImageType;
typedef itk::Image< OutputPixelType, DIM > OutputImageType;

typedef itk::Image< InterimPixelType, DIM > InterimImageType;
typedef itk::Image< InterimPixelType, SLICEDIM > InterimSliceType;

typedef itk::CastImageFilter< InputImageType, InterimImageType > CastToInterimType;
typedef itk::CastImageFilter< InterimImageType, OutputImageType > CastToOutputType;

typedef itk::ImageNormalizerPipeline< InterimImageType, InterimImageType > Normalizer3dType;
typedef itk::ImageNormalizerPipeline< InterimSliceType, InterimSliceType > NormalizerType;
typedef itk::SliceBySliceImageFilter< InterimImageType, InterimImageType > SlicedFilterType;
typedef itk::N4Pipeline< InterimImageType, InterimImageType > N4PipelineType;

typedef itk::CurvatureFlowImageFilter< InterimImageType, InterimImageType > CurvatureFlowImageFilterType;
typedef itk::BilateralImageFilter< InterimImageType, InterimImageType > BilateralImageFilterType;
typedef itk::MaskImageFilter< InterimImageType, InterimImageType > MaskFilterType;

#if ITK_VERSION_MAJOR >= 4
typedef itk::ComposeImageFilter< InterimImageType > CollectorType;
#else
typedef itk::ImageToVectorImageFilter< InterimImageType > CollectorType;
#endif

typedef CollectorType::OutputImageType CollectedImageType;
typedef itk::RobustOutlierPipeline< CollectedImageType, InterimImageType > RobustOutlierPipelineType;
typedef RobustOutlierPipelineType::MaskImageType MaskImageType;
typedef itk::BinaryThresholdImageFilter< MaskImageType, MaskImageType > BinaryThresholdImageFilterType;

typedef itk::RobustMeanVariancePipeline< InterimImageType > StatCalculatorType;
/*
 * IO types
 */
typedef itk::ImageFileReader< InputImageType > InputReaderType;
typedef itk::ImageFileWriter< OutputImageType > OutputWriterType;

InterimImageType::Pointer PreprocessImage(InputImageType* inImage)
  {
  InterimImageType::Pointer image;

  CastToInterimType::Pointer castor = CastToInterimType::New();
  SlicedFilterType::Pointer slicer = SlicedFilterType::New();
  N4PipelineType::Pointer n4Corrector = N4PipelineType::New();
  Normalizer3dType::Pointer normalizer3D = Normalizer3dType::New();
  NormalizerType::Pointer normalizer = NormalizerType::New();
  BilateralImageFilterType::Pointer smoothing = BilateralImageFilterType::New();
  MaskFilterType::Pointer maskFilter = MaskFilterType::New();

  castor->SetInput(inImage);

  normalizer3D->SetInput(castor->GetOutput());
  normalizer3D->Update();

  normalizer->SetTargetMax(normalizer3D->GetMaxValue());
  normalizer->SetTargetMin(normalizer3D->GetMinValue());
  slicer->SetInput(castor->GetOutput());
  slicer->SetFilter(normalizer);
  n4Corrector->SetInput(slicer->GetOutput());

  smoothing->AutomaticKernelSizeOn();
  smoothing->SetInput(n4Corrector->GetOutput());
  smoothing->SetDomainSigma(2);
  smoothing->SetRangeSigma(
      (normalizer3D->GetMaxValue() - normalizer3D->GetMinValue()) / 25.0);

  maskFilter->SetInput(smoothing->GetOutput());
  maskFilter->SetMaskImage(castor->GetOutput());

  image = maskFilter->GetOutput();
  image->Update();
  image->DisconnectPipeline();

  return image;
  }

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Image intensity range controller " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "out.nii.gz", "string", cmd);

  TCLAP::ValueArg< unsigned int > bins("b", "bins", "", false, 20, "Integer",
                                       cmd);

  TCLAP::ValueArg< float > percentile("p", "percentile", "", false, 0.05,
                                      "Real", cmd);

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
    CollectorType::Pointer collector = CollectorType::New();
    collector->PushBackInput(
        PreprocessImage(
            cascade::util::LoadImage< InputImageType >(input.getValue())));
    RobustOutlierPipelineType::Pointer outlierDetector =
        RobustOutlierPipelineType::New();
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
    thresholdFilter->SetLowerThreshold(
        itk::NumericTraits< MaskImageType::PixelType >::epsilon());
    outlierDetector->SetMaskImage(thresholdFilter->GetOutput());
    outlierDetector->SetMaskValue(thresholdFilter->GetInsideValue());
    outlierDetector->SetPercentile(percentile.getValue());
    outlierDetector->SetNumberOfBins(bins.getValue());
    outlierDetector->SetInput(collector->GetOutput());
    outlierDetector->Update();
    CastToOutputType::Pointer castor = CastToOutputType::New();

    castor->SetInput(outlierDetector->GetOutput());

    OutputWriterType::Pointer outputWriter = OutputWriterType::New();
    outputWriter->SetInput(castor->GetOutput());
    outputWriter->SetFileName(outfile.getValue());
    outputWriter->Update();
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
