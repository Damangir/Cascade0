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

#include <fstream>
#include <string>
/*
 * General ITK
 */
#include "itkImage.h"
/*
 * ITK Filters
 */
#include "itkCastImageFilter.h"
#include "itkUnaryFunctorImageFilter.h"
/*
 * Others
 */

#include "util/itkIntensityTableLookupFunctor.h"

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

typedef itk::CastImageFilter< InputImageType, InterimImageType > CastToInterimType;
typedef itk::CastImageFilter< InterimImageType, OutputImageType > CastToOutputType;

typedef itk::IntensityTableLookupFunctor< InterimPixelType, InterimPixelType > LookupFunctorType;
typedef itk::UnaryFunctorImageFilter< InterimImageType, InterimImageType,
    LookupFunctorType > LookupTransform;

int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion. Image to percentile filter. " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile("o", "out", "Output filename", false,
                                         "out.nii.gz", "string", cmd);

  TCLAP::ValueArg< std::string > transform("t", "transform",
                                           "Intensity transformation file",
                                           false, "", "string", cmd);

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
    CastToInterimType::Pointer castToInterim = CastToInterimType::New();
    castToInterim->SetInput(
        cascade::util::LoadImage< InputImageType >(input.getValue()));

    LookupFunctorType lookupFunctor;

    std::ifstream infile(transform.getValue().c_str());
    double from, to, perc;
    while (infile >> perc >> from >> to)
    {
      lookupFunctor.AddLookupRow(from, to);
    }
    lookupFunctor.AddLookupRow(0, 0);

    LookupTransform::Pointer lookupTransform = LookupTransform::New();
    lookupTransform->SetInput(castToInterim->GetOutput());
    lookupTransform->SetFunctor(lookupFunctor);
    lookupTransform->Update();

    CastToOutputType::Pointer castToOutput = CastToOutputType::New();
    castToOutput->SetInput(lookupTransform->GetOutput());
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
