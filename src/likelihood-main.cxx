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
#include "3rdparty/stacktrace.h"
#include "buildinfo.h"
/** CPP Headers */
#include <sstream>
#include <string>
#include <vector>
/** General ITK  */
#include "itkImage.h"
/** ITK Filters */
#include "itkBinaryThresholdImageFilter.h"
#if ITK_VERSION_MAJOR >= 4
#include "itkComposeImageFilter.h"
#else
#include "itkImageToVectorImageFilter.h"
#endif
/** ITK IO  */
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
#include "itkTransformFileReader.h"
/** Others */
#include "pipeline/itkRobustOutlierPipeline.h"
#include "3rdparty/tclap/CmdLine.h"
#include "util/helpers.h"

/** Pixel types, please only change these types */
typedef float PixelType;
typedef float StatePixelType;

/** Image and Filter types */
typedef itk::Image< PixelType, DIM > ImageType;
#if ITK_VERSION_MAJOR >= 4
typedef itk::ComposeImageFilter< ImageType > CollectorType;
#else
typedef itk::ImageToVectorImageFilter< ImageType > CollectorType;
#endif
typedef CollectorType::OutputImageType CollectedImageType;

typedef itk::RobustOutlierPipeline< CollectedImageType > OutlierPipelineType;
typedef OutlierPipelineType::StateImageType StateImageType;
typedef OutlierPipelineType::TransformType TransformType;
typedef OutlierPipelineType::MaskImageType MaskImageType;
typedef itk::BinaryThresholdImageFilter< MaskImageType, MaskImageType > BinaryThresholdImageFilterType;

/** IO types */
typedef itk::ImageFileReader< ImageType > ImageReaderType;
typedef itk::ImageFileReader< StateImageType > StateReaderType;
typedef itk::ImageFileWriter< ImageType > ImageWriterType;

#if (ITK_VERSION_MAJOR == 4 && ITK_VERSION_MINOR >= 5) || ITK_VERSION_MAJOR > 4
typedef itk::TransformFileReaderTemplate<float> TransformReaderType;
#else
typedef itk::TransformFileReader TransformReaderType;
#endif

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion: Training " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output state file.",
                                         false, "out.nii.gz", "Output", cmd);

  TCLAP::ValueArg< std::string > trainedState(
      "s",
      "state",
      "Initial state file. A vector image with specific dimension (3,6,10,15,...). Typically the output of this program.",
      false, "", "Output", cmd);

  TCLAP::ValueArg< std::string > mask(
      "m",
      "mask",
      "Mask the input image. Process only from the points with non zero value. Should be the same size as Input.",
      false, "", "Output", cmd);

  TCLAP::ValueArg< std::string > transform(
      "t", "transform",
      "Transform from input space to standard (MNI) space. e.g. trans.tfm",
      true, "", "Transform", cmd);

  TCLAP::MultiArg< std::string > inputLight(
      "l", "light", "Normalized light image file e.g. FLAIR_normalized.nii.gz",
      false, "Light Input", cmd);

  TCLAP::MultiArg< std::string > inputDark(
      "d", "dark", "Normalized dark image file e.g. MPRAGE_normalized.nii.gz",
      false, "Dark Input", cmd);

  /** Parse the argv array.   */
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

  /** Argument and setting up the pipeline  */
  try
    {
    /** Reading all the inputs. */
    CollectorType::Pointer collector = CollectorType::New();
    OutlierPipelineType::Pointer likelihood = OutlierPipelineType::New();

    int n(0);
    for (TCLAP::MultiArg< std::string >::const_iterator seqNameIt =
        inputLight.begin(); seqNameIt != inputLight.end(); ++seqNameIt)
      {
      collector->PushBackInput(
          cascade::util::LoadImage< ImageType >(*seqNameIt));
      likelihood->SetNthChannelLight(n++);
      }
    for (TCLAP::MultiArg< std::string >::const_iterator seqNameIt =
        inputDark.begin(); seqNameIt != inputDark.end(); ++seqNameIt)
      {
      collector->PushBackInput(
          cascade::util::LoadImage< ImageType >(*seqNameIt));
      likelihood->SetNthChannelDark(n++);
      }

    itkAssertOrThrowMacro(n!=0,
                          "You should specify at least one input sequence.");
    collector->Update();
    likelihood->SetInput(collector->GetOutput());

    TransformReaderType::Pointer transformReader = TransformReaderType::New();
    transformReader->SetFileName(transform.getValue());
    transformReader->Update();

    likelihood->SetTransform(
        static_cast< TransformType* >(transformReader->GetTransformList()->front().GetPointer()));

    BinaryThresholdImageFilterType::Pointer thresholdFilter =
        BinaryThresholdImageFilterType::New();
    /** Set mask if any */
    if (mask.isSet())
      {
      thresholdFilter->SetInput(
          cascade::util::LoadImage< MaskImageType >(mask.getValue()));
      thresholdFilter->SetLowerThreshold(itk::NumericTraits<MaskImageType::PixelType>::epsilon());
      likelihood->SetMaskImage(thresholdFilter->GetOutput());
      likelihood->SetMaskValue(thresholdFilter->GetInsideValue());
      }

    StateReaderType::Pointer stateReader = StateReaderType::New();
    stateReader->SetFileName(trainedState.getValue());
    stateReader->Update();
    likelihood->SetStateImage(stateReader->GetOutput());

    likelihood->Update();

    ImageWriterType::Pointer stateWriter = ImageWriterType::New();
    stateWriter->SetFileName(outfile.getValue());
    stateWriter->SetInput(likelihood->GetOutput());
    stateWriter->Update();
    }
  catch (itk::ExceptionObject & err)
    {
    std::ostringstream errorMessage;
    errorMessage << "Exception caught!\n" << err << "\n";
    itk::OutputWindowDisplayErrorText(errorMessage.str().c_str());
    print_stacktrace();
    return EXIT_FAILURE;
    }
  return EXIT_SUCCESS;
  }
