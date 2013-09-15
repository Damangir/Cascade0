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
/** CPP Headers */
#include <sstream>
#include <string>
#include <vector>
/** General ITK  */
#include "itkImage.h"
/** ITK Filters */
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
#include "util/itkTrainSingleNodeFilter.h"
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
typedef itk::TrainSingleNodeFilter< CollectedImageType > TrainerFilterType;
typedef TrainerFilterType::StateImageType StateImageType;
typedef TrainerFilterType::MaskImageType MaskImageType;
typedef TrainerFilterType::TransformType TransformType;
/** IO types */
typedef itk::ImageFileReader< ImageType > ImageReaderType;
typedef itk::ImageFileReader< StateImageType > StateReaderType;
typedef itk::ImageFileReader< MaskImageType > MaskReaderType;
typedef itk::ImageFileWriter< StateImageType > StateWriterType;
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

  TCLAP::SwitchArg debugFlag("", "debug",
                             "Write individual part of the state image", cmd,
                             false);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output state file.",
                                         false, "out.nii.gz", "Output", cmd);

  TCLAP::ValueArg< std::string > initState(
      "s",
      "init",
      "Initial state file. A vector image with specific dimension (3,6,10,15,...). Typically the output of this program.",
      false, "", "Output", cmd);

  TCLAP::ValueArg< int > size(
      "",
      "size",
      "Size of the state image. If this value set together with --init option, the values in state image will be ignored and only its prameters will be used.",
      false, 0, "Size", cmd);

  TCLAP::ValueArg< std::string > mask(
      "m",
      "mask",
      "Mask the input image. Learn only from the points with non zero value. Should be the same size as Input.",
      false, "", "Output", cmd);

  TCLAP::ValueArg< std::string > transform(
      "t", "transform",
      "Transform from input space to standard (MNI) space. e.g. trans.tfm",
      true, "", "Transform", cmd);

  TCLAP::MultiArg< std::string > input(
      "i", "input", "Normalized input image file e.g. MPRAGE_normalized.nii.gz",
      true, "Input", cmd);

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

    for (TCLAP::MultiArg< std::string >::const_iterator seqNameIt =
        input.begin(); seqNameIt != input.end(); ++seqNameIt)
      {
      collector->PushBackInput(cascade::util::LoadImage<ImageType>(*seqNameIt));
      }

    TransformReaderType::Pointer transformReader = TransformReaderType::New();
    transformReader->SetFileName(transform.getValue());
    transformReader->Update();

    TrainerFilterType::Pointer trainer = TrainerFilterType::New();
    trainer->SetInput(collector->GetOutput());
    trainer->SetTransform(
        static_cast< TransformType* >(transformReader->GetTransformList()->front().GetPointer()));

    /** Set initial state if any */
    StateReaderType::Pointer stateReader = StateReaderType::New();
    ImageReaderType::Pointer stateReader1 = ImageReaderType::New();
    if (initState.isSet())
      {
      if (size.isSet())
        {
        stateReader1->SetFileName(initState.getValue());
        stateReader1->Update();
        TrainerFilterType::SizeType s;
        s.Fill(size.getValue());
        trainer->SetOutputParameterFromImageWithCustomSize(
            stateReader1->GetOutput(), s);
        }
      else
        {
        stateReader->SetFileName(initState.getValue());
        stateReader->Update();
        trainer->SetInitialState(stateReader->GetOutput());
        }
      }

    /** Set input mask if any */
    MaskReaderType::Pointer maskReader = MaskReaderType::New();
    if (mask.isSet())
      {
      maskReader->SetFileName(mask.getValue());
      maskReader->Update();
      trainer->SetMaskImage(maskReader->GetOutput());
      }

    trainer->Update();

    StateWriterType::Pointer stateWriter = StateWriterType::New();
    stateWriter->SetFileName(outfile.getValue());
    stateWriter->SetInput(trainer->GetOutput());
    stateWriter->Update();

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
