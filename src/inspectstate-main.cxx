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
#include "itkVectorImage.h"
#include "itkImageIOBase.h"
#include "itkNumericSeriesFileNames.h"
#include "itkVectorIndexSelectionCastImageFilter.h"
#include "itkUnaryFunctorImageFilter.h"
/** ITK IO  */
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
/** Others */
#include "3rdparty/tclap/CmdLine.h"
#include "util/helpers.h"

/** Pixel types, please only change these types */
typedef float PixelType;
typedef float StatePixelType;

/** Image and Filter types */
typedef itk::Image< PixelType, DIM > ImageType;
typedef itk::VectorImage< PixelType, DIM > StateImageType;
/** IO types */
typedef itk::ImageFileReader< StateImageType > StateReaderType;
typedef itk::ImageFileWriter< ImageType > ImageWriterType;

typedef itk::NumericSeriesFileNames FilenameType;
typedef itk::VectorIndexSelectionCastImageFilter< StateImageType, ImageType > IndexSelectionType;
int main(int argc, char *argv[])
  {
  TCLAP::CmdLine cmd(
      "Cascade(v" CASCADE_VERSION ") - Segmentation of White Matter Lesion: Training " BUILDINFO,
      ' ', CASCADE_VERSION);

  TCLAP::ValueArg< std::string > outfile(
      "o",
      "out",
      "Output prefix. Output series would be OUT000, OUT001 and so on with the same file format as the input.",
      false, "out_", "OUT", cmd);

  TCLAP::ValueArg< std::string > input(
      "i", "input", "Normalized input image file e.g. MPRAGE_normalized.nii.gz",
      true, "Input", "", cmd);

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
    /** Load the state */
    StateReaderType::Pointer stateReader = StateReaderType::New();
    stateReader->SetFileName(input.getValue());
    stateReader->Update();
    StateImageType::Pointer stateImage = stateReader->GetOutput();

    /** Exploit vector space to regular images */
    std::string stateFileSeriesFormat = "%03d.nii.gz";
    typedef itk::ImageIOBase::ArrayOfExtensionsType ExtType;
    typedef ExtType::const_iterator ExtIteratorType;
    itk::ImageIOBase::ArrayOfExtensionsType extlist =
        stateReader->GetImageIO()->GetSupportedWriteExtensions();
    for (ExtIteratorType it = extlist.begin(); it != extlist.end(); ++it)
      {
      std::string ext = *it;
      std::string frmt = input.getValue();
      if (cascade::util::endsWith(input.getValue(), ext))
        {
        frmt = outfile.getValue() + "%03d" + ext;
        stateFileSeriesFormat = frmt;
        break;
        }
      }
    const unsigned int comps = stateImage->GetNumberOfComponentsPerPixel();
    FilenameType::Pointer numericSeriesFileNames = FilenameType::New();
    numericSeriesFileNames->SetStartIndex(0);
    numericSeriesFileNames->SetEndIndex(comps);
    numericSeriesFileNames->SetSeriesFormat(stateFileSeriesFormat);

    ImageWriterType::Pointer sliceWriter = ImageWriterType::New();

    IndexSelectionType::Pointer indexSelector = IndexSelectionType::New();
    indexSelector->SetInput(stateImage);
    for (int i = 0; i < comps; i++)
      {
      indexSelector->SetIndex(i);
      sliceWriter->SetInput(indexSelector->GetOutput());
      sliceWriter->SetFileName(numericSeriesFileNames->GetFileNames()[i]);
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
